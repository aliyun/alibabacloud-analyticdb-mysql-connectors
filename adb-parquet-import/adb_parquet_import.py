# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "pyarrow>=14.0.0",
#     "pymysql>=1.1.0",
#     "tqdm>=4.60.0",
# ]
# ///
"""Parquet to AnalyticDB MySQL import tool.

Reads a Parquet file and bulk-inserts its data into an AnalyticDB MySQL table
using batched multi-row INSERT/REPLACE statements.

Configuration priority: CLI args > environment variables > config file > defaults.

Usage:
    uv run adb_parquet_import.py -f data.parquet -H host -u user -d db -t table
    uv run adb_parquet_import.py -f data.parquet -t table --config my_adb.ini
    ADB_HOST=host ADB_USER=user ADB_DATABASE=db uv run adb_parquet_import.py -f data.parquet -t table
"""

from __future__ import annotations

import argparse
import configparser
import datetime
import getpass
import json
import logging
import math
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, Future
from dataclasses import dataclass, field
from decimal import Decimal
from pathlib import Path
from typing import Any, Callable

import pyarrow as pa
import pyarrow.parquet as pq
import pyarrow.types as pat
import pymysql
from pymysql.converters import escape_string
from tqdm import tqdm

logger = logging.getLogger("adb_parquet_import")

# ---------------------------------------------------------------------------
# Type mapping: PyArrow type  →  (ADB DDL type, value converter function)
# ---------------------------------------------------------------------------

def _conv_bool(v: Any) -> str:
    return "1" if v else "0"


def _conv_int(v: Any) -> str:
    return str(v)


def _conv_float(v: Any) -> str:
    if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
        return "NULL"
    return repr(v)


def _conv_decimal(v: Any) -> str:
    return str(v)


def _conv_string(v: Any) -> str:
    return "'" + escape_string(str(v)) + "'"


def _conv_binary(v: Any) -> str:
    if isinstance(v, (bytes, bytearray)):
        return "X'" + v.hex() + "'"
    return "NULL"


def _conv_date(v: Any) -> str:
    if isinstance(v, datetime.date):
        return "'" + v.isoformat() + "'"
    return "NULL"


def _conv_time(v: Any) -> str:
    if isinstance(v, datetime.time):
        return "'" + v.isoformat() + "'"
    return "NULL"


def _conv_datetime(v: Any) -> str:
    if isinstance(v, datetime.datetime):
        return "'" + v.strftime("%Y-%m-%d %H:%M:%S.%f") + "'"
    return "NULL"


def _conv_duration(v: Any) -> str:
    """Convert timedelta to microseconds integer."""
    if isinstance(v, datetime.timedelta):
        return str(int(v.total_seconds() * 1_000_000))
    return str(v)


def _conv_json(v: Any) -> str:
    """Convert complex types (list / dict / map) to JSON string."""
    try:
        s = json.dumps(v, default=str, ensure_ascii=False)
    except (TypeError, ValueError):
        s = str(v)
    return "'" + escape_string(s) + "'"


def _conv_null(_v: Any) -> str:
    return "NULL"


