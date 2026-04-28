"""add medicine refill fields

Revision ID: 0002_refill_fields
Revises: 0001_initial
Create Date: 2026-04-28
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0002_refill_fields"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade():
    existing = {column["name"] for column in inspect(op.get_bind()).get_columns("medicines")}
    if "stock_quantity" not in existing:
        op.add_column("medicines", sa.Column("stock_quantity", sa.Integer(), nullable=True))
    if "refill_threshold" not in existing:
        op.add_column("medicines", sa.Column("refill_threshold", sa.Integer(), nullable=True))
    if "refill_reminder_enabled" not in existing:
        op.add_column(
            "medicines",
            sa.Column(
                "refill_reminder_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
        )


def downgrade():
    op.drop_column("medicines", "refill_reminder_enabled")
    op.drop_column("medicines", "refill_threshold")
    op.drop_column("medicines", "stock_quantity")
