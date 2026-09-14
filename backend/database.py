"""
database.py
Single database connection for the whole combined app (auth + decision
engine + ML results all live in the same DB now, instead of three
separate/missing databases).

Defaults to a local SQLite file (cashflow.db) so the project runs with
zero setup - no Postgres install required to try it out. To use
PostgreSQL instead (recommended for real deployment), set the
DATABASE_URL environment variable before starting the server, e.g.:

    # Windows PowerShell
    $env:DATABASE_URL = "postgresql://postgres:YOUR_PASSWORD@localhost:5432/finance_engine"

    # macOS/Linux
    export DATABASE_URL="postgresql://postgres:YOUR_PASSWORD@localhost:5432/finance_engine"

Nothing else in the codebase needs to change either way.
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./cashflow.db")

# SQLite needs this connect arg when used from a threaded server (FastAPI/uvicorn).
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