def make_converter(arrow_type: pa.DataType) -> tuple[str, Callable[[Any], str]]:
    """Return ``(adb_ddl_type, value_converter)`` for the given Arrow type."""

    # -- Boolean --
    if pat.is_boolean(arrow_type):
        return ("BOOLEAN", _conv_bool)

    # -- Signed integers --
    if pat.is_int8(arrow_type):
        return ("TINYINT", _conv_int)
    if pat.is_int16(arrow_type):
        return ("SMALLINT", _conv_int)
    if pat.is_int32(arrow_type):
        return ("INT", _conv_int)
    if pat.is_int64(arrow_type):
        return ("BIGINT", _conv_int)

    # -- Unsigned integers (promote one tier because ADB types are signed) --
    if pat.is_uint8(arrow_type):
        return ("SMALLINT", _conv_int)
    if pat.is_uint16(arrow_type):
        return ("INT", _conv_int)
    if pat.is_uint32(arrow_type):
        return ("BIGINT", _conv_int)
    if pat.is_uint64(arrow_type):
        return ("DECIMAL(20,0)", _conv_int)

    # -- Floating point --
    if pat.is_float16(arrow_type):
        return ("FLOAT", _conv_float)
    if pat.is_float32(arrow_type):
        return ("FLOAT", _conv_float)
    if pat.is_float64(arrow_type):
        return ("DOUBLE", _conv_float)

    # -- Decimal --
    if pat.is_decimal128(arrow_type) or pat.is_decimal256(arrow_type):
        p = arrow_type.precision
        s = arrow_type.scale
        if p > 38:
            logger.warning(
                "Decimal precision %d exceeds ADB max 38, clamping to DECIMAL(38,%d)",
                p,
                s,
            )
            p = 38
        return (f"DECIMAL({p},{s})", _conv_decimal)

    # -- String / UTF-8 --
    if (
        pat.is_string(arrow_type)
        or pat.is_large_string(arrow_type)
    ):
        return ("VARCHAR", _conv_string)

    # -- Binary --
    if (
        pat.is_binary(arrow_type)
        or pat.is_large_binary(arrow_type)
        or pat.is_fixed_size_binary(arrow_type)
    ):
        return ("BINARY", _conv_binary)

    # -- Date --
    if pat.is_date(arrow_type):
        return ("DATE", _conv_date)

    # -- Time --
    if pat.is_time(arrow_type):
        return ("TIME", _conv_time)

    # -- Timestamp --
    if pat.is_timestamp(arrow_type):
        if arrow_type.tz is not None:
            return ("TIMESTAMP", _conv_datetime)
        return ("DATETIME", _conv_datetime)

    # -- Duration --
    if pat.is_duration(arrow_type):
        return ("BIGINT", _conv_duration)

    # -- Complex types → JSON --
    if (
        pat.is_list(arrow_type)
        or pat.is_large_list(arrow_type)
        or pat.is_fixed_size_list(arrow_type)
        or pat.is_struct(arrow_type)
        or pat.is_map(arrow_type)
    ):
        return ("JSON", _conv_json)

    # -- Null type --
    if pat.is_null(arrow_type):
        return ("VARCHAR", _conv_null)

    # -- Fallback: treat as VARCHAR --
    logger.warning("Unknown Arrow type %s, falling back to VARCHAR", arrow_type)
    return ("VARCHAR", _conv_string)


# ---------------------------------------------------------------------------
# DDL generation
# ---------------------------------------------------------------------------

def _escape_identifier(name: str) -> str:
    """Escape a SQL identifier (table name, column name) for safe use in backticks."""
    return "`" + name.replace("`", "``") + "`"


def generate_ddl(
    table_name: str,
    columns: list[str],
    type_info: list[tuple[str, Callable]],
) -> str:
    """Build a ``CREATE TABLE IF NOT EXISTS`` DDL from Parquet schema."""
    col_defs = []
    for col_name, (adb_type, _conv) in zip(columns, type_info):
        escaped = _escape_identifier(col_name)
        col_defs.append(f"  {escaped} {adb_type}")
    cols_sql = ",\n".join(col_defs)
    first_col = _escape_identifier(columns[0])
    return (
        f"CREATE TABLE IF NOT EXISTS {_escape_identifier(table_name)} (\n"
        f"{cols_sql}\n"
        f") DISTRIBUTE BY HASH({first_col})"
    )


# ---------------------------------------------------------------------------
# Core import logic
# ---------------------------------------------------------------------------

@dataclass
class ImportResult:
    total_rows: int = 0
    imported_rows: int = 0
    failed_rows: int = 0
    failed_batches: int = 0
    elapsed: float = 0.0
    interrupted: bool = False
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def add_imported(self, count: int) -> None:
        with self._lock:
            self.imported_rows += count

    def add_failed(self, count: int) -> None:
        with self._lock:
            self.failed_rows += count
            self.failed_batches += 1


def _split_by_size(
    sql_prefix: str,
    row_tuples: list[str],
    max_bytes: int,
) -> list[list[str]]:
    """Split *row_tuples* into sub-lists so each INSERT stays under *max_bytes*.

    Each sub-list will produce: ``sql_prefix + '\n' + ',\n'.join(sub)``.
    If a single row already exceeds the limit, it is placed alone in its own
    sub-batch (we never drop data).
    """
    if not row_tuples:
        return []

    prefix_len = len(sql_prefix.encode("utf-8")) + 1  # +1 for '\n'
    batches: list[list[str]] = []
    current: list[str] = []
    current_size = prefix_len

    for row in row_tuples:
        row_size = len(row.encode("utf-8")) + 2  # +2 for ',\n' separator
        if current and (current_size + row_size) > max_bytes:
            batches.append(current)
            current = []
            current_size = prefix_len
        current.append(row)
        current_size += row_size

    if current:
        batches.append(current)
    return batches


