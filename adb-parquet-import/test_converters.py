# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "pyarrow>=14.0.0",
#     "pymysql>=1.1.0",
#     "tqdm>=4.60.0",
# ]
# ///
"""Unit tests for type converters, make_converter, DDL generation,
_build_row_tuples, and _split_by_size."""

import datetime
import json
import math
import tempfile
import unittest
from decimal import Decimal
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

from adb_parquet_import import (
    _conv_bool,
    _conv_int,
    _conv_float,
    _conv_decimal,
    _conv_string,
    _conv_binary,
    _conv_date,
    _conv_time,
    _conv_datetime,
    _conv_duration,
    _conv_json,
    _conv_null,
    make_converter,
    generate_ddl,
    _escape_identifier,
    _build_row_tuples,
    _split_by_size,
)


# =========================================================================
# 1. Individual converter function tests
# =========================================================================

class TestConvBool(unittest.TestCase):
    def test_true(self):
        self.assertEqual(_conv_bool(True), "1")

    def test_false(self):
        self.assertEqual(_conv_bool(False), "0")

    def test_truthy_int(self):
        self.assertEqual(_conv_bool(1), "1")

    def test_falsy_zero(self):
        self.assertEqual(_conv_bool(0), "0")


class TestConvInt(unittest.TestCase):
    def test_positive(self):
        self.assertEqual(_conv_int(42), "42")

    def test_negative(self):
        self.assertEqual(_conv_int(-128), "-128")

    def test_zero(self):
        self.assertEqual(_conv_int(0), "0")

    def test_large(self):
        self.assertEqual(_conv_int(18446744073709551615), "18446744073709551615")

    def test_int64_min(self):
        self.assertEqual(_conv_int(-9223372036854775808), "-9223372036854775808")


class TestConvFloat(unittest.TestCase):
    def test_normal(self):
        result = _conv_float(3.14)
        self.assertIn("3.14", result)

    def test_nan(self):
        self.assertEqual(_conv_float(float("nan")), "NULL")

    def test_inf(self):
        self.assertEqual(_conv_float(float("inf")), "NULL")

    def test_neg_inf(self):
        self.assertEqual(_conv_float(float("-inf")), "NULL")

    def test_zero(self):
        self.assertEqual(_conv_float(0.0), "0.0")

    def test_negative(self):
        result = _conv_float(-2.5)
        self.assertEqual(result, "-2.5")


class TestConvDecimal(unittest.TestCase):
    def test_positive(self):
        self.assertEqual(_conv_decimal(Decimal("12345.67")), "12345.67")

    def test_negative(self):
        self.assertEqual(_conv_decimal(Decimal("-99999.99")), "-99999.99")

    def test_zero(self):
        self.assertEqual(_conv_decimal(Decimal("0")), "0")

    def test_high_precision(self):
        d = Decimal("0.000000000000000001")
        # str(Decimal) may use scientific notation
        result = _conv_decimal(d)
        self.assertEqual(Decimal(result), d)


class TestConvString(unittest.TestCase):
    def test_simple(self):
        self.assertEqual(_conv_string("hello"), "'hello'")

    def test_single_quote(self):
        # pymysql escape_string escapes single quotes
        result = _conv_string("it's")
        self.assertIn("it", result)
        self.assertTrue(result.startswith("'"))
        self.assertTrue(result.endswith("'"))

    def test_backslash(self):
        result = _conv_string("path\\to\\file")
        self.assertTrue(result.startswith("'"))
        self.assertTrue(result.endswith("'"))

    def test_newline(self):
        result = _conv_string("line1\nline2")
        self.assertTrue(result.startswith("'"))
        self.assertTrue(result.endswith("'"))

    def test_empty(self):
        self.assertEqual(_conv_string(""), "''")

    def test_unicode(self):
        result = _conv_string("你好世界")
        self.assertEqual(result, "'你好世界'")

    def test_sql_injection(self):
        result = _conv_string("'; DROP TABLE users; --")
        # Must be properly escaped
        self.assertTrue(result.startswith("'"))
        self.assertTrue(result.endswith("'"))
        # The inner single quote must be escaped (pymysql uses \')
        inner = result[1:-1]
        # Unescaped standalone ' should not appear
        self.assertNotIn("' ", inner.replace("\\'", ""))


