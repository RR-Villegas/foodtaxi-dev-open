"""Database utilities centralized for migration.

This module provides:
- `init_db_pool(db_config, pool_name, pool_size)` to initialize the
  connection pool when called from the legacy `app.py`.
- `get_db_conn()` which returns a tuple `(conn, cursor)` using Flask's
  request-local `g` object (cursor created with `dictionary=True`).
- `DB` helper class with `query` and `query_one` helpers that use
  `get_db_conn()` so the rest of the codebase can keep calling
  `db.query(...)` without changes.
"""
from typing import Optional
import mysql.connector
from mysql.connector import pooling
from flask import g


class DB:
    def __init__(self, pool: Optional[pooling.MySQLConnectionPool] = None):
        self.pool = pool

    def query(self, sql, params=None):
        conn, cur = get_db_conn()
        cur.execute(sql, params or ())
        return cur.fetchall()

    def query_one(self, sql, params=None):
        conn, cur = get_db_conn()
        cur.execute(sql, params or ())
        return cur.fetchone()


_pool: Optional[pooling.MySQLConnectionPool] = None


def init_db_pool(db_config: dict, pool_name: str = "mypool", pool_size: int = 5):
    """Initialize the MySQL connection pool for the application.

    Call this once during application startup (the old `app.py` will
    call it with its `DB_CONFIG`). This avoids automatically creating
    a connection on import which may be undesirable in some test
    environments.
    """
    global _pool
    if _pool is not None:
        return _pool

    _pool = mysql.connector.pooling.MySQLConnectionPool(
        pool_name=pool_name,
        pool_size=pool_size,
        **db_config,
    )
    return _pool


def get_db_conn():
    """Return (conn, cursor) for the current request, creating them if needed.

    The cursor is created with `dictionary=True` to preserve the
    behaviour of the legacy code.
    """
    if not hasattr(g, 'db_conn') or g.db_conn is None:
        if _pool is None:
            raise RuntimeError('DB pool not initialized. Call init_db_pool first.')
        g.db_conn = _pool.get_connection()
        g.db_cursor = g.db_conn.cursor(dictionary=True)

    return g.db_conn, g.db_cursor


# Export a DB helper instance (keeps compatibility with existing code)
db = DB()
