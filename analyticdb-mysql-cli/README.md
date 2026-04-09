English | [简体中文](README_CN.md)
# analyticdb-mysql-cli

AI-Agent-friendly database CLI for AnalyticDB MySQL. Default JSON output, stateless invocations, and a consistent error format make it easy for agents to run SQL and inspect schema reliably.

AnalyticDB MySQL is Alibaba Cloud's cloud-native data warehouse product.

## Why analyticdb-mysql-cli

- **Agent-friendly**: Any agent that can run shell commands can use analyticdb-mysql-cli via the `adbmysql-cli` command (the `analyticdb-mysql-cli` command is the same entry point, useful for `which analyticdb-mysql-cli`–style checks); output is JSON by default, and the `analyticdb-mysql-cli ai-guide` command provides a self-description of analyticdb-mysql-cli usage for agents.
- **Safety**: Row limits, write guards, and masking reduce risk when agents or scripts operate on live data.
- **Unified interface**: Execute SQL via CLI, without interactive prompts or session state.

## Features

- **JSON by default**: All commands emit structured JSON; use `--format table|csv|jsonl` for human-readable output.
- **Row limits**: LIMIT required when result exceeds 1000 rows.
- **Write safeguards**: Writes require `--write`; DELETE/UPDATE without WHERE are disallowed.
- **Sensitive-field masking**: Columns such as phone, email, password, id_card are auto-masked in query results.
- **Operation history**: All commands are logged to `~/.adbmysql/sql-history.jsonl`; for **SQL execution**, the SQL text is logged with sensitive literals redacted.

## Requirements

- Python 3.11+
- AnalyticDB MySQL instance (MySQL-protocol–compatible)

## Installation

From PyPI:

```bash
uv tool install analyticdb-mysql-cli
```

From local source:

```bash
cd analyticdb-mysql-cli
uv tool install .
```

After installation, the `analyticdb-mysql-cli` command is available. The same program is also installed as `analyticdb-mysql-cli` (e.g. for tooling that probes the binary name matching the PyPI package).

## Connection

To connect to an AnalyticDB MySQL instance, create a global config file:

```bash
mkdir -p ~/.adbmysql
# Remote
echo 'ADBMYSQL_DSN="mysql://user:pass@host:port/database"' > ~/.adbmysql/config.env
```

Also supports `--dsn` CLI flag, `ADBMYSQL_DSN` environment variable, and project `.env` files, in decreasing priority.

## Common commands

| Command | Description |
|--------|-------------|
| `analyticdb-mysql-cli status` | Connection status and version |
| `analyticdb-mysql-cli schema tables` | List all tables |
| `analyticdb-mysql-cli schema describe <table>` | Table structure (columns, types, indexes) |
| `analyticdb-mysql-cli schema dump` | Output DDL for all tables (to stdout) |
| `analyticdb-mysql-cli table profile <table>` | Table data profile (row count, nulls, distinct, min/max, candidate JOIN keys and time columns) |
| `analyticdb-mysql-cli sql "<stmt>"` | Execute SQL (read-only by default; use `--write` for writes; `--with-schema` adds table schema; `--no-truncate` keeps large fields intact) |
| `analyticdb-mysql-cli relations infer [--table <t>]` | Infer JOIN relationships between tables |
| `analyticdb-mysql-cli ai-guide` | Print structured guide for AI agents (JSON) |

## Option order

`--dsn` and `--format` are global options and must appear **before** the subcommand:

```bash
analyticdb-mysql-cli --format table sql "SELECT * FROM t LIMIT 5"
analyticdb-mysql-cli --dsn "mysql://root:@127.0.0.1:3306/test" schema tables
```
