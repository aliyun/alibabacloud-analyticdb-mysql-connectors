"""DSN parsing and connection management for adbmysql-cli.

Supports remote connection mode:
  - Remote: mysql://user:pass@host:port/db  → pymysql

Remote DSNs: if the username contains ``@`` (e.g. ``u@domain``), use
``mysql://u@domain:password@host:port/db``.  The parser takes the *rightmost*
``@`` whose suffix is ``host[:port]``, then splits the credential prefix on
the *first* ``:`` into user and password.  Usernames containing ``:`` must
still be percent-encoded.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from typing import Any
from urllib.parse import unquote

import pymysql
import pymysql.cursors
import pymysql.err


# ---------------------------------------------------------------------------
# DSN config
# ---------------------------------------------------------------------------

@dataclass
class DSNConfig:
    host: str = "127.0.0.1"
    port: int = 3306
    user: str = "root"
    password: str = ""
    database: str = "test"


# ---------------------------------------------------------------------------
# DSN parsing
# ---------------------------------------------------------------------------

# Tail after the last "@" that separates credentials from host must look like host[:port].
_ADBMYSQL_HOST_PORT_RE = re.compile(r"^(?P<host>[^@/:]+)(?::(?P<port>\d+))?$")


def _parse_adbmysql_remote_body(body: str) -> DSNConfig | None:
    """Parse ``[user[:password]@]host[:port][/database]`` (no scheme, no ``?``)."""
    database = ""
    if "/" in body:
        slash = body.index("/")
        database = unquote(body[slash + 1 :])
        body = body[:slash]

    cfg = DSNConfig()
    if database:
        cfg.database = database

    def apply_host_port(hostpart: str) -> bool:
        m = _ADBMYSQL_HOST_PORT_RE.match(hostpart)
        if not m:
            return False
        cfg.host = m.group("host")
        if m.group("port"):
            cfg.port = int(m.group("port"))
        return True

    if "@" not in body:
        if not apply_host_port(body):
            return None
        return cfg

    for at_idx in range(len(body) - 1, -1, -1):
        if body[at_idx] != "@":
            continue
        userinfo, hostpart = body[:at_idx], body[at_idx + 1 :]
        if not apply_host_port(hostpart):
            continue
        if ":" in userinfo:
            c = userinfo.index(":")
            cfg.user = unquote(userinfo[:c])
            cfg.password = unquote(userinfo[c + 1 :])
        else:
            cfg.user = unquote(userinfo)
        return cfg

    return None


def _parse_adbmysql_remote_dsn(dsn: str) -> DSNConfig | None:
    """Parse ``mysql://[user[:password]@]host[:port][/database][?query]``.

    The ``@`` before *host* may be ambiguous when the username contains ``@``
    (e.g. ``u@domain:secret@10.0.0.1:3306/db``).  We pick the **rightmost** ``@``
    whose suffix matches ``host:port``; credentials are the prefix, split on
    the **first** ``:`` into user and password (password may contain ``:`` and
    ``@``).  Usernames containing an unencoded ``:`` are not supported.
    """
    prefix = "mysql://"
    if not dsn.startswith(prefix):
        return None
    rest = dsn[len(prefix) :]
    query = ""
    if "?" in rest:
        main_part, query = rest.split("?", 1)
    else:
        main_part = rest

    cfg = _parse_adbmysql_remote_body(main_part)
    return cfg


def parse_dsn(dsn: str) -> DSNConfig:
    """Parse ``mysql://user:pass@host:port/db`` into a DSNConfig."""
    cfg = _parse_adbmysql_remote_dsn(dsn)
    if cfg is None:
        raise ValueError(
            f"Invalid DSN format: {dsn!r}. "
            "Expected: mysql://user:pass@host:port/db"
        )
    return cfg


def _read_dsn_from_env_file(filepath: str) -> str | None:
    """Extract ADBMYSQL_DSN value from a .env-style file."""
    try:
        with open(filepath) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("ADBMYSQL_DSN="):
                    val = line[len("ADBMYSQL_DSN="):]
                    return val.strip().strip("\"'")
    except OSError:
        pass
    return None


def _discover_dsn() -> str | None:
    """Auto-discover DSN from config files.

    Search order:
      1. .env            in cwd   (ADBMYSQL_DSN=... line)
      2. ~/.adbmysql/config.env   (ADBMYSQL_DSN=... line)
    """
    cwd = os.getcwd()

    env_file = os.path.join(cwd, ".env")
    dsn = _read_dsn_from_env_file(env_file)
    if dsn:
        return dsn

    config_file = os.path.expanduser("~/.adbmysql/config.env")
    dsn = _read_dsn_from_env_file(config_file)
    if dsn:
        return dsn

    return None


def resolve_raw_dsn(cli_dsn: str | None) -> str:
    """Return the raw DSN string.

    Resolution order:
      1. ``--dsn`` CLI argument
      2. ``ADBMYSQL_DSN`` environment variable
      3. Auto-discover from config files (see ``_discover_dsn``)
      4. Raise ValueError if no DSN is found
    """
    raw = (
        cli_dsn
        or os.environ.get("ADBMYSQL_DSN")
        or _discover_dsn()
    )
    if not raw:
        raise ValueError(
            "No DSN provided. Use --dsn, set ADBMYSQL_DSN environment variable, "
            "or add ADBMYSQL_DSN=mysql://user:pass@host:port/db to .env or "
            "~/.adbmysql/config.env"
        )
    return raw


# ---------------------------------------------------------------------------
# Remote pymysql connection
# ---------------------------------------------------------------------------

def connect(cfg: DSNConfig) -> pymysql.connections.Connection:
    """Open a pymysql connection from a DSNConfig."""
    return pymysql.connect(
        host=cfg.host,
        port=cfg.port,
        user=cfg.user,
        password=cfg.password,
        database=cfg.database,
        cursorclass=pymysql.cursors.DictCursor,
        charset="utf8mb4",
        connect_timeout=10,
        read_timeout=30,
    )


# ---------------------------------------------------------------------------
# Unified entry point
# ---------------------------------------------------------------------------

def get_connection(cli_dsn: str | None) -> Any:
    """Resolve DSN and return an open pymysql connection.

    Returns a ``pymysql.Connection`` with DictCursor support.
    DSN format: ``mysql://[user[:password]@]host[:port][/database]``
    """
    raw = resolve_raw_dsn(cli_dsn)
    cfg = parse_dsn(raw)
    return connect(cfg)