class TestConvBinary(unittest.TestCase):
    def test_bytes(self):
        self.assertEqual(_conv_binary(b"\x00\x01\x02"), "X'000102'")

    def test_bytearray(self):
        self.assertEqual(_conv_binary(bytearray(b"\xff\xfe")), "X'fffe'")

    def test_empty_bytes(self):
        self.assertEqual(_conv_binary(b""), "X''")

    def test_non_bytes(self):
        self.assertEqual(_conv_binary("not bytes"), "NULL")

    def test_none(self):
        self.assertEqual(_conv_binary(None), "NULL")


class TestConvDate(unittest.TestCase):
    def test_normal(self):
        d = datetime.date(2024, 1, 15)
        self.assertEqual(_conv_date(d), "'2024-01-15'")

    def test_epoch(self):
        d = datetime.date(1970, 1, 1)
        self.assertEqual(_conv_date(d), "'1970-01-01'")

    def test_non_date(self):
        self.assertEqual(_conv_date("2024-01-15"), "NULL")

    def test_datetime_is_also_date(self):
        # datetime is a subclass of date
        dt = datetime.datetime(2024, 6, 15, 10, 30, 0)
        result = _conv_date(dt)
        # Should work since datetime is subclass of date
        self.assertIn("2024-06-15", result)


class TestConvTime(unittest.TestCase):
    def test_normal(self):
        t = datetime.time(10, 30, 45)
        self.assertEqual(_conv_time(t), "'10:30:45'")

    def test_midnight(self):
        t = datetime.time(0, 0, 0)
        self.assertEqual(_conv_time(t), "'00:00:00'")

    def test_with_microseconds(self):
        t = datetime.time(10, 30, 45, 123456)
        self.assertEqual(_conv_time(t), "'10:30:45.123456'")

    def test_non_time(self):
        self.assertEqual(_conv_time("10:30:00"), "NULL")


class TestConvDatetime(unittest.TestCase):
    def test_normal(self):
        dt = datetime.datetime(2024, 6, 15, 10, 30, 0)
        self.assertEqual(_conv_datetime(dt), "'2024-06-15 10:30:00.000000'")

    def test_with_microseconds(self):
        dt = datetime.datetime(2024, 6, 15, 10, 30, 0, 123456)
        self.assertEqual(_conv_datetime(dt), "'2024-06-15 10:30:00.123456'")

    def test_epoch(self):
        dt = datetime.datetime(1970, 1, 1, 0, 0, 0)
        self.assertEqual(_conv_datetime(dt), "'1970-01-01 00:00:00.000000'")

    def test_non_datetime(self):
        self.assertEqual(_conv_datetime("2024-06-15"), "NULL")


class TestConvDuration(unittest.TestCase):
    def test_timedelta(self):
        td = datetime.timedelta(seconds=1)
        self.assertEqual(_conv_duration(td), "1000000")

    def test_timedelta_zero(self):
        td = datetime.timedelta(0)
        self.assertEqual(_conv_duration(td), "0")

    def test_timedelta_complex(self):
        td = datetime.timedelta(days=1, hours=2, minutes=3, seconds=4, microseconds=5)
        expected_us = (1 * 86400 + 2 * 3600 + 3 * 60 + 4) * 1_000_000 + 5
        self.assertEqual(_conv_duration(td), str(expected_us))

    def test_raw_int(self):
        # When not a timedelta, fallback to str()
        self.assertEqual(_conv_duration(1000000), "1000000")


