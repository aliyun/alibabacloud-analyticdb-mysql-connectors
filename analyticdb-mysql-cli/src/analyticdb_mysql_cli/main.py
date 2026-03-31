"""adbmysql-cli — AI-Agent-friendly database CLI for AnalyticDB MySQL."""

from __future__ import annotations

import json

import click
import pymysql

from analyticdb_mysql_cli import __version__, output
from analyticdb_mysql_cli.connection import get_connection, resolve_raw_dsn
from analyticdb_mysql_cli.logger import log_operation


@click.group(invoke_without_command=True)
@click.option(
    "--dsn", envvar="ADBMYSQL_DSN", default=None,
    help="Connection string. Format: mysql://user:pass@host:port/db",
)
@click.option("--format", "fmt", type=click.Choice(["json", "table", "csv", "jsonl"]), default="json", help="Output format.")
@click.version_option(__version__, message="version %(version)s")
@click.pass_context
def cli(ctx: click.Context, dsn: str | None, fmt: str) -> None:
    """adbmysql-cli — AI-Agent-friendly database CLI for AnalyticDB MySQL."""
    ctx.ensure_object(dict)
    ctx.obj["dsn"] = dsn
    ctx.obj["format"] = fmt

    if ctx.invoked_subcommand is None:
        click.echo(ctx.get_help())


@cli.command("status")
@click.pass_context
def status_cmd(ctx: click.Context) -> None:
    """Show connection status and version info."""
    fmt: str = ctx.obj["format"]
    dsn: str | None = ctx.obj["dsn"]

    info: dict = {"cli_version": __version__}

    try:
        resolve_raw_dsn(dsn)
        info["mode"] = "remote"
    except ValueError:
        info["mode"] = "unknown"

    try:
        conn = get_connection(dsn)
    except Exception as exc:
        info["connected"] = False
        info["error"] = str(exc)
        log_operation("status", ok=False, error_code="CONNECTION_ERROR")
        output.success(info, fmt=fmt)
        return

    timer = output.Timer()
    try:
        with timer:
            cur = conn.cursor()
            try:
                cur.execute("SELECT VERSION()")
                row = cur.fetchone()
                info["server_version"] = next(iter(row.values())) if row else "unknown"
                cur.execute("SELECT DATABASE()")
                row = cur.fetchone()
                info["database"] = next(iter(row.values())) if row else "unknown"
                try:
                    cur.execute("SELECT adb_version()")
                    row = cur.fetchone()
                    info["adb_version"] = row["source_version"] if row else "unknown"
                except pymysql.err.Error:
                    info["adb_version"] = "unknown"
                info["connected"] = True
            finally:
                cur.close()
    except (pymysql.err.Error, RuntimeError) as exc:
        info["connected"] = False
        info["error"] = str(exc)
    finally:
        conn.close()

    log_operation("status", ok=info.get("connected", False), time_ms=timer.elapsed_ms)
    output.success(info, time_ms=timer.elapsed_ms, fmt=fmt)


# ---------------------------------------------------------------------------
# ai-guide — structured self-description for AI Agents
# ---------------------------------------------------------------------------

_AI_GUIDE = {
    "name": "adbmysql-cli",
    "version": __version__,
    "description": "AI-Agent-friendly database CLI for AnalyticDB MySQL",
    "global_options": {
        "order": "Global options --dsn and --format must appear before the subcommand.",
        "usage_pattern": "adbmysql-cli [--dsn DSN] [--format json|table|csv|jsonl] <subcommand> [args]",
        "dsn_format": "mysql://user:pass@host:port/db",
        "examples": [
            "adbmysql-cli --format table sql \"SELECT * FROM t LIMIT 5\"",
            "adbmysql-cli --dsn \"mysql://root:@127.0.0.1:3306/test\" status",
        ],
    },
    "recommended_workflow": [
        "adbmysql-cli schema tables",
        "adbmysql-cli schema describe <table>",
        "adbmysql-cli table profile <table>",
        "adbmysql-cli sql \"SELECT ... LIMIT N\"",
    ],
    "commands": [
        {
            "name": "status",
            "usage": "adbmysql-cli status",
            "description": "Show connection status, server version, and database name.",
        },
        {
            "name": "sql",
            "usage": "adbmysql-cli sql [<statement>] [--write] [--with-schema] [--no-truncate] [--file <path>] [--stdin] (or pipe SQL on stdin)",
            "description": "Execute SQL. Read-only by default; add --write for mutations. Row protection auto-enforces LIMIT. Piped stdin is accepted without --stdin.",
        },
        {
            "name": "schema tables",
            "usage": "adbmysql-cli schema tables",
            "description": "List all tables with column count and row estimate.",
        },
        {
            "name": "schema describe",
            "usage": "adbmysql-cli schema describe <table>",
            "description": "Show table columns, types, indexes, and comments.",
        },
        {
            "name": "schema dump",
            "usage": "adbmysql-cli schema dump",
            "description": "Output CREATE TABLE DDL for all tables.",
        },
        {
            "name": "table profile",
            "usage": "adbmysql-cli table profile <table>",
            "description": "Statistical summary of a table: row count, null ratios, distinct counts, min/max, top values.",
        },
        {
            "name": "relations infer",
            "usage": "adbmysql-cli relations infer [--table <table>]",
            "description": "Infer JOIN relationships between tables using column name patterns.",
        },
        {
            "name": "ai-guide",
            "usage": "adbmysql-cli ai-guide",
            "description": "Output this structured guide for AI Agents (JSON).",
        },
    ],
    "output_format": {
        "success": {"ok": True, "data": "...", "time_ms": "N"},
        "error": {"ok": False, "error": {"code": "...", "message": "..."}},
    },
    "safety": {
        "row_protection": "Queries without LIMIT are probed at 1001 rows; if exceeded, LIMIT_REQUIRED error is returned.",
        "write_protection": "Write operations require --write flag. DELETE/UPDATE without WHERE are blocked.",
        "masking": "Sensitive fields (phone, email, password, id_card) are auto-masked in output.",
    },
    "exit_codes": {"0": "success", "1": "business error", "2": "usage error"},
    "tips": {
        "detailed_help": "Run 'adbmysql-cli <subcommand> --help' for detailed options. Examples: adbmysql-cli sql --help | adbmysql-cli schema describe --help | adbmysql-cli table profile --help",
    },
}


@cli.command("ai-guide")
@click.pass_context
def ai_guide_cmd(ctx: click.Context) -> None:
    """Output structured AI Agent usage guide (JSON)."""
    fmt: str = ctx.obj["format"]
    log_operation("ai-guide", ok=True)
    print(json.dumps(_AI_GUIDE, ensure_ascii=False, indent=2))
    raise SystemExit(0)


# ---------------------------------------------------------------------------
# Register all sub-commands
# ---------------------------------------------------------------------------

from analyticdb_mysql_cli.commands.sql import sql_cmd  # noqa: E402
from analyticdb_mysql_cli.commands.schema import schema_cmd  # noqa: E402
from analyticdb_mysql_cli.commands.profile import table_cmd  # noqa: E402
from analyticdb_mysql_cli.commands.relations import relations_cmd  # noqa: E402

cli.add_command(sql_cmd)
cli.add_command(schema_cmd)
cli.add_command(table_cmd)
cli.add_command(relations_cmd)