def _execute_sub_batch(
    args: argparse.Namespace,
    sql_prefix: str,
    sub_rows: list[str],
    result: ImportResult,
    pbar: tqdm | None,
    pbar_lock: threading.Lock,
    pbar_rows: int,
    conns: dict[int, pymysql.Connection],
    conns_lock: threading.Lock,
    abort_event: threading.Event,
) -> None:
    """Execute a single sub-batch INSERT in a worker thread."""
    if abort_event.is_set():
        return

    tid = threading.get_ident()

    # Get or create a per-thread connection
    with conns_lock:
        conn = conns.get(tid)

    if conn is None or not conn.open:
        try:
            conn = _connect(args)
            with conns_lock:
                conns[tid] = conn
        except Exception:
            logger.error("Worker thread failed to connect, aborting.")
            abort_event.set()
            result.add_failed(len(sub_rows))
            return

    full_sql = sql_prefix + "\n" + ",\n".join(sub_rows)
    sub_count = len(sub_rows)
    cursor = conn.cursor()

    try:
        cursor.execute(full_sql)
        conn.commit()
        result.add_imported(sub_count)
    except pymysql.Error as exc:
        logger.error("Batch failed (%d rows): %s", sub_count, exc)
        logger.debug("Failed SQL (first 500 chars): %s", full_sql[:500])
        try:
            conn.rollback()
        except Exception:
            pass
        result.add_failed(sub_count)
        # Try to recover from lost connection
        if not conn.open:
            logger.warning("Connection lost in worker, attempting reconnect ...")
            try:
                conn = _connect(args)
                with conns_lock:
                    conns[tid] = conn
            except Exception:
                logger.error("Reconnect failed in worker, aborting.")
                abort_event.set()
    finally:
        cursor.close()
        if pbar is not None and pbar_rows > 0:
            with pbar_lock:
                pbar.update(pbar_rows)


