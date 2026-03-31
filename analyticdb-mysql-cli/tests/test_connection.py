"""Tests for DSN parsing."""

import pytest
from analyticdb_mysql_cli.connection import parse_dsn, DSNConfig


class TestParseDSN:
    def test_full_dsn(self):
        cfg = parse_dsn("mysql://root:mypass@10.0.0.1:3306/testdb")
        assert cfg.host == "10.0.0.1"
        assert cfg.port == 3306
        assert cfg.user == "root"
        assert cfg.password == "mypass"
        assert cfg.database == "testdb"

    def test_minimal_dsn(self):
        cfg = parse_dsn("mysql://localhost")
        assert cfg.host == "localhost"
        assert cfg.port == 3306
        assert cfg.user == "root"
        assert cfg.password == ""
        assert cfg.database == "test"

    def test_dsn_with_user_no_password(self):
        cfg = parse_dsn("mysql://admin@db.example.com:3306/prod")
        assert cfg.user == "admin"
        assert cfg.password == ""
        assert cfg.host == "db.example.com"
        assert cfg.port == 3306
        assert cfg.database == "prod"

    def test_dsn_with_empty_password(self):
        cfg = parse_dsn("mysql://root:@127.0.0.1:3306/test")
        assert cfg.user == "root"
        assert cfg.password == ""

    def test_dsn_url_encoded_password(self):
        cfg = parse_dsn("mysql://root:p%40ss%3Aword@host:3306/db")
        assert cfg.password == "p@ss:word"

    def test_dsn_at_in_username_before_sys_password(self):
        """Usernames like u@sys:secret@host — use rightmost @ before host."""
        cfg = parse_dsn(
            "mysql://u_b0d763c7@sys:xxxx@6.12.233.85:3306/db_b0d763c7"
        )
        assert cfg.user == "u_b0d763c7@sys"
        assert cfg.password == "xxxx"
        assert cfg.host == "6.12.233.85"
        assert cfg.port == 3306
        assert cfg.database == "db_b0d763c7"

    def test_dsn_at_in_username_no_password(self):
        cfg = parse_dsn("mysql://u@sys@10.0.0.2:3306/db")
        assert cfg.user == "u@sys"
        assert cfg.password == ""
        assert cfg.host == "10.0.0.2"

    def test_invalid_dsn(self):
        with pytest.raises(ValueError, match="Invalid DSN format"):
            parse_dsn("http://user:pass@host/db")

    def test_invalid_dsn_no_scheme(self):
        with pytest.raises(ValueError, match="Invalid DSN format"):
            parse_dsn("user:pass@host:3306/db")
