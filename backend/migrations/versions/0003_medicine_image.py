"""medicine image

Revision ID: 0003_medicine_image
Revises: 0002_refill_fields
Create Date: 2026-04-28 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0003_medicine_image"
down_revision = "0002_refill_fields"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("medicines", sa.Column("image_url", sa.String(length=500), nullable=True))


def downgrade():
    op.drop_column("medicines", "image_url")
