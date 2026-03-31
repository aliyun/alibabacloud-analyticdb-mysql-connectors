"""Tests for operation logger and SQL redaction in sql-history.jsonl."""

from analyticdb_mysql_cli.logger import _redact_sql


class TestRedactSql:
    def test_phone_redacted(self):
        sql = "INSERT INTO t (phone) VALUES ('13812345678')"
        assert "138****5678" in _redact_sql(sql)
        assert "13812345678" not in _redact_sql(sql)

    def test_id_card_redacted(self):
        sql = "INSERT INTO t (id_card) VALUES ('110101199001011234')"
        out = _redact_sql(sql)
        assert out.startswith("INSERT INTO t (id_card) VALUES ('110")
        assert "110101199001011234" not in out
        assert "1234'" in out

    def test_email_redacted(self):
        sql = "SELECT * FROM u WHERE email = 'zhang@gmail.com'"
        out = _redact_sql(sql)
        assert "z***@gmail.com" in out
        assert "zhang@gmail.com" not in out

    def test_password_context_redacted(self):
        sql = "INSERT INTO mask_demo (id, name, phone, id_card, password, email) VALUES (1, '张三', '13812345678', '110101199001011234', 'super_secret_123', 'zhang@gmail.com')"
        out = _redact_sql(sql)
        assert "super_secret_123" not in out
        assert "******" in out
        assert "张三" in out

    def test_non_sensitive_unchanged(self):
        sql = "SELECT * FROM test_table LIMIT 5"
        assert _redact_sql(sql) == sql