class TestConvJson(unittest.TestCase):
    def test_list(self):
        result = _conv_json([1, 2, 3])
        self.assertTrue(result.startswith("'"))
        self.assertTrue(result.endswith("'"))
        # Inner content should be valid JSON
        inner = result[1:-1]
        parsed = json.loads(inner)
        self.assertEqual(parsed, [1, 2, 3])

    def test_dict(self):
        result = _conv_json({"x": 1, "y": "a"})
        # escape_string escapes quotes, so we unescape for validation
        inner = result[1:-1].replace("\\'", "'").replace('\\"', '"')
        parsed = json.loads(inner)
        self.assertEqual(parsed, {"x": 1, "y": "a"})

    def test_nested(self):
        data = {"a": [1, 2], "b": {"c": 3}}
        result = _conv_json(data)
        inner = result[1:-1].replace("\\'", "'").replace('\\"', '"')
        parsed = json.loads(inner)
        self.assertEqual(parsed, data)

    def test_unicode(self):
        result = _conv_json({"name": "你好"})
        inner = result[1:-1].replace("\\'", "'").replace('\\"', '"')
        parsed = json.loads(inner)
        self.assertEqual(parsed["name"], "你好")

    def test_empty_list(self):
        result = _conv_json([])
        inner = result[1:-1]
        self.assertEqual(json.loads(inner), [])


class TestConvNull(unittest.TestCase):
    def test_none(self):
        self.assertEqual(_conv_null(None), "NULL")

    def test_any_value(self):
        self.assertEqual(_conv_null(42), "NULL")
        self.assertEqual(_conv_null("hello"), "NULL")


# =========================================================================
# 2. make_converter: type mapping correctness
# =========================================================================

