---
name: analyticdb-mysql-cli
description: Use the analyticdb-mysql-cli command-line tool to interact with AnalyticDB MySQL databases. Provides SQL execution, schema inspection, table profiling, and relationship inference. Use when the user wants to query a database, inspect table structures, analyze data, or perform any AnalyticDB MySQL database operations via CLI.
---

# AnalyticDB MySQL CLI

AI Agent 友好的 AnalyticDB MySQL 命令行工具，默认 JSON 输出、无状态调用、统一错误格式。

## 连接配置

DSN 优先级（从高到低）：`--dsn` 参数 > `ADBMYSQL_DSN` 环境变量 > 项目 `.env` 文件 > `~/.adbmysql/config.env`

DSN 格式：`mysql://user:pass@host:port/database`

首次使用前，配置全局连接：

```bash
mkdir -p ~/.adbmysql
echo 'ADBMYSQL_DSN="mysql://user:pass@host:port/database"' > ~/.adbmysql/config.env
```

## 全局选项

`--dsn` 和 `--format` 必须写在子命令**之前**：

```bash
analyticdb-mysql-cli --format table sql "SELECT 1"
analyticdb-mysql-cli --dsn "mysql://root:@127.0.0.1:3306/test" schema tables
```

`--format` 支持：`json`（默认）、`table`、`csv`、`jsonl`

## 命令速查

### 连接状态

```bash
analyticdb-mysql-cli status
```

### Schema 检查

```bash
# 列出所有表（含列数和行数估计）
analyticdb-mysql-cli schema tables

# 查看表结构（列名、类型、注释、索引）
analyticdb-mysql-cli schema describe <table>

# 导出所有表 DDL
analyticdb-mysql-cli schema dump
```

### SQL 执行

```bash
# 只读查询（默认）
analyticdb-mysql-cli sql "SELECT * FROM orders LIMIT 10"

# 写操作需加 --write
analyticdb-mysql-cli sql --write "INSERT INTO t(id, name) VALUES (1, 'foo')"

# 附带表 schema 信息
analyticdb-mysql-cli sql --with-schema "SELECT * FROM orders LIMIT 5"

# 不截断大字段（默认截断 TEXT/BLOB > 3000 字符）
analyticdb-mysql-cli sql --no-truncate "SELECT content FROM articles LIMIT 1"

# 从文件执行
analyticdb-mysql-cli sql --file script.sql

# 从 stdin 执行
cat script.sql | analyticdb-mysql-cli sql --stdin
```

### 表数据画像

```bash
# 统计摘要：行数、空值率、distinct、min/max、候选 JOIN 键、时间列
analyticdb-mysql-cli table profile <table>
```

### 关系推断

```bash
# 推断所有表间 JOIN 关系
analyticdb-mysql-cli relations infer

# 仅推断指定表的关系
analyticdb-mysql-cli relations infer --table <table>
```

### AI 指南

```bash
# 输出结构化的 AI Agent 使用指南
analyticdb-mysql-cli ai-guide
```

## 安全机制

1. **行数限制**：SELECT 结果超过 1000 行时，必须显式指定 LIMIT，否则返回 `LIMIT_REQUIRED` 错误
2. **写操作保护**：INSERT/UPDATE/DELETE/DROP 等写操作必须加 `--write` 标志
3. **危险操作拦截**：DELETE/UPDATE 无 WHERE 子句会被拒绝
4. **敏感字段脱敏**：phone、email、password、id_card 等列自动掩码
5. **大字段截断**：TEXT/BLOB 超过 3000 字符默认截断（`--no-truncate` 禁用）

## 输出格式

JSON 输出结构：

```json
{
  "ok": true,
  "data": { ... },
  "time_ms": 42
}
```

错误时：

```json
{
  "ok": false,
  "error": { "code": "ERROR_CODE", "message": "..." },
  "time_ms": 10
}
```

使用 `--format table` 可获得人类可读的表格输出。

## 典型工作流

### 1. 探索数据库

```bash
analyticdb-mysql-cli status                          # 确认连接
analyticdb-mysql-cli schema tables                   # 查看有哪些表
analyticdb-mysql-cli schema describe orders          # 查看表结构
analyticdb-mysql-cli table profile orders            # 数据画像
analyticdb-mysql-cli relations infer                 # 表间关系
```

### 2. 查询数据

```bash
analyticdb-mysql-cli sql "SELECT * FROM orders WHERE status='paid' LIMIT 20"
analyticdb-mysql-cli --format table sql "SELECT count(*) as cnt FROM orders"
```

### 3. 写入数据

```bash
analyticdb-mysql-cli sql --write "INSERT INTO orders(id, amount) VALUES (100, 99.9)"
analyticdb-mysql-cli sql --write "UPDATE orders SET status='shipped' WHERE id=100"
```

## 安装

```bash
# 从 PyPI
uv tool install analyticdb-mysql-cli

# 从本地源码
cd analyticdb-mysql-cli && uv tool install .
```

安装后 `analyticdb-mysql-cli` 和 `analyticdb-mysql-cli` 两个命令均可用。

## 操作历史

所有操作记录到 `~/.adbmysql/sql-history.jsonl`，SQL 文本中的敏感字面量会自动脱敏。
