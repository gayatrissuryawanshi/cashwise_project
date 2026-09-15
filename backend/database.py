"""
database.py
Single database connection for the combined CashWise app.

Local development:
    Uses ./cashflow.db

Vercel:
    Uses /tmp/cashflow.db because the deployed filesystem is read-only.
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base


if os.getenv("VERCEL"):
    DATABASE_URL = "sqlite:////tmp/cashflow.db"
else:
    DATABASE_URL = os.environ.get(
        "DATABASE_URL",
        "sqlite:///./cashflow.db",
    )


connect_args = (
    {"check_same_thread": False}
    if DATABASE_URL.startswith("sqlite")
    else {}
)

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()