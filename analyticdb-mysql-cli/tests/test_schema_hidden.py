"""Tests for internal table filtering in schema commands."""

import pytest

from analyticdb_mysql_cli.commands.schema import _is_hidden_schema_table


@pytest.mark.parametrize(
    "name,hidden",
    [
        ("__internal_table", True),
        ("__system", True),
        ("__META", True),
        ("my_table", False),
        ("users", False),
        ("_single_underscore", False),
        ("normal_table", False),
    ],
)
def test_is_hidden_schema_table(name: str, hidden: bool) -> None:
    assert _is_hidden_schema_table(name) is hidden
