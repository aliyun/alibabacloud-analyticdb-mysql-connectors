"""analyticdb-mysql-cli table profile command — generate statistical summaries of table data."""

from __future__ import annotations

import re
from typing import Any

import click
import pymysql

from analyticdb_mysql_cli import output
from analyticdb_mysql_cli.connection import get_connection
from analyticdb_mysql_cli.logger import log_operation

_NUMERIC_TYPES = re.compile(r"(int|decimal|float|double|numeric|bigint|smallint|tinyint|mediumint)", re.I)
_DATETIME_TYPES = re.compile(r"(date|time|datetime|timestamp|year)", re.I)


@click.group("table")
@click.pass_context
def table_cmd(ctx: click.Context) -> None:
    """Table data operations."""


@table_cmd.command("profile")
@click.argument("table")
@click.pass_context
def profile(ctx: click.Context, table: str) -> None:
    """Generate a statistical profile of a table (no raw data returned)."""
    fmt: str = ctx.obj["format"]
    dsn: str | None = ctx.obj["dsn"]

    try:
        conn = get_connection(dsn)
    except Exception as exc:
        log_operation("table profile", ok=False, error_code="CONNECTION_ERROR")
        output.error("CONNECTION_ERROR", str(exc), fmt=fmt)
        return

    timer = output.Timer()
    try:
        with timer, conn.cursor() as cur:
            cur.execute(
                "SELECT TABLE_COMMENT FROM INFORMATION_SCHEMA.TABLES "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s",
                (table,),
            )
            tinfo = cur.fetchone()
            if not tinfo:
                cur.execute("SHOW TABLES")
                tables_list = [list(r.values())[0] for r in cur.fetchall()]
                log_operation("table profile", ok=False, error_code="TABLE_NOT_FOUND")
                output.error(
                    "TABLE_NOT_FOUND",
                    f"Table '{table}' does not exist",
                    fmt=fmt,
                    extra={"schema": {"tables": tables_list}},
                )
                return

            cur.execute(f"SELECT COUNT(*) AS cnt FROM `{table}`")
            row_count = cur.fetchone()["cnt"]

            cur.execute(f"SHOW FULL COLUMNS FROM `{table}`")
            columns_meta = cur.fetchall()

            col_profiles: list[dict[str, Any]] = []
            candidate_join_keys: list[str] = []
            candidate_time_columns: list[str] = []

            for cmeta in columns_meta:
                col_name = cmeta["Field"]
                col_type = cmeta["Type"]
                comment = cmeta.get("Comment", "")

                profile_entry: dict[str, Any] = {
                    "name": col_name,
                    "type": col_type,
                }
                if comment:
                    profile_entry["comment"] = comment

                if row_count > 0:
                    cur.execute(
                        f"SELECT "
                        f"  COUNT(CASE WHEN `{col_name}` IS NULL THEN 1 END) / COUNT(*) AS null_ratio, "
                        f"  COUNT(DISTINCT `{col_name}`) AS distinct_count "
                        f"FROM `{table}`"
                    )
                    stats = cur.fetchone()
                    profile_entry["null_ratio"] = round(float(stats["null_ratio"] or 0), 4)
                    profile_entry["distinct"] = int(stats["distinct_count"] or 0)

                    if _NUMERIC_TYPES.search(col_type) or _DATETIME_TYPES.search(col_type):
                        cur.execute(
                            f"SELECT MIN(`{col_name}`) AS min_val, MAX(`{col_name}`) AS max_val "
                            f"FROM `{table}`"
                        )
                        minmax = cur.fetchone()
                        profile_entry["min"] = minmax["min_val"]
                        profile_entry["max"] = minmax["max_val"]

                    distinct = profile_entry["distinct"]
                    if distinct <= 20 and not _NUMERIC_TYPES.search(col_type):
                        cur.execute(
                            f"SELECT `{col_name}` AS val, COUNT(*) AS cnt "
                            f"FROM `{table}` WHERE `{col_name}` IS NOT NULL "
                            f"GROUP BY `{col_name}` ORDER BY cnt DESC LIMIT 10"
                        )
                        profile_entry["top_values"] = [
                            str(r["val"]) for r in cur.fetchall()
                        ]
                else:
                    profile_entry["null_ratio"] = 0
                    profile_entry["distinct"] = 0

                col_profiles.append(profile_entry)

                if col_name.endswith("_id") or col_name.endswith("_ID"):
                    candidate_join_keys.append(col_name)
                if _DATETIME_TYPES.search(col_type):
                    candidate_time_columns.append(col_name)

            data: dict[str, Any] = {
                "table": table,
                "row_count": row_count,
                "columns": col_profiles,
            }
            if candidate_join_keys:
                data["candidate_join_keys"] = candidate_join_keys
            if candidate_time_columns:
                data["candidate_time_columns"] = candidate_time_columns

        log_operation("table profile", ok=True, time_ms=timer.elapsed_ms)
        output.success(data, time_ms=timer.elapsed_ms, fmt=fmt)
    except SystemExit:
        raise
    except pymysql.err.Error as exc:
        log_operation("table profile", ok=False, error_code="SQL_ERROR")
        output.error("SQL_ERROR", str(exc), fmt=fmt)
    finally:
        conn.close()
