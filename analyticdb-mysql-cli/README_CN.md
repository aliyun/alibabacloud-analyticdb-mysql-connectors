[English](README.md) | 简体中文
# analyticdb-mysql-cli

AI Agent 友好的 AnalyticDB MySQL 数据库命令行工具。默认 JSON 输出、无状态调用、统一错误格式，便于 Agent 可靠地执行 SQL、查看 schema。

AnalyticDB MySQL 是阿里云的云原生数据仓库产品。

## 为什么选择 analyticdb-mysql-cli

- **面向 Agent**：任何能执行 Shell 的 Agent 均可通过 `adbmysql-cli` 命令使用 analyticdb-mysql-cli；（同时提供同名入口 `analyticdb-mysql-cli`，便于 `which analyticdb-mysql-cli` 等探测）。默认输出 JSON 格式，`analyticdb-mysql-cli ai-guide` 命令给 Agent 提供 analyticdb-mysql-cli 用法的自描述。
- **安全可控**：行数限制、写操作保护与敏感字段脱敏，降低 Agent 或脚本操作生产数据的风险。
- **统一入口**：通过 CLI 执行 SQL，无需交互式提示或会话状态。

## 特性

- **默认 JSON**：所有命令输出结构化 JSON，`--format table|csv|jsonl` 可切换人类可读格式
- **行数保护**：超过 1000 行要求补充 LIMIT
- **写操作保护**：写操作需 `--write`；禁止无 WHERE 的 DELETE/UPDATE
- **敏感字段脱敏**：查询结果中 phone、email、password、id_card 等自动掩码
- **操作历史**：所有命令的操作记录到 `~/.adbmysql/sql-history.jsonl`；其中 **SQL 执行** 会记录 SQL 文本，并对 SQL 中敏感字面量脱敏

## 环境要求

- Python 3.11+
- AnalyticDB MySQL 实例（兼容 MySQL 协议）

## 安装

从 PyPI 安装：

```bash
uv tool install analyticdb-mysql-cli
```

从本地源码安装：

```bash
cd analyticdb-mysql-cli
uv tool install .
```

安装后可使用 `analyticdb-mysql-cli` 命令；亦提供 `analyticdb-mysql-cli` 作为同一程序的别名（例如与 PyPI 包名一致、供脚本或工具探测）。

## 连接

如需连接 AnalyticDB MySQL 实例，创建全局配置文件：

```bash
mkdir -p ~/.adbmysql
# 远程
echo 'ADBMYSQL_DSN="mysql://user:pass@host:port/database"' > ~/.adbmysql/config.env
```

也支持 `--dsn` 命令行参数、`ADBMYSQL_DSN` 环境变量、项目 `.env` 文件等方式，优先级依次递减。

## 常用命令

| 命令 | 说明 |
|------|------|
| `analyticdb-mysql-cli status` | 连接状态与版本 |
| `analyticdb-mysql-cli schema tables` | 列出所有表 |
| `analyticdb-mysql-cli schema describe <table>` | 表结构（列、类型、索引） |
| `analyticdb-mysql-cli schema dump` | 输出所有表的 DDL |
| `analyticdb-mysql-cli table profile <table>` | 表数据画像（行数、空值、distinct、min/max、候选 JOIN 键与时间列） |
| `analyticdb-mysql-cli sql "<stmt>"` | 执行 SQL（只读默认；加 `--write` 允许写；`--with-schema` 附带表 schema；`--no-truncate` 不截断大字段） |
| `analyticdb-mysql-cli relations infer [--table <t>]` | 推断表间 JOIN 关系 |
| `analyticdb-mysql-cli ai-guide` | 输出 AI Agent 用结构化指南（JSON） |

## 选项顺序

`--dsn`、`--format` 为主命令的全局选项，必须写在子命令**之前**：

```bash
analyticdb-mysql-cli --format table sql "SELECT * FROM t LIMIT 5"
analyticdb-mysql-cli --dsn "mysql://root:@127.0.0.1:3306/test" schema tables
```