class TestMakeConverter(unittest.TestCase):
    """Test that make_converter returns the correct (DDL type, converter) pair."""

    # -- Boolean --
    def test_bool(self):
        ddl, conv = make_converter(pa.bool_())
        self.assertEqual(ddl, "BOOLEAN")
        self.assertEqual(conv(True), "1")
        self.assertEqual(conv(False), "0")

    # -- Signed integers --
    def test_int8(self):
        ddl, conv = make_converter(pa.int8())
        self.assertEqual(ddl, "TINYINT")
        self.assertEqual(conv(-128), "-128")

    def test_int16(self):
        ddl, conv = make_converter(pa.int16())
        self.assertEqual(ddl, "SMALLINT")

    def test_int32(self):
        ddl, conv = make_converter(pa.int32())
        self.assertEqual(ddl, "INT")

    def test_int64(self):
        ddl, conv = make_converter(pa.int64())
        self.assertEqual(ddl, "BIGINT")
        self.assertEqual(conv(9223372036854775807), "9223372036854775807")

    # -- Unsigned integers --
    def test_uint8(self):
        ddl, conv = make_converter(pa.uint8())
        self.assertEqual(ddl, "SMALLINT")
        self.assertEqual(conv(255), "255")

    def test_uint16(self):
        ddl, conv = make_converter(pa.uint16())
        self.assertEqual(ddl, "INT")

    def test_uint32(self):
        ddl, conv = make_converter(pa.uint32())
        self.assertEqual(ddl, "BIGINT")

    def test_uint64(self):
        ddl, conv = make_converter(pa.uint64())
        self.assertEqual(ddl, "DECIMAL(20,0)")
        self.assertEqual(conv(18446744073709551615), "18446744073709551615")

    # -- Float --
    def test_float16(self):
        ddl, conv = make_converter(pa.float16())
        self.assertEqual(ddl, "FLOAT")

    def test_float32(self):
        ddl, conv = make_converter(pa.float32())
        self.assertEqual(ddl, "FLOAT")
        self.assertEqual(conv(float("nan")), "NULL")

    def test_float64(self):
        ddl, conv = make_converter(pa.float64())
        self.assertEqual(ddl, "DOUBLE")
        self.assertEqual(conv(float("inf")), "NULL")

    # -- Decimal --
    def test_decimal128(self):
        ddl, conv = make_converter(pa.decimal128(10, 2))
        self.assertEqual(ddl, "DECIMAL(10,2)")
        self.assertEqual(conv(Decimal("123.45")), "123.45")

    def test_decimal128_high_precision(self):
        ddl, conv = make_converter(pa.decimal128(38, 18))
        self.assertEqual(ddl, "DECIMAL(38,18)")

    def test_decimal256(self):
        ddl, conv = make_converter(pa.decimal256(50, 10))
        # precision clamped to 38
        self.assertEqual(ddl, "DECIMAL(38,10)")

    # -- String --
    def test_string(self):
        ddl, conv = make_converter(pa.string())
        self.assertEqual(ddl, "VARCHAR")
        self.assertEqual(conv("hello"), "'hello'")

    def test_large_string(self):
        ddl, conv = make_converter(pa.large_string())
        self.assertEqual(ddl, "VARCHAR")

    # -- Binary --
    def test_binary(self):
        ddl, conv = make_converter(pa.binary())
        self.assertEqual(ddl, "BINARY")
        self.assertEqual(conv(b"\xab\xcd"), "X'abcd'")

    def test_large_binary(self):
        ddl, conv = make_converter(pa.large_binary())
        self.assertEqual(ddl, "BINARY")

    def test_fixed_size_binary(self):
        ddl, conv = make_converter(pa.binary(4))
        self.assertEqual(ddl, "BINARY")

    # -- Date --
    def test_date32(self):
        ddl, conv = make_converter(pa.date32())
        self.assertEqual(ddl, "DATE")
        self.assertEqual(conv(datetime.date(2024, 1, 15)), "'2024-01-15'")

    def test_date64(self):
        ddl, conv = make_converter(pa.date64())
        self.assertEqual(ddl, "DATE")

    # -- Time --
    def test_time32_ms(self):
        ddl, conv = make_converter(pa.time32("ms"))
        self.assertEqual(ddl, "TIME")

    def test_time64_us(self):
        ddl, conv = make_converter(pa.time64("us"))
        self.assertEqual(ddl, "TIME")
        self.assertEqual(conv(datetime.time(10, 30)), "'10:30:00'")

    # -- Timestamp --
    def test_timestamp_no_tz(self):
        ddl, conv = make_converter(pa.timestamp("us"))
        self.assertEqual(ddl, "DATETIME")
        dt = datetime.datetime(2024, 6, 15, 10, 30, 0)
        self.assertEqual(conv(dt), "'2024-06-15 10:30:00.000000'")

    def test_timestamp_with_tz(self):
        ddl, conv = make_converter(pa.timestamp("us", tz="UTC"))
        self.assertEqual(ddl, "TIMESTAMP")

    def test_timestamp_s(self):
        ddl, conv = make_converter(pa.timestamp("s"))
        self.assertEqual(ddl, "DATETIME")

    def test_timestamp_ns(self):
        ddl, conv = make_converter(pa.timestamp("ns"))
        self.assertEqual(ddl, "DATETIME")

    # -- Duration --
    def test_duration_us(self):
        ddl, conv = make_converter(pa.duration("us"))
        self.assertEqual(ddl, "BIGINT")
        td = datetime.timedelta(seconds=1)
        self.assertEqual(conv(td), "1000000")

    def test_duration_s(self):
        ddl, conv = make_converter(pa.duration("s"))
        self.assertEqual(ddl, "BIGINT")

    # -- Complex types → JSON --
    def test_list(self):
        ddl, conv = make_converter(pa.list_(pa.int32()))
        self.assertEqual(ddl, "JSON")

    def test_large_list(self):
        ddl, conv = make_converter(pa.large_list(pa.int32()))
        self.assertEqual(ddl, "JSON")

    def test_fixed_size_list(self):
        ddl, conv = make_converter(pa.list_(pa.int32(), 3))
        self.assertEqual(ddl, "JSON")

    def test_struct(self):
        ddl, conv = make_converter(pa.struct([("x", pa.int32()), ("y", pa.string())]))
        self.assertEqual(ddl, "JSON")

    def test_map(self):
        ddl, conv = make_converter(pa.map_(pa.string(), pa.int32()))
        self.assertEqual(ddl, "JSON")

    # -- Null type --
    def test_null(self):
        ddl, conv = make_converter(pa.null())
        self.assertEqual(ddl, "VARCHAR")
        self.assertEqual(conv(None), "NULL")
        self.assertEqual(conv(42), "NULL")


# =========================================================================
# 3. End-to-end: Parquet → to_pylist → converter round-trip
# =========================================================================