def import_parquet(args: argparse.Namespace) -> ImportResult:
    """Main import orchestration."""
    result = ImportResult()
    start = time.monotonic()

    # -- Open Parquet file -------------------------------------------------
    try:
        pf = pq.ParquetFile(args.file)
    except Exception as exc:
        logger.error("Failed to open Parquet file: %s", exc)
        sys.exit(2)

    schema = pf.schema_arrow
    total_rows = pf.metadata.num_rows
    result.total_rows = total_rows

    # -- Column selection ---------------------------------------------------
    if args.columns:
        selected = [c.strip() for c in args.columns.split(",")]
        missing = [c for c in selected if c not in schema.names]
        if missing:
            logger.error("Columns not found in Parquet: %s", missing)
            sys.exit(2)
        col_names = selected
    else:
        col_names = schema.names

    # -- Build type mapping -------------------------------------------------
    type_info: list[tuple[str, Callable]] = []
    for name in col_names:
        idx = schema.get_field_index(name)
        arrow_type = schema.field(idx).type
        type_info.append(make_converter(arrow_type))

    # -- SQL prefix ---------------------------------------------------------
    escaped_cols = ", ".join(_escape_identifier(c) for c in col_names)
    keyword = "REPLACE" if args.mode == "replace" else "INSERT"
    escaped_table = _escape_identifier(args.table)
    sql_prefix = f"{keyword} INTO {escaped_table} ({escaped_cols}) VALUES"

    # -- dry-run: no DB connection needed -----------------------------------
    if args.dry_run:
        _dry_run(pf, col_names, type_info, sql_prefix, args, total_rows)
        result.elapsed = time.monotonic() - start
        return result

    # -- Connect to ADB MySQL (main connection for DDL) --------------------
    conn = _connect(args)
    cursor = conn.cursor()

    # -- Optional: CREATE / DROP TABLE --------------------------------------
    if args.drop_table:
        logger.info("Dropping table `%s` ...", args.table)
        cursor.execute(f"DROP TABLE IF EXISTS {_escape_identifier(args.table)}")
        conn.commit()

    if args.create_table or args.drop_table:
        ddl = generate_ddl(args.table, col_names, type_info)
        logger.info("Creating table:\n%s", ddl)
        cursor.execute(ddl)
        conn.commit()

    cursor.close()
    conn.close()

    # -- Iterate batches (multi-threaded) -----------------------------------
    num_threads = getattr(args, "threads", 1) or 1
    logger.info("Using %d writer thread(s)", num_threads)

    show_progress = not args.no_progress and total_rows > 0
    pbar = tqdm(total=total_rows, unit="rows", disable=not show_progress)
    pbar_lock = threading.Lock()

    # max_sql_bytes: soft limit per INSERT statement to stay within
    # MySQL max_allowed_packet (default 16 MB, we use 15 MB to be safe).
    max_sql_bytes = 15 * 1024 * 1024

    abort_event = threading.Event()
    # Per-thread connections: thread_id -> connection
    conns: dict[int, pymysql.Connection] = {}
    conns_lock = threading.Lock()

    try:
        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            futures: list[Future] = []

            for batch in pf.iter_batches(batch_size=args.batch_size, columns=col_names):
                if abort_event.is_set():
                    break

                n_rows = batch.num_rows
                if n_rows == 0:
                    continue

                # Convert columns to Python lists
                columns_data = [batch.column(c).to_pylist() for c in col_names]

                # Build per-row value tuples
                row_tuples: list[str] = []
                for row_idx in range(n_rows):
                    vals: list[str] = []
                    for col_idx in range(len(col_names)):
                        raw = columns_data[col_idx][row_idx]
                        if raw is None:
                            vals.append("NULL")
                        else:
                            vals.append(type_info[col_idx][1](raw))
                    row_tuples.append("(" + ",".join(vals) + ")")

                # Split into sub-batches that respect max_sql_bytes
                sub_batches = _split_by_size(sql_prefix, row_tuples, max_sql_bytes)

                for i, sub_rows in enumerate(sub_batches):
                    # Only the last sub-batch of this parquet batch updates pbar
                    is_last = (i == len(sub_batches) - 1)
                    pbar_rows = n_rows if is_last else 0

                    fut = executor.submit(
                        _execute_sub_batch,
                        args, sql_prefix, sub_rows, result,
                        pbar, pbar_lock, pbar_rows,
                        conns, conns_lock, abort_event,
                    )
                    futures.append(fut)

            # Wait for all pending futures
            for fut in futures:
                fut.result()

    except KeyboardInterrupt:
        logger.warning("Interrupted by user.")
        result.interrupted = True
        abort_event.set()
    finally:
        pbar.close()
        # Close all worker connections
        with conns_lock:
            for c in conns.values():
                try:
                    c.close()
                except Exception:
                    pass

    result.elapsed = time.monotonic() - start
    return result


def _connect(args: argparse.Namespace) -> pymysql.Connection:
    """Open a pymysql connection from CLI args."""
    try:
        conn = pymysql.connect(
            host=args.host,
            port=args.port,
            user=args.user,
            password=args.password,
            database=args.database,
            charset=args.charset,
            connect_timeout=10,
            autocommit=False,
        )
        logger.info("Connected to %s:%d/%s", args.host, args.port, args.database)
        return conn
    except pymysql.Error as exc:
        logger.error("Connection failed: %s", exc)
        sys.exit(2)


def _dry_run(
    pf: pq.ParquetFile,
    col_names: list[str],
    type_info: list[tuple[str, Callable]],
    sql_prefix: str,
    args: argparse.Namespace,
    total_rows: int,
) -> None:
    """Print generated DDL and SQL for the first few batches."""
    print("=" * 60)
    print("DRY RUN MODE — no data will be written")
    print("=" * 60)

    # Show DDL if create-table is requested
    if args.create_table or args.drop_table:
        if args.drop_table:
            print(f"\nDROP TABLE IF EXISTS {_escape_identifier(args.table)};")
        ddl = generate_ddl(args.table, col_names, type_info)
        print(f"\n{ddl};\n")

    # Show type mapping
    print("Column type mapping:")
    for name, (adb_type, _) in zip(col_names, type_info):
        print(f"  {name:30s} -> {adb_type}")
    print()

    # Show first 3 batches of INSERT SQL
    batch_count = 0
    max_batches = 3
    for batch in pf.iter_batches(batch_size=args.batch_size, columns=col_names):
        if batch.num_rows == 0:
            continue
        batch_count += 1
        if batch_count > max_batches:
            break

        columns_data = [batch.column(c).to_pylist() for c in col_names]
        rows_sql: list[str] = []
        for row_idx in range(batch.num_rows):
            vals: list[str] = []
            for col_idx in range(len(col_names)):
                raw = columns_data[col_idx][row_idx]
                if raw is None:
                    vals.append("NULL")
                else:
                    vals.append(type_info[col_idx][1](raw))
            rows_sql.append("(" + ",".join(vals) + ")")

        full_sql = sql_prefix + "\n" + ",\n".join(rows_sql) + ";"
        print(f"--- Batch {batch_count} ({batch.num_rows} rows) ---")
        print(full_sql)
        print()

    remaining = total_rows - sum(
        min(args.batch_size, total_rows - i * args.batch_size)
        for i in range(min(batch_count, max_batches))
    )
    if remaining > 0:
        print(f"... {remaining} more rows omitted ...")


