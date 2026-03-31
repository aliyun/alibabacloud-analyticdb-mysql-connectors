"""analyticdb-mysql-cli schema command — inspect database schema."""

from __future__ import annotations

from typing import Any

import click
import pymysql

from analyticdb_mysql_cli import output
from analyticdb_mysql_cli.connection import get_connection
from analyticdb_mysql_cli.logger import log_operation


def _is_hidden_schema_table(table_name: str) -> bool:
    """True for internal/system tables omitted from ``schema tables`` and ``schema dump``."""
    t = table_name.strip()
    if not t:
        return False
    # Filter out common AnalyticDB MySQL internal system tables
    lower = t.lower()
    if lower.startswith("__"):
        return True
    return False


@click.group("schema")
@click.pass_context
def schema_cmd(ctx: click.Context) -> None:
    """Inspect database schema."""


@schema_cmd.command("tables")
@click.pass_context
def tables(ctx: click.Context) -> None:
    """List all tables with column count and row estimate."""
    fmt: str = ctx.obj["format"]
    dsn: str | None = ctx.obj["dsn"]

    try:
        conn = get_connection(dsn)
    except Exception as exc:
        log_operation("schema tables", ok=False, error_code="CONNECTION_ERROR")
        output.error("CONNECTION_ERROR", str(exc), fmt=fmt)
        return

    timer = output.Timer()
    try:
        with timer, conn.cursor() as cur:
            cur.execute("SHOW TABLE STATUS")
            status_rows = cur.fetchall()

            result: list[dict[str, Any]] = []
            for row in status_rows:
                table_name = row.get("Name", "")
                if _is_hidden_schema_table(table_name):
                    continue

                cur.execute(f"SHOW COLUMNS FROM `{table_name}`")
                col_count = len(cur.fetchall())

                row_count = row.get("Rows", 0) or 0
                if row_count == 0:
                    # Stats report 0 — may be stale before compaction.
                    # Verify with COUNT(*) only for these tables.
                    try:
                        cur.execute(f"SELECT COUNT(*) AS cnt FROM `{table_name}`")
                        cnt_row = cur.fetchone()
                        row_count = cnt_row["cnt"] if cnt_row else 0
                    except Exception:
                        pass

                result.append({
                    "name": table_name,
                    "columns": col_count,
                    "rows": row_count,
                })

        log_operation("schema tables", ok=True, time_ms=timer.elapsed_ms)
        output.success(result, time_ms=timer.elapsed_ms, fmt=fmt)
    except pymysql.err.Error as exc:
        log_operation("schema tables", ok=False, error_code="SQL_ERROR")
        output.error("SQL_ERROR", str(exc), fmt=fmt)
    finally:
        conn.close()


@schema_cmd.command("describe")
@click.argument("table")
@click.pass_context
def describe(ctx: click.Context, table: str) -> None:
    """Show table structure: columns, types, indexes, and comments."""
    fmt: str = ctx.obj["format"]
    dsn: str | None = ctx.obj["dsn"]

    try:
        conn = get_connection(dsn)
    except Exception as exc:
        log_operation("schema describe", ok=False, error_code="CONNECTION_ERROR")
        output.error("CONNECTION_ERROR", str(exc), fmt=fmt)
        return

    timer = output.Timer()
    try:
        with timer, conn.cursor() as cur:
            # Table comment
            cur.execute(
                "SELECT TABLE_COMMENT FROM INFORMATION_SCHEMA.TABLES "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s",
                (table,),
            )
            table_info = cur.fetchone()
            if not table_info:
                log_operation("schema describe", ok=False, error_code="TABLE_NOT_FOUND")
                cur.execute("SHOW TABLES")
                tables_list = [list(r.values())[0] for r in cur.fetchall()]
                output.error(
                    "TABLE_NOT_FOUND",
                    f"Table '{table}' does not exist",
                    fmt=fmt,
                    extra={"schema": {"tables": tables_list}},
                )
                return

            table_comment = table_info.get("TABLE_COMMENT", "")

            cur.execute(f"SHOW FULL COLUMNS FROM `{table}`")
            columns = [
                {
                    "name": r["Field"],
                    "type": r["Type"],
                    "comment": r.get("Comment", ""),
                }
                for r in cur.fetchall()
            ]

            cur.execute(f"SHOW INDEX FROM `{table}`")
            indexes: list[str] = []
            idx_cols: dict[str, list[str]] = {}
            for idx in cur.fetchall():
                key = idx["Key_name"]
                col = idx["Column_name"]
                idx_cols.setdefault(key, []).append(col)
            for key, cols in idx_cols.items():
                indexes.append(f"{key}({','.join(cols)})")

        data: dict[str, Any] = {
            "table": table,
            "comment": table_comment,
            "columns": columns,
            "indexes": indexes,
        }

        log_operation("schema describe", ok=True, time_ms=timer.elapsed_ms)
        output.success(data, time_ms=timer.elapsed_ms, fmt=fmt)
    except pymysql.err.Error as exc:
        log_operation("schema describe", ok=False, error_code="SQL_ERROR")
        output.error("SQL_ERROR", str(exc), fmt=fmt)
    finally:
        conn.close()


@schema_cmd.command("dump")
@click.pass_context
def dump(ctx: click.Context) -> None:
    """Output CREATE TABLE DDL for all tables."""
    fmt: str = ctx.obj["format"]
    dsn: str | None = ctx.obj["dsn"]

    try:
        conn = get_connection(dsn)
    except Exception as exc:
        log_operation("schema dump", ok=False, error_code="CONNECTION_ERROR")
        output.error("CONNECTION_ERROR", str(exc), fmt=fmt)
        return

    timer = output.Timer()
    try:
        with timer, conn.cursor() as cur:
            cur.execute("SHOW TABLES")
            all_names = [list(r.values())[0] for r in cur.fetchall()]
            table_names = [n for n in all_names if not _is_hidden_schema_table(n)]

            ddl_list: list[dict[str, str]] = []
            for tbl in table_names:
                cur.execute(f"SHOW CREATE TABLE `{tbl}`")
                row = cur.fetchone()
                create_stmt = row.get("Create Table", "") if row else ""
                ddl_list.append({"table": tbl, "ddl": create_stmt})

        log_operation("schema dump", ok=True, time_ms=timer.elapsed_ms)
        output.success(ddl_list, time_ms=timer.elapsed_ms, fmt=fmt)
    except pymysql.err.Error as exc:
        log_operation("schema dump", ok=False, error_code="SQL_ERROR")
        output.error("SQL_ERROR", str(exc), fmt=fmt)
    finally:
        conn.close()
