"""Tests for SQL parsing utilities in the sql command."""

from analyticdb_mysql_cli.commands.sql import (
    _is_write,
    _is_select,
    _has_limit,
    _has_where,
    _extract_tables_from_sql,
    _split_sql_statements,
)


class TestIsWrite:
    def test_insert(self):
        assert _is_write("INSERT INTO users (name) VALUES ('Alice')")

    def test_update(self):
        assert _is_write("UPDATE users SET name = 'Bob' WHERE id = 1")

    def test_delete(self):
        assert _is_write("DELETE FROM users WHERE id = 1")

    def test_drop(self):
        assert _is_write("DROP TABLE users")

    def test_truncate(self):
        assert _is_write("TRUNCATE TABLE users")

    def test_select_is_not_write(self):
        assert not _is_write("SELECT * FROM users")

    def test_show_is_not_write(self):
        assert not _is_write("SHOW TABLES")

    def test_case_insensitive(self):
        assert _is_write("insert into users values (1)")
        assert _is_write("  DELETE FROM t")

    def test_fork_table(self):
        assert _is_write("FORK TABLE source_table TO destination_table;")
        assert _is_write("  fork TABLE t1 TO t1_fork")


class TestIsSelect:
    def test_select(self):
        assert _is_select("SELECT id, name FROM users")

    def test_select_with_whitespace(self):
        assert _is_select("  SELECT 1")

    def test_insert_is_not_select(self):
        assert not _is_select("INSERT INTO t VALUES (1)")


class TestHasLimit:
    def test_with_limit(self):
        assert _has_limit("SELECT * FROM users LIMIT 10")

    def test_without_limit(self):
        assert not _has_limit("SELECT * FROM users")

    def test_limit_case_insensitive(self):
        assert _has_limit("select * from t limit 50")


class TestHasWhere:
    def test_with_where(self):
        assert _has_where("DELETE FROM users WHERE id = 1")

    def test_without_where(self):
        assert not _has_where("DELETE FROM users")


class TestExtractTables:
    def test_select_from(self):
        tables = _extract_tables_from_sql("SELECT * FROM users WHERE id = 1")
        assert "users" in tables

    def test_insert_into(self):
        tables = _extract_tables_from_sql("INSERT INTO orders (id) VALUES (1)")
        assert "orders" in tables

    def test_update(self):
        tables = _extract_tables_from_sql("UPDATE products SET price = 10 WHERE id = 1")
        assert "products" in tables

    def test_backtick_table(self):
        tables = _extract_tables_from_sql("SELECT * FROM `my_table`")
        assert "my_table" in tables


class TestSplitSqlStatements:
    def test_single_select(self):
        assert _split_sql_statements("SELECT 1") == ["SELECT 1"]

    def test_trailing_semicolon(self):
        assert _split_sql_statements("SELECT 1;") == ["SELECT 1"]

    def test_set_then_select(self):
        s = "SET @a = 1; SELECT @a AS v"
        assert _split_sql_statements(s) == ["SET @a = 1", "SELECT @a AS v"]

    def test_semicolon_inside_single_quoted_string(self):
        s = "SELECT 'a;b' AS x; SELECT 2"
        assert _split_sql_statements(s) == ["SELECT 'a;b' AS x", "SELECT 2"]

    def test_json_in_set_single_quoted(self):
        s = (
            "SET @p = '{\"k\":1}'; "
            "SELECT json_pretty(@p)"
        )
        parts = _split_sql_statements(s)
        assert len(parts) == 2
        assert parts[0].startswith("SET @p")
        assert "SELECT json_pretty" in parts[1]

    def test_doubled_quote_in_string(self):
        s = "SELECT '''' AS q; SELECT 1"
        assert _split_sql_statements(s) == ["SELECT '''' AS q", "SELECT 1"]