class TestParquetRoundTrip(unittest.TestCase):
    """Write data to a Parquet file, read it back via PyArrow, and verify
    that each converter produces the expected SQL fragment."""

    def _write_and_read(self, col_name, arrow_array):
        """Helper: write a single-column table to Parquet and read back."""
        table = pa.table({col_name: arrow_array})
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "test.parquet"
            pq.write_table(table, path)
            pf = pq.ParquetFile(path)
            batch = next(pf.iter_batches(batch_size=1024))
            return batch.column(col_name).to_pylist(), pf.schema_arrow.field(col_name).type

    def test_bool_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([True, False, None], type=pa.bool_()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "1")
        self.assertEqual(conv(data[1]), "0")
        self.assertIsNone(data[2])

    def test_int32_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([42, -1, None], type=pa.int32()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "42")
        self.assertEqual(conv(data[1]), "-1")
        self.assertIsNone(data[2])

    def test_int64_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([9223372036854775807, -9223372036854775808, None], type=pa.int64()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "9223372036854775807")
        self.assertEqual(conv(data[1]), "-9223372036854775808")

    def test_uint64_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([0, 18446744073709551615, None], type=pa.uint64()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "0")
        self.assertEqual(conv(data[1]), "18446744073709551615")

    def test_float64_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([3.14, float("nan"), None], type=pa.float64()))
        _, conv = make_converter(arrow_type)
        self.assertIn("3.14", conv(data[0]))
        # NaN from parquet comes back as float nan
        self.assertEqual(conv(data[1]), "NULL")
        self.assertIsNone(data[2])

    def test_float32_inf_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([float("inf"), float("-inf"), None], type=pa.float32()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "NULL")
        self.assertEqual(conv(data[1]), "NULL")

    def test_decimal128_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([Decimal("12345.67"), Decimal("-99.99"), None], type=pa.decimal128(10, 2)))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "DECIMAL(10,2)")
        self.assertEqual(conv(data[0]), "12345.67")
        self.assertEqual(conv(data[1]), "-99.99")

    def test_string_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array(["hello", "it's \"quoted\"", None], type=pa.string()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "'hello'")
        # Special chars must be escaped
        result = conv(data[1])
        self.assertTrue(result.startswith("'"))
        self.assertTrue(result.endswith("'"))

    def test_string_unicode_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array(["你好", "🎉emoji", None], type=pa.string()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "'你好'")
        self.assertIn("emoji", conv(data[1]))

    def test_binary_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([b"\x00\x01\xff", b"", None], type=pa.binary()))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "X'0001ff'")
        self.assertEqual(conv(data[1]), "X''")

    def test_fixed_binary_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([b"AB", b"CD", None], type=pa.binary(2)))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "BINARY")
        self.assertEqual(conv(data[0]), "X'4142'")

    def test_date32_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([datetime.date(2024, 1, 15), datetime.date(1970, 1, 1), None], type=pa.date32()))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "DATE")
        self.assertEqual(conv(data[0]), "'2024-01-15'")
        self.assertEqual(conv(data[1]), "'1970-01-01'")

    def test_time32_roundtrip(self):
        # time32("ms") stores milliseconds
        data, arrow_type = self._write_and_read(
            "c", pa.array([3600000, 0, None], type=pa.time32("ms")))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "TIME")
        # 3600000ms = 1 hour
        self.assertEqual(conv(data[0]), "'01:00:00'")
        self.assertEqual(conv(data[1]), "'00:00:00'")

    def test_time64_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([3600000000, 0, None], type=pa.time64("us")))
        _, conv = make_converter(arrow_type)
        self.assertEqual(conv(data[0]), "'01:00:00'")

    def test_timestamp_no_tz_roundtrip(self):
        dt1 = datetime.datetime(2024, 6, 15, 10, 30, 0)
        dt2 = datetime.datetime(2000, 1, 1, 0, 0, 0)
        data, arrow_type = self._write_and_read(
            "c", pa.array([dt1, dt2, None], type=pa.timestamp("us")))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "DATETIME")
        self.assertEqual(conv(data[0]), "'2024-06-15 10:30:00.000000'")
        self.assertEqual(conv(data[1]), "'2000-01-01 00:00:00.000000'")

    def test_timestamp_with_tz_roundtrip(self):
        dt1 = datetime.datetime(2024, 6, 15, 10, 30, 0)
        data, arrow_type = self._write_and_read(
            "c", pa.array([dt1, None], type=pa.timestamp("us", tz="UTC")))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "TIMESTAMP")
        result = conv(data[0])
        self.assertIn("2024-06-15", result)

    def test_duration_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([1000000, 0, None], type=pa.duration("us")))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "BIGINT")
        self.assertEqual(conv(data[0]), "1000000")
        self.assertEqual(conv(data[1]), "0")

    def test_list_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([[1, 2, 3], [4, 5], None], type=pa.list_(pa.int32())))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "JSON")
        result = conv(data[0])
        inner = result[1:-1]
        self.assertEqual(json.loads(inner), [1, 2, 3])

    def test_struct_roundtrip(self):
        st = pa.struct([("x", pa.int32()), ("y", pa.string())])
        data, arrow_type = self._write_and_read(
            "c", pa.array([{"x": 1, "y": "a"}, {"x": 2, "y": "b"}, None], type=st))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "JSON")
        result = conv(data[0])
        inner = result[1:-1].replace("\\'", "'").replace('\\"', '"')
        parsed = json.loads(inner)
        self.assertEqual(parsed["x"], 1)
        self.assertEqual(parsed["y"], "a")

    def test_map_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array(
                [[(1, "one"), (2, "two")], [(3, "three")], None],
                type=pa.map_(pa.int32(), pa.string()),
            ))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "JSON")
        result = conv(data[0])
        # Map is represented as list of (key, value) tuples in pyarrow
        inner = result[1:-1].replace("\\'", "'").replace('\\"', '"')
        parsed = json.loads(inner)
        self.assertIsInstance(parsed, list)

    def test_null_type_roundtrip(self):
        data, arrow_type = self._write_and_read(
            "c", pa.array([None, None, None], type=pa.null()))
        ddl, conv = make_converter(arrow_type)
        self.assertEqual(ddl, "VARCHAR")
        self.assertEqual(conv(data[0]), "NULL")


