"""Tests for relations inference logic."""

from analyticdb_mysql_cli.commands.relations import (
    _find_candidate_tables,
    _match_fk_pattern,
    _types_compatible,
)


class TestTypesCompatible:
    def test_same_type(self):
        assert _types_compatible("int", "int") is True

    def test_int_family(self):
        assert _types_compatible("int", "bigint") is True
        assert _types_compatible("smallint", "int") is True
        assert _types_compatible("tinyint", "mediumint") is True

    def test_string_family(self):
        assert _types_compatible("varchar(64)", "varchar(128)") is True
        assert _types_compatible("char(10)", "varchar(20)") is True

    def test_incompatible(self):
        assert _types_compatible("int", "varchar(64)") is False
        assert _types_compatible("datetime", "int") is False


class TestFindCandidateTables:
    def test_plural_match(self):
        tables = ["users", "orders", "products"]
        candidates = _find_candidate_tables("user", tables, "orders")
        assert any(t == "users" for t, _ in candidates)

    def test_exact_match(self):
        tables = ["user", "order", "product"]
        candidates = _find_candidate_tables("user", tables, "orders")
        assert any(t == "user" for t, _ in candidates)

    def test_no_self_match(self):
        tables = ["users", "orders"]
        candidates = _find_candidate_tables("order", tables, "orders")
        assert all(t != "orders" for t, _ in candidates)

    def test_ies_plural(self):
        tables = ["categories", "products"]
        candidates = _find_candidate_tables("category", tables, "products")
        assert any(t == "categories" for t, _ in candidates)

    def test_high_confidence(self):
        tables = ["users", "orders"]
        candidates = _find_candidate_tables("user", tables, "orders")
        matched = [(t, c) for t, c in candidates if t == "users"]
        assert matched and matched[0][1] == "high"


class TestMatchFkPattern:
    def test_user_id(self):
        pk_map = {"users": {"column": "id", "type": "int"}}
        result = _match_fk_pattern("user_id", "orders", ["users", "orders"], pk_map, "int")
        assert result is not None
        assert result["to_table"] == "users"
        assert result["to_column"] == "id"
        assert result["confidence"] == "high"

    def test_non_id_column(self):
        pk_map = {"users": {"column": "id", "type": "int"}}
        result = _match_fk_pattern("user_name", "orders", ["users", "orders"], pk_map, "varchar(64)")
        assert result is None

    def test_type_mismatch(self):
        pk_map = {"users": {"column": "id", "type": "varchar(36)"}}
        result = _match_fk_pattern("user_id", "orders", ["users", "orders"], pk_map, "int")
        assert result is None
