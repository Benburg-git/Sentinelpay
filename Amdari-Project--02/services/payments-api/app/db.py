
"""Database connection helpers for SentinelPay payments API."""

import os

import psycopg2
import psycopg2.extras


def get_connection():
    """Create a PostgreSQL connection using runtime configuration."""
    database_url = os.environ.get("DATABASE_URL")

    if not database_url:
        raise RuntimeError(
            "DATABASE_URL is not configured. "
            "Provide the PostgreSQL connection URL securely at runtime."
        )

    return psycopg2.connect(
        database_url,
        cursor_factory=psycopg2.extras.RealDictCursor,
    )
