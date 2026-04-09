# adb-parquet-import

Parquet 文件批量导入 AnalyticDB MySQL (ADB) 的命令行工具。

支持一条 SQL 语句包含多个 VALUES 的攒批写入，可配置 INSERT/REPLACE 模式和攒批数量，支持多线程并发写入，覆盖 Parquet 到 ADB 的全部数据类型映射。

## 前置条件

- [uv](https://docs.astral.sh/uv/) (Python 包管理工具)

无需手动安装 Python 或依赖，`uv run` 会自动处理。

## 快速开始

```bash
# 基本导入（CLI 参数指定连接信息）
uv run adb_parquet_import.py \
  -f data.parquet \
  -H 10.0.0.1 \
  -u analyst \
  -d mydb \
  -t target_table

# 使用配置文件（连接信息写在 .adb.ini 中）
uv run adb_parquet_import.py -f data.parquet -t target_table

# 使用环境变量
export ADB_HOST=10.0.0.1 ADB_USER=analyst ADB_DATABASE=mydb ADB_PASSWORD=secret
uv run adb_parquet_import.py -f data.parquet -t target_table

# REPLACE 模式 + 自定义批次大小
uv run adb_parquet_import.py \
  -f data.parquet \
  -t target_table \
  --mode replace \
  --batch-size 5000

# 2 线程并发写入
uv run adb_parquet_import.py \
  -f data.parquet \
  -t target_table \
  --threads 2

# 8 线程 + 大批次，最大化吞吐
uv run adb_parquet_import.py \
  -f data.parquet \
  -t target_table \
  --threads 8 \
  --batch-size 5000

# 自动建表（根据 Parquet schema 生成 DDL）
uv run adb_parquet_import.py \
  -f data.parquet \
  -t target_table \
  --create-table

# 先删表再建表
uv run adb_parquet_import.py \
  -f data.parquet \
  -t target_table \
  --drop-table

# 仅预览 SQL（不执行，不需要数据库连接）
uv run adb_parquet_import.py \
  -f data.parquet \
  -H 10.0.0.1 \
  -u analyst \
  -d mydb \
  -t target_table \
  --create-table \
  --dry-run

# 只导入指定列
uv run adb_parquet_import.py \
  -f data.parquet \
  -t target_table \
  --columns "id,name,amount"
```

## 配置方式

支持三种方式配置 ADB 连接信息，优先级从高到低：**CLI 参数 > 环境变量 > 配置文件 > 默认值**。

### 配置文件

默认查找 `.adb.ini`（先查当前目录，再查 `$HOME` 目录），也可通过 `-c`/`--config` 指定路径：

```ini
[connection]
host = 10.0.0.1
port = 3306
user = analyst
password = secret
database = mydb
charset = utf8mb4

[import]
mode = insert
batch_size = 1000
threads = 2
```

```bash
# 使用默认配置文件 (.adb.ini)
uv run adb_parquet_import.py -f data.parquet -t my_table

# 指定配置文件路径
uv run adb_parquet_import.py -f data.parquet -t my_table --config /path/to/my_adb.ini
```

### 环境变量

| 环境变量 | 对应参数 |
|----------|----------|
| `ADB_HOST` | `--host` |
| `ADB_PORT` | `--port` |
| `ADB_USER` | `--user` |
| `ADB_PASSWORD` | `--password` |
| `ADB_DATABASE` | `--database` |
| `ADB_CHARSET` | `--charset` |
| `ADB_MODE` | `--mode` |
| `ADB_BATCH_SIZE` | `--batch-size` |
| `ADB_THREADS` | `--threads` |

```bash
export ADB_HOST=10.0.0.1
export ADB_USER=analyst
export ADB_PASSWORD=secret
export ADB_DATABASE=mydb
uv run adb_parquet_import.py -f data.parquet -t my_table
```

### 混合使用

可以在配置文件中存放固定的连接信息，用环境变量覆盖敏感信息（如密码），再用 CLI 参数覆盖单次运行的特定值：

```bash
# 配置文件提供 host/user/database，环境变量提供密码，CLI 指定 mode
ADB_PASSWORD=secret uv run adb_parquet_import.py \
  -f data.parquet -t my_table --mode replace
```

## 参数说明

### 数据源

| 参数 | 短标记 | 必填 | 默认值 | 说明 |
|------|--------|------|--------|------|
| `--file` | `-f` | 是 | - | Parquet 文件路径 |

### 数据库连接

| 参数 | 短标记 | 必填 | 默认值 | 说明 |
|------|--------|------|--------|------|
| `--host` | `-H` | 是* | - | ADB MySQL 主机地址 |
| `--port` | `-P` | 否 | `3306` | ADB MySQL 端口 |
| `--user` | `-u` | 是* | - | 数据库用户名 |
| `--password` | `-p` | 否 | 见下文 | 数据库密码 |
| `--database` | `-d` | 是* | - | 目标数据库名 |
| `--charset` | | 否 | `utf8mb4` | 连接字符集 |
| `--config` | `-c` | 否 | `.adb.ini` | 配置文件路径 |

*标注"是*"的参数可通过环境变量或配置文件提供，不一定需要 CLI 传入。

**密码获取优先级：** `--password` 参数 > `ADB_PASSWORD` 环境变量 > 配置文件 > 交互式输入（getpass）

### 目标表

| 参数 | 短标记 | 必填 | 默认值 | 说明 |
|------|--------|------|--------|------|
| `--table` | `-t` | 是 | - | 目标表名 |

### 导入行为

| 参数 | 短标记 | 默认值 | 说明 |
|------|--------|--------|------|
| `--mode` | `-m` | `insert` | `insert` 或 `replace`，控制使用 INSERT INTO 还是 REPLACE INTO |
| `--batch-size` | `-b` | `1000` | 每条 SQL 语句的 VALUES 行数 |
| `--create-table` | | `False` | 根据 Parquet schema 自动生成 DDL 并建表 |
| `--drop-table` | | `False` | 建表前先 DROP TABLE（隐含 `--create-table`） |
| `--columns` | | 全部列 | 指定要导入的 Parquet 列名，逗号分隔 |
| `--threads` | `-j` | `1` | 并发写入线程数，每个线程使用独立的数据库连接 |
| `--on-error` | | `abort` | 遇到损坏的 Row Group 时的行为：`abort` 直接报错终止，`skip` 跳过并继续 |

### 运维选项

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--dry-run` | `False` | 只打印生成的 SQL，不连接数据库（打印前 3 批） |
| `--log-level` | `INFO` | 日志级别：`DEBUG` / `INFO` / `WARNING` / `ERROR` |
| `--no-progress` | `False` | 禁用 tqdm 进度条 |

## 类型映射

### 标量类型

| Parquet (PyArrow) 类型 | ADB MySQL 类型 | 说明 |
|------------------------|----------------|------|
| `bool` | `BOOLEAN` | `True`/`False` → `1`/`0` |
| `int8` | `TINYINT` | |
| `int16` | `SMALLINT` | |
| `int32` | `INT` | |
| `int64` | `BIGINT` | |
| `uint8` | `SMALLINT` | ADB 仅有有符号整型，上提一级 |
| `uint16` | `INT` | 同上 |
| `uint32` | `BIGINT` | 同上 |
| `uint64` | `DECIMAL(20,0)` | 避免 BIGINT 溢出 |
| `float16` | `FLOAT` | |
| `float32` / `float` | `FLOAT` | NaN / Inf → `NULL` |
| `float64` / `double` | `DOUBLE` | NaN / Inf → `NULL` |
| `decimal128(p,s)` | `DECIMAL(p,s)` | |
| `decimal256(p,s)` | `DECIMAL(min(p,38),s)` | 精度超过 38 自动截断并警告 |
| `string` / `large_string` | `VARCHAR` | 使用 pymysql `escape_string` 转义 |
| `binary` / `large_binary` / `fixed_size_binary` | `BINARY` | 输出为 hex 字面量 `X'...'` |
| `date32` / `date64` | `DATE` | 格式 `YYYY-MM-DD` |
| `time32` / `time64` | `TIME` | 格式 `HH:MM:SS[.ffffff]` |
| `timestamp` (无时区) | `DATETIME` | 格式 `YYYY-MM-DD HH:MM:SS.ffffff` |
| `timestamp` (有时区) | `TIMESTAMP` | 同上 |
| `duration` | `BIGINT` | 转换为微秒整数 |
| `null` | `VARCHAR` | 始终输出 `NULL` |

### 复杂类型

| Parquet (PyArrow) 类型 | ADB MySQL 类型 | 说明 |
|------------------------|----------------|------|
| `list` / `large_list` / `fixed_size_list` | `JSON` | `json.dumps()` 序列化 |
| `struct` | `JSON` | `json.dumps()` 序列化 |
| `map` | `JSON` | 转为数组后 `json.dumps()` 序列化 |

### 特殊值处理

- **NULL**: 所有类型统一输出 SQL `NULL`
- **NaN / Inf / -Inf**: 浮点数特殊值转换为 `NULL`（ADB 不支持 IEEE 754 特殊值）
- **未知类型**: 回退为 `VARCHAR`，以字符串形式写入

## 攒批写入原理

工具使用一条 SQL 语句包含多个 VALUES 的方式批量写入，而非逐行 INSERT：

```sql
INSERT INTO `table` (`c1`, `c2`, `c3`) VALUES
(1, 'hello', 3.14),
(2, 'world', 2.72),
(3, 'foo', 1.41);
```

`--batch-size` 控制每条 SQL 中包含的行数。Parquet 文件通过 `iter_batches` 流式读取，内存占用与批次大小成正比，不受文件总大小影响。

## 多线程并发写入

通过 `-j`/`--threads` 参数可开启多线程并发写入，提升导入吞吐量：

```bash
uv run adb_parquet_import.py -f data.parquet -t target_table -j 2
```

**工作原理：**

- **主线程**负责顺序读取 Parquet 文件并构建 SQL 语句（CPU 密集）
- **工作线程池**中的多个线程并发执行 SQL 写入到 ADB（IO 密集）
- 每个工作线程持有**独立的数据库连接**（pymysql 连接非线程安全）
- 进度条和结果统计均为线程安全

**线程数选择建议：**

| 场景 | 建议线程数 |
|------|------------|
| 窄表、小批次 | 4-8 |
| 宽表、大批次 | 2-4 |
| 网络延迟较高 | 适当增大 |
| ADB 集群负载已高 | 保持 1-2 |

## 错误处理

| 场景 | 行为 |
|------|------|
| Parquet 文件不存在或格式错误 | 立即退出，exit code 2 |
| Parquet Row Group 数据损坏 | 默认报错终止；`--on-error=skip` 时跳过损坏部分，继续导入其余数据 |
| 数据库连接/认证失败 | 立即退出，exit code 2 |
| 某批次执行失败 | rollback 该批，记录错误日志，继续下一批 |
| 数据库连接断开 | 自动重连一次，失败则退出 |
| Ctrl+C 中断 | rollback 当前事务，打印已完成进度，exit code 130 |
| 空 Parquet 文件 | 如指定 `--create-table` 仍建表，正常退出 |

### Exit Code

| Code | 含义 |
|------|------|
| `0` | 全部成功 |
| `1` | 部分批次失败 |
| `2` | 致命错误（文件/连接/全部失败） |
| `130` | 用户中断 (Ctrl+C) |

## 导入摘要

每次运行结束后打印摘要：

```
==================================================
Import Summary
==================================================
  File:            /path/to/data.parquet
  Table:           mydb.target_table
  Total rows:      1,000,000
  Rows imported:   998,000
  Rows failed:     2,000 (2 batches)
  Elapsed time:    45.3s
  Throughput:      22,030 rows/sec
  Mode:            INSERT
  Batch size:      1,000
  Threads:         2
==================================================
```

## 注意事项

- **REPLACE 模式**：目标表必须有主键或唯一索引才能发挥 REPLACE 的去重语义，否则等同于 INSERT。
- **自动建表的分布键**：`--create-table` 生成的 DDL 默认使用第一列作为 `DISTRIBUTE BY HASH` 的分布键。如需指定其他分布策略，请手动建表。
- **ADB `max_allowed_packet`**：大批次 + 宽表可能导致单条 SQL 超过 ADB 的 `max_allowed_packet` 限制（默认 64MB），可通过减小 `--batch-size` 解决。
- **多线程连接数**：`--threads N` 会创建 N 个数据库连接，请确保 ADB 实例的连接数上限足够。
