"""Tests for profile module patterns."""

import re

from analyticdb_mysql_cli.commands.profile import _NUMERIC_TYPES, _DATETIME_TYPES


class TestTypePatterns:
    def test_numeric_types(self):
        assert _NUMERIC_TYPES.search("int")
        assert _NUMERIC_TYPES.search("INT")
        assert _NUMERIC_TYPES.search("bigint")
        assert _NUMERIC_TYPES.search("decimal(10,2)")
        assert _NUMERIC_TYPES.search("float")
        assert _NUMERIC_TYPES.search("double")
        assert _NUMERIC_TYPES.search("smallint")
        assert _NUMERIC_TYPES.search("tinyint")
        assert not _NUMERIC_TYPES.search("varchar(64)")
        assert not _NUMERIC_TYPES.search("text")
        assert not _NUMERIC_TYPES.search("datetime")

    def test_datetime_types(self):
        assert _DATETIME_TYPES.search("datetime")
        assert _DATETIME_TYPES.search("DATETIME")
        assert _DATETIME_TYPES.search("timestamp")
        assert _DATETIME_TYPES.search("date")
        assert _DATETIME_TYPES.search("time")
        assert not _DATETIME_TYPES.search("varchar(64)")
        assert not _DATETIME_TYPES.search("int")
