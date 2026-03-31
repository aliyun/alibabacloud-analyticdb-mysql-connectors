"""Tests for sensitive field masking."""

from analyticdb_mysql_cli.masking import mask_rows


class TestMaskRows:
    def test_phone_masking(self):
        rows = [{"phone": "13812345678"}]
        result = mask_rows(["phone"], rows)
        assert result[0]["phone"] == "138****5678"

    def test_email_masking(self):
        rows = [{"email": "zhang@gmail.com"}]
        result = mask_rows(["email"], rows)
        assert result[0]["email"] == "z***@gmail.com"

    def test_password_masking(self):
        rows = [{"password": "super_secret_123"}]
        result = mask_rows(["password"], rows)
        assert result[0]["password"] == "******"

    def test_tokenize_expression_column_not_masked(self):
        col = "TOKENIZE('x', 'space')"
        rows = [{col: '["a","b"]'}]
        result = mask_rows([col], rows)
        assert result[0][col] == '["a","b"]'

    def test_idcard_masking(self):
        rows = [{"id_card": "110101199001011234"}]
        result = mask_rows(["id_card"], rows)
        masked = result[0]["id_card"]
        assert masked.startswith("110")
        assert masked.endswith("1234")
        assert "*" in masked

    def test_no_masking_for_regular_columns(self):
        rows = [{"name": "Alice", "age": "30"}]
        result = mask_rows(["name", "age"], rows)
        assert result[0]["name"] == "Alice"
        assert result[0]["age"] == "30"

    def test_mixed_columns(self):
        rows = [{"name": "Bob", "mobile": "13912345678", "user_email": "b@x.com"}]
        result = mask_rows(["name", "mobile", "user_email"], rows)
        assert result[0]["name"] == "Bob"
        assert "****" in result[0]["mobile"]
        assert "***@" in result[0]["user_email"]

    def test_none_values_skipped(self):
        rows = [{"phone": None}]
        result = mask_rows(["phone"], rows)
        assert result[0]["phone"] is None

    def test_non_string_values_skipped(self):
        rows = [{"phone": 13812345678}]
        result = mask_rows(["phone"], rows)
        assert result[0]["phone"] == 13812345678
