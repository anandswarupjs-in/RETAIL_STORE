"""MySQL connection helpers for the Retail Store Management System."""
import os
from contextlib import contextmanager

import pymysql
from pymysql.cursors import DictCursor


def get_connection():
    """Return a new connection. Set DB_* environment variables before running."""
    return pymysql.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "retail_store"),
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
        connect_timeout=5,
    )


@contextmanager
def connection_scope():
    """Commit on success, roll back on failure, and always close."""
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
