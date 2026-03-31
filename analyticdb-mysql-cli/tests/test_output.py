"""Tests for output formatting."""

import json
import pytest
from unittest.mock import patch
from io import StringIO

from analyticdb_mysql_cli.output import Timer


class TestTimer:
    def test_timer_measures_ms(self):
        import time
        t = Timer()
        with t:
            time.sleep(0.05)
        assert t.elapsed_ms >= 40


class TestJsonDumps:
    def test_non_ascii(self):
        from analyticdb_mysql_cli.output import _json_dumps
        result = _json_dumps({"name": "张三"})
        assert "张三" in result
        assert "\\u" not in result
