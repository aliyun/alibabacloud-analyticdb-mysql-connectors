# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "pyarrow>=14.0.0",
# ]
# ///
"""Generate a test Parquet file covering all type mappings, then run dry-run."""

import datetime
import decimal
import subprocess
import sys
import tempfile
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

def main():
    # Build a table with every supported Arrow type
    arrays = {}

    # Boolean
    arrays["col_bool"] = pa.array([True, False, None], type=pa.bool_())

    # Signed integers
    arrays["col_int8"] = pa.array([1, -128, None], type=pa.int8())
    arrays["col_int16"] = pa.array([1000, -32768, None], type=pa.int16())
    arrays["col_int32"] = pa.array([100000, -2147483648, None], type=pa.int32())
    arrays["col_int64"] = pa.array([9000000000, -9223372036854775808, None], type=pa.int64())

    # Unsigned integers
    arrays["col_uint8"] = pa.array([0, 255, None], type=pa.uint8())
    arrays["col_uint16"] = pa.array([0, 65535, None], type=pa.uint16())
    arrays["col_uint32"] = pa.array([0, 4294967295, None], type=pa.uint32())
    arrays["col_uint64"] = pa.array([0, 18446744073709551615, None], type=pa.uint64())

    # Float
    arrays["col_float16"] = pa.array([1.5, float("nan"), None], type=pa.float16())
    arrays["col_float32"] = pa.array([3.14, float("inf"), None], type=pa.float32())
    arrays["col_float64"] = pa.array([2.718281828, float("-inf"), None], type=pa.float64())

    # Decimal
    arrays["col_decimal128"] = pa.array(
        [decimal.Decimal("12345.67"), decimal.Decimal("-99999.99"), None],
        type=pa.decimal128(10, 2),
    )

    # String
    arrays["col_string"] = pa.array(["hello", "it's a \"test\"", None], type=pa.string())
    arrays["col_large_string"] = pa.array(["large_val", "with\nnewline", None], type=pa.large_string())

    # Binary
    arrays["col_binary"] = pa.array([b"\x00\x01\x02", b"\xff\xfe", None], type=pa.binary())
    arrays["col_large_binary"] = pa.array([b"abc", b"\x00", None], type=pa.large_binary())
    arrays["col_fixed_binary"] = pa.array([b"AB", b"CD", None], type=pa.binary(2))

    # Date
    arrays["col_date32"] = pa.array(
        [datetime.date(2024, 1, 15), datetime.date(1970, 1, 1), None], type=pa.date32()
    )

    # Time
    arrays["col_time32"] = pa.array([3600000, 0, None], type=pa.time32("ms"))
    arrays["col_time64"] = pa.array([3600000000, 0, None], type=pa.time64("us"))

    # Timestamp (without tz)
    arrays["col_ts_no_tz"] = pa.array(
        [datetime.datetime(2024, 6, 15, 10, 30, 0), datetime.datetime(2000, 1, 1, 0, 0, 0), None],
        type=pa.timestamp("us"),
    )
    # Timestamp (with tz)
    arrays["col_ts_with_tz"] = pa.array(
        [datetime.datetime(2024, 6, 15, 10, 30, 0), datetime.datetime(2000, 1, 1, 0, 0, 0), None],
        type=pa.timestamp("us", tz="UTC"),
    )

    # Duration
    arrays["col_duration"] = pa.array([1000000, 0, None], type=pa.duration("us"))

    # List (complex → JSON)
    arrays["col_list"] = pa.array([[1, 2, 3], [4, 5], None], type=pa.list_(pa.int32()))

    # Struct (complex → JSON)
    arrays["col_struct"] = pa.array(
        [{"x": 1, "y": "a"}, {"x": 2, "y": "b"}, None],
        type=pa.struct([("x", pa.int32()), ("y", pa.string())]),
    )

    # Map (complex → JSON)
    arrays["col_map"] = pa.array(
        [[(1, "one"), (2, "two")], [(3, "three")], None],
        type=pa.map_(pa.int32(), pa.string()),
    )

    # Null type
    arrays["col_null"] = pa.array([None, None, None], type=pa.null())

    # Build table and write Parquet
    table = pa.table(arrays)

    with tempfile.TemporaryDirectory() as tmpdir:
        parquet_path = Path(tmpdir) / "test_all_types.parquet"
        pq.write_table(table, parquet_path)
        print(f"Test Parquet written to: {parquet_path}")
        print(f"Schema:\n{table.schema}\n")
        print(f"Rows: {table.num_rows}\n")

        # Run dry-run via `uv run`
        script = Path(__file__).resolve().parent / "adb_parquet_import.py"
        cmd = [
            "uv", "run", str(script),
            "--file", str(parquet_path),
            "--host", "127.0.0.1",
            "--user", "test",
            "--password", "test",
            "--database", "testdb",
            "--table", "test_all_types",
            "--batch-size", "2",
            "--create-table",
            "--dry-run",
            "--log-level", "DEBUG",
        ]
        print("Running dry-run command:")
        print(" ".join(cmd))
        print()
        result = subprocess.run(cmd, capture_output=False, text=True)
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