# =========================================================================
# 4. DDL generation
# =========================================================================

class TestGenerateDDL(unittest.TestCase):
    def test_basic(self):
        type_info = [("INT", _conv_int), ("VARCHAR", _conv_string)]
        ddl = generate_ddl("my_table", ["id", "name"], type_info)
        self.assertIn("CREATE TABLE IF NOT EXISTS `my_table`", ddl)
        self.assertIn("`id` INT", ddl)
        self.assertIn("`name` VARCHAR", ddl)
        self.assertIn("DISTRIBUTE BY HASH(`id`)", ddl)

    def test_special_chars_in_name(self):
        type_info = [("INT", _conv_int)]
        ddl = generate_ddl("table`name", ["col`1"], type_info)
        self.assertIn("`table``name`", ddl)
        self.assertIn("`col``1`", ddl)


class TestEscapeIdentifier(unittest.TestCase):
    def test_simple(self):
        self.assertEqual(_escape_identifier("col"), "`col`")

    def test_backtick(self):
        self.assertEqual(_escape_identifier("col`x"), "`col``x`")

    def test_empty(self):
        self.assertEqual(_escape_identifier(""), "``")


# =========================================================================
# 5. _build_row_tuples
# =========================================================================

class TestBuildRowTuples(unittest.TestCase):
    def test_basic(self):
        columns_data = [[1, 2], ["a", "b"]]
        type_info = [("INT", _conv_int), ("VARCHAR", _conv_string)]
        result = _build_row_tuples(columns_data, type_info, 2, 2)
        self.assertEqual(result, ["(1,'a')", "(2,'b')"])

    def test_with_nulls(self):
        columns_data = [[1, None], [None, "b"]]
        type_info = [("INT", _conv_int), ("VARCHAR", _conv_string)]
        result = _build_row_tuples(columns_data, type_info, 2, 2)
        self.assertEqual(result, ["(1,NULL)", "(NULL,'b')"])

    def test_empty(self):
        result = _build_row_tuples([], [], 0, 0)
        self.assertEqual(result, [])

    def test_single_row(self):
        columns_data = [[42]]
        type_info = [("INT", _conv_int)]
        result = _build_row_tuples(columns_data, type_info, 1, 1)
        self.assertEqual(result, ["(42)"])


