"""Baseline: the PHASE 0 DDL from D2b §3.2, executed verbatim.

The SQL file next to this revision (../sql/0001_baseline.sql) is a byte-for-byte copy of
SAA_CORE_DATABASE_DESIGN_v0.2.3.md §3.2. It is NOT rewritten, reformatted, or "improved" —
PHASE 1 must reproduce exactly 31 tables / 368 columns / 40 FK / 5 CHECK.
"""

from __future__ import annotations

import pathlib

from alembic import op

revision = "0001_baseline_phase0_ddl"
down_revision = None
branch_labels = None
depends_on = None

SQL_FILE = pathlib.Path(__file__).resolve().parent.parent / "sql" / "0001_baseline.sql"


def split_statements(raw: str) -> list[str]:
    """The baseline has no stored procedures, so ';' at end-of-line is a safe delimiter."""
    statements: list[str] = []
    for chunk in raw.split(";\n"):
        stmt = chunk.strip()
        if stmt:
            statements.append(stmt)
    return statements


def upgrade() -> None:
    raw = SQL_FILE.read_text(encoding="utf-8")
    bind = op.get_bind()
    for statement in split_statements(raw):
        bind.exec_driver_sql(statement)


def downgrade() -> None:
    """Drop exactly the tables this baseline created; alembic_version is Alembic's, not ours."""
    bind = op.get_bind()
    bind.exec_driver_sql("SET FOREIGN_KEY_CHECKS=0")
    rows = bind.exec_driver_sql("SHOW TABLES").fetchall()
    for (table,) in rows:
        if table == "alembic_version":
            continue
        bind.exec_driver_sql(f"DROP TABLE IF EXISTS `{table}`")
    bind.exec_driver_sql("SET FOREIGN_KEY_CHECKS=1")
