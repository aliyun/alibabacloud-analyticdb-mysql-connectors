"""analyticdb-mysql-cli relations infer command — infer table relationships by column name patterns."""

from __future__ import annotations

import re
from typing import Any

import click
import pymysql

from analyticdb_mysql_cli import output
from analyticdb_mysql_cli.connection import get_connection
from analyticdb_mysql_cli.logger import log_operation


@click.group("relations")
@click.pass_context
def relations_cmd(ctx: click.Context) -> None:
    """Infer table relationships."""


@relations_cmd.command("infer")
@click.option("--table", "target_table", default=None, help="Infer relations for a specific table only.")
@click.pass_context
def infer(ctx: click.Context, target_table: str | None) -> None:
    """Infer JOIN relationships between tables using column name patterns and type consistency."""
    fmt: str = ctx.obj["format"]
    dsn: str | None = ctx.obj["dsn"]

    try:
        conn = get_connection(dsn)
    except Exception as exc:
        log_operation("relations infer", ok=False, error_code="CONNECTION_ERROR")
        output.error("CONNECTION_ERROR", str(exc), fmt=fmt)
        return

    timer = output.Timer()
    try:
        with timer, conn.cursor() as cur:
            cur.execute("SHOW TABLES")
            all_tables = [list(r.values())[0] for r in cur.fetchall()]

            if target_table and target_table not in all_tables:
                log_operation("relations infer", ok=False, error_code="TABLE_NOT_FOUND")
                output.error(
                    "TABLE_NOT_FOUND",
                    f"Table '{target_table}' does not exist",
                    fmt=fmt,
                    extra={"schema": {"tables": all_tables}},
                )
                return

            pk_map: dict[str, dict[str, str]] = {}
            col_map: dict[str, list[dict[str, str]]] = {}

            for tbl in all_tables:
                cur.execute(f"SHOW FULL COLUMNS FROM `{tbl}`")
                cols = cur.fetchall()
                col_map[tbl] = [{"name": c["Field"], "type": c["Type"]} for c in cols]

                cur.execute(f"SHOW INDEX FROM `{tbl}` WHERE Key_name = 'PRIMARY'")
                pk_rows = cur.fetchall()
                for pk in pk_rows:
                    pk_col_name = pk["Column_name"]
                    pk_type = next(
                        (c["type"] for c in col_map[tbl] if c["name"] == pk_col_name), ""
                    )
                    pk_map[tbl] = {"column": pk_col_name, "type": pk_type}

            tables_to_check = [target_table] if target_table else all_tables
            relations: list[dict[str, Any]] = []
            seen: set[str] = set()

            for tbl in tables_to_check:
                for col_info in col_map.get(tbl, []):
                    col_name = col_info["name"]
                    col_type = col_info["type"]

                    ref = _match_fk_pattern(col_name, tbl, all_tables, pk_map, col_type)
                    if ref:
                        key = f"{tbl}.{col_name}->{ref['to_table']}.{ref['to_column']}"
                        if key not in seen:
                            seen.add(key)
                            relations.append({
                                "from": f"{tbl}.{col_name}",
                                "to": f"{ref['to_table']}.{ref['to_column']}",
                                "confidence": ref["confidence"],
                            })

        log_operation("relations infer", ok=True, time_ms=timer.elapsed_ms)
        output.success(relations, time_ms=timer.elapsed_ms, fmt=fmt)
    except SystemExit:
        raise
    except pymysql.err.Error as exc:
        log_operation("relations infer", ok=False, error_code="SQL_ERROR")
        output.error("SQL_ERROR", str(exc), fmt=fmt)
    finally:
        conn.close()


def _match_fk_pattern(
    col_name: str,
    source_table: str,
    all_tables: list[str],
    pk_map: dict[str, dict[str, str]],
    col_type: str,
) -> dict[str, str] | None:
    """Try to match a column name to a foreign table's primary key."""
    if not col_name.lower().endswith("_id"):
        return None

    prefix = col_name[:-3]
    if not prefix:
        return None

    candidates = _find_candidate_tables(prefix, all_tables, source_table)

    for candidate_table, confidence in candidates:
        pk_info = pk_map.get(candidate_table)
        if pk_info and _types_compatible(col_type, pk_info["type"]):
            return {
                "to_table": candidate_table,
                "to_column": pk_info["column"],
                "confidence": confidence,
            }

    return None


def _find_candidate_tables(
    prefix: str,
    all_tables: list[str],
    source_table: str,
) -> list[tuple[str, str]]:
    """Find tables that match a FK prefix, returning (table_name, confidence)."""
    candidates: list[tuple[str, str]] = []
    prefix_lower = prefix.lower()

    plural_forms = [
        prefix_lower + "s",
        prefix_lower + "es",
        prefix_lower,
    ]
    if prefix_lower.endswith("y"):
        plural_forms.append(prefix_lower[:-1] + "ies")

    for tbl in all_tables:
        if tbl == source_table:
            continue
        tbl_lower = tbl.lower()

        if tbl_lower in plural_forms:
            candidates.append((tbl, "high"))
        elif tbl_lower.endswith(prefix_lower) or prefix_lower in tbl_lower:
            candidates.append((tbl, "medium"))

    return candidates


def _types_compatible(fk_type: str, pk_type: str) -> bool:
    """Check if two column types are compatible for a join relationship."""
    fk_base = re.sub(r"\(.*\)", "", fk_type).strip().lower()
    pk_base = re.sub(r"\(.*\)", "", pk_type).strip().lower()

    int_types = {"int", "bigint", "smallint", "tinyint", "mediumint", "integer"}
    str_types = {"varchar", "char", "text", "tinytext", "mediumtext", "longtext"}

    if fk_base == pk_base:
        return True
    if fk_base in int_types and pk_base in int_types:
        return True
    if fk_base in str_types and pk_base in str_types:
        return True
    return False