# =========================================================================
# 6. _split_by_size
# =========================================================================

class TestSplitBySize(unittest.TestCase):
    def test_no_split_needed(self):
        rows = ["(1,'a')", "(2,'b')"]
        result = _split_by_size("INSERT INTO t VALUES", rows, 10000)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0], rows)

    def test_split_into_two(self):
        rows = ["(1,'a')", "(2,'b')", "(3,'c')"]
        # Use a small limit to force splitting
        result = _split_by_size("INSERT INTO t VALUES", rows, 40)
        self.assertGreater(len(result), 1)
        # All rows must be present
        all_rows = [r for batch in result for r in batch]
        self.assertEqual(all_rows, rows)

    def test_single_large_row(self):
        big_row = "(" + "x" * 1000 + ")"
        result = _split_by_size("INSERT INTO t VALUES", [big_row], 50)
        # Single large row placed alone
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0], [big_row])

    def test_empty_input(self):
        result = _split_by_size("INSERT INTO t VALUES", [], 10000)
        self.assertEqual(result, [])


# =========================================================================
# 7. Full pipeline: Parquet → _build_row_tuples (all types in one table)
# =========================================================================

class TestFullPipeline(unittest.TestCase):
    """Write a multi-column Parquet with all types, read back, and verify
    _build_row_tuples produces valid SQL value rows."""

    def test_all_types_pipeline(self):
        arrays = {
            "c_bool": pa.array([True, None], type=pa.bool_()),
            "c_int8": pa.array([1, None], type=pa.int8()),
            "c_int64": pa.array([9223372036854775807, None], type=pa.int64()),
            "c_uint64": pa.array([18446744073709551615, None], type=pa.uint64()),
            "c_float64": pa.array([3.14, None], type=pa.float64()),
            "c_decimal": pa.array([Decimal("123.45"), None], type=pa.decimal128(10, 2)),
            "c_string": pa.array(["hello", None], type=pa.string()),
            "c_binary": pa.array([b"\xab\xcd", None], type=pa.binary()),
            "c_date": pa.array([datetime.date(2024, 1, 15), None], type=pa.date32()),
            "c_time": pa.array([3600000000, None], type=pa.time64("us")),
            "c_ts": pa.array(
                [datetime.datetime(2024, 6, 15, 10, 30), None],
                type=pa.timestamp("us")),
            "c_duration": pa.array([1000000, None], type=pa.duration("us")),
            "c_list": pa.array([[1, 2], None], type=pa.list_(pa.int32())),
            "c_struct": pa.array(
                [{"x": 1}, None],
                type=pa.struct([("x", pa.int32())])),
            "c_null": pa.array([None, None], type=pa.null()),
        }
        table = pa.table(arrays)

        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "all_types.parquet"
            pq.write_table(table, path)
            pf = pq.ParquetFile(path)
            schema = pf.schema_arrow
            col_names = schema.names

            type_info = []
            for name in col_names:
                idx = schema.get_field_index(name)
                arrow_type = schema.field(idx).type
                type_info.append(make_converter(arrow_type))

            batch = next(pf.iter_batches(batch_size=1024))
            columns_data = [batch.column(c).to_pylist() for c in col_names]
            rows = _build_row_tuples(columns_data, type_info, 2, len(col_names))

            # Row 0: all non-null
            self.assertIn("1", rows[0])           # bool True -> 1
            self.assertIn("'hello'", rows[0])     # string
            self.assertIn("X'abcd'", rows[0])     # binary
            self.assertIn("'2024-01-15'", rows[0])  # date
            self.assertIn("'2024-06-15", rows[0])   # timestamp

            # Row 1: all NULL
            parts = rows[1].strip("()").split(",")
            self.assertTrue(all(p == "NULL" for p in parts),
                            f"Expected all NULLs but got: {rows[1]}")


if __name__ == "__main__":
    unittest.main()