# ---------------------------------------------------------------------------
# Configuration loading (config file + environment variables)
# ---------------------------------------------------------------------------

# Mapping: config key → (config section, env var name, type)
_CONFIG_KEYS: dict[str, tuple[str, str, type]] = {
    "host":       ("connection", "ADB_HOST",     str),
    "port":       ("connection", "ADB_PORT",     int),
    "user":       ("connection", "ADB_USER",     str),
    "password":   ("connection", "ADB_PASSWORD", str),
    "database":   ("connection", "ADB_DATABASE", str),
    "charset":    ("connection", "ADB_CHARSET",  str),
    "mode":       ("import",     "ADB_MODE",     str),
    "batch_size": ("import",     "ADB_BATCH_SIZE", int),
    "threads":    ("import",     "ADB_THREADS",    int),
}

DEFAULT_CONFIG_FILE = ".adb.ini"


def _load_config_file(path: str | None) -> dict[str, Any]:
    """Load values from an INI config file.

    Returns a flat dict of resolved values (only keys present in the file).
    """
    result: dict[str, Any] = {}

    if path is None:
        # Try default locations: CWD, then home directory
        candidates = [
            Path.cwd() / DEFAULT_CONFIG_FILE,
            Path.home() / DEFAULT_CONFIG_FILE,
        ]
        for candidate in candidates:
            if candidate.is_file():
                path = str(candidate)
                break
    if path is None:
        return result

    cfg = configparser.ConfigParser()
    cfg.read(path, encoding="utf-8")

    for key, (section, _env, typ) in _CONFIG_KEYS.items():
        if cfg.has_option(section, key):
            raw = cfg.get(section, key)
            try:
                result[key] = typ(raw)
            except (ValueError, TypeError):
                pass

    logger.debug("Loaded config from %s: %s", path, {k: '***' if k == 'password' else v for k, v in result.items()})
    return result


def _load_env_vars() -> dict[str, Any]:
    """Load values from environment variables.

    Returns a flat dict of resolved values (only keys present in env).
    """
    result: dict[str, Any] = {}
    for key, (_section, env_name, typ) in _CONFIG_KEYS.items():
        val = os.environ.get(env_name)
        if val is not None:
            try:
                result[key] = typ(val)
            except (ValueError, TypeError):
                pass
    return result


# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Import Parquet data into AnalyticDB MySQL",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Configuration priority: CLI args > env vars > config file > defaults.\n"
            "\n"
            "Environment variables:\n"
            "  ADB_HOST, ADB_PORT, ADB_USER, ADB_PASSWORD, ADB_DATABASE,\n"
            "  ADB_CHARSET, ADB_MODE, ADB_BATCH_SIZE\n"
            "\n"
            "Config file (INI format, default: .adb.ini):\n"
            "  [connection]\n"
            "  host = 10.0.0.1\n"
            "  port = 3306\n"
            "  user = analyst\n"
            "  password = secret\n"
            "  database = mydb\n"
            "  charset = utf8mb4\n"
            "\n"
            "  [import]\n"
            "  mode = insert\n"
            "  batch_size = 1000\n"
        ),
    )

    src = p.add_argument_group("Source")
    src.add_argument("-f", "--file", required=True, help="Parquet file path")

    conn = p.add_argument_group("Connection")
    conn.add_argument("-H", "--host", default=None, help="ADB MySQL host")
    conn.add_argument("-P", "--port", type=int, default=None, help="ADB MySQL port (default: 3306)")
    conn.add_argument("-u", "--user", default=None, help="Database username")
    conn.add_argument("-p", "--password", default=None, help="Database password")
    conn.add_argument("-d", "--database", default=None, help="Target database")
    conn.add_argument("--charset", default=None, help="Connection charset (default: utf8mb4)")
    conn.add_argument("-c", "--config", default=None,
                      help=f"Config file path (default: ./{DEFAULT_CONFIG_FILE} or ~/{DEFAULT_CONFIG_FILE})")

    target = p.add_argument_group("Target")
    target.add_argument("-t", "--table", required=True, help="Target table name")

    behavior = p.add_argument_group("Behavior")
    behavior.add_argument("-m", "--mode", choices=["insert", "replace"], default=None,
                          help="insert or replace (default: insert)")
    behavior.add_argument("-b", "--batch-size", type=int, default=None,
                          help="Rows per INSERT statement (default: 1000)")
    behavior.add_argument("--create-table", action="store_true",
                          help="Auto-create table from Parquet schema")
    behavior.add_argument("--drop-table", action="store_true",
                          help="Drop table before creating (implies --create-table)")
    behavior.add_argument("--columns", default=None,
                          help="Comma-separated list of columns to import (default: all)")
    behavior.add_argument("-j", "--threads", type=int, default=None,
                          help="Number of parallel writer threads (default: 1)")

    oper = p.add_argument_group("Operational")
    oper.add_argument("--dry-run", action="store_true",
                      help="Print SQL without executing (first 3 batches)")
    oper.add_argument("--log-level", default="INFO",
                      choices=["DEBUG", "INFO", "WARNING", "ERROR"],
                      help="Logging level (default: INFO)")
    oper.add_argument("--no-progress", action="store_true",
                      help="Disable progress bar")

    args = p.parse_args(argv)

    # --- Merge: CLI > env vars > config file > defaults --------------------
    file_cfg = _load_config_file(args.config)
    env_cfg = _load_env_vars()

    defaults = {
        "port": 3306,
        "charset": "utf8mb4",
        "mode": "insert",
        "batch_size": 1000,
        "threads": 1,
    }

    for key in ("host", "port", "user", "password", "database", "charset", "mode", "batch_size", "threads"):
        cli_val = getattr(args, key.replace("-", "_"), None)
        if cli_val is not None:
            continue  # CLI takes priority
        # Try env, then config file, then default (use `is not None` to
        # preserve falsy-but-valid values like 0 or empty string).
        for source in (env_cfg, file_cfg, defaults):
            if source.get(key) is not None:
                setattr(args, key.replace("-", "_"), source[key])
                break

    # Validate required connection fields (unless dry-run)
    missing = [k for k in ("host", "user", "database") if not getattr(args, k, None)]
    if missing and not args.dry_run:
        p.error(
            f"Missing required connection parameter(s): {', '.join('--' + m for m in missing)}. "
            "Provide via CLI args, environment variables (ADB_HOST, ADB_USER, ADB_DATABASE), "
            f"or config file ({DEFAULT_CONFIG_FILE})."
        )

    # Password resolution: already set via CLI/env/config → done; otherwise prompt
    if args.password is None and not args.dry_run:
        args.password = getpass.getpass("ADB MySQL password: ")

    # --drop-table implies --create-table
    if args.drop_table:
        args.create_table = True

    return args


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    args = parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    logger.info("Parquet file: %s", args.file)
    logger.info("Target: %s:%d/%s.%s", args.host, args.port, args.database, args.table)
    logger.info("Mode: %s | Batch size: %d | Threads: %d", args.mode.upper(), args.batch_size, args.threads)

    result = import_parquet(args)

    # -- Summary -----------------------------------------------------------
    throughput = result.imported_rows / result.elapsed if result.elapsed > 0 else 0
    print()
    print("=" * 50)
    print("Import Summary")
    print("=" * 50)
    print(f"  File:            {args.file}")
    print(f"  Table:           {args.database}.{args.table}")
    print(f"  Total rows:      {result.total_rows:,}")
    print(f"  Rows imported:   {result.imported_rows:,}")
    print(f"  Rows failed:     {result.failed_rows:,} ({result.failed_batches} batches)")
    print(f"  Elapsed time:    {result.elapsed:.1f}s")
    print(f"  Throughput:      {throughput:,.0f} rows/sec")
    print(f"  Mode:            {args.mode.upper()}")
    print(f"  Batch size:      {args.batch_size:,}")
    print(f"  Threads:         {args.threads}")
    print("=" * 50)

    if result.failed_rows > 0 and result.imported_rows == 0:
        sys.exit(2)
    elif result.interrupted:
        sys.exit(130)
    elif result.failed_rows > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
