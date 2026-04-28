"""initial medreminder schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-04-27
"""
from alembic import op
import sqlalchemy as sa

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=True),
        sa.Column("google_id", sa.String(length=255), nullable=True),
        sa.Column("is_email_verified", sa.Boolean(), nullable=False),
        sa.Column("email_verified_at", sa.DateTime(), nullable=True),
        sa.Column("avatar_url", sa.String(length=500), nullable=True),
        sa.Column("language", sa.String(length=2), nullable=False),
        sa.Column("dark_mode", sa.Boolean(), nullable=False),
        sa.Column("app_notifications_enabled", sa.Boolean(), nullable=False),
        sa.Column("email_notifications_enabled", sa.Boolean(), nullable=False),
        sa.Column("telegram_notifications_enabled", sa.Boolean(), nullable=False),
        sa.Column("telegram_chat_id", sa.String(length=80), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("google_id", name="uq_users_google_id"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table("email_verification_codes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(length=10), nullable=False),
        sa.Column("purpose", sa.String(length=32), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("is_used", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_email_verification_codes_user_id", "email_verification_codes", ["user_id"])

    op.create_table("refresh_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(length=128), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"], unique=True)
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])

    op.create_table("family_members",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("relationship", sa.String(length=80), nullable=False),
        sa.Column("birth_date", sa.Date(), nullable=True),
        sa.Column("avatar_url", sa.String(length=500), nullable=True),
        sa.Column("avatar_color", sa.String(length=32), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_family_members_user_id", "family_members", ["user_id"])

    op.create_table("medicines",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("family_member_id", sa.Integer(), sa.ForeignKey("family_members.id", ondelete="SET NULL"), nullable=True),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("dosage", sa.String(length=120), nullable=False),
        sa.Column("intake_type", sa.String(length=32), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("stock_quantity", sa.Integer(), nullable=True),
        sa.Column("refill_threshold", sa.Integer(), nullable=True),
        sa.Column("refill_reminder_enabled", sa.Boolean(), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_medicines_active", "medicines", ["active"])
    op.create_index("ix_medicines_family_member_id", "medicines", ["family_member_id"])
    op.create_index("ix_medicines_user_id", "medicines", ["user_id"])

    op.create_table("medicine_schedules",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("medicine_id", sa.Integer(), sa.ForeignKey("medicines.id", ondelete="CASCADE"), nullable=False),
        sa.Column("time", sa.Time(), nullable=False),
        sa.Column("repeat_days", sa.JSON(), nullable=False),
        sa.Column("reminder_before_minutes", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_medicine_schedules_medicine_id", "medicine_schedules", ["medicine_id"])

    op.create_table("medicine_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("medicine_id", sa.Integer(), sa.ForeignKey("medicines.id", ondelete="CASCADE"), nullable=False),
        sa.Column("schedule_id", sa.Integer(), sa.ForeignKey("medicine_schedules.id", ondelete="CASCADE"), nullable=False),
        sa.Column("planned_at", sa.DateTime(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("taken_at", sa.DateTime(), nullable=True),
        sa.Column("snoozed_until", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("schedule_id", "planned_at", name="uq_schedule_planned_at"),
    )
    op.create_index("ix_medicine_logs_medicine_id", "medicine_logs", ["medicine_id"])
    op.create_index("ix_medicine_logs_planned_at", "medicine_logs", ["planned_at"])
    op.create_index("ix_medicine_logs_schedule_id", "medicine_logs", ["schedule_id"])
    op.create_index("ix_medicine_logs_status", "medicine_logs", ["status"])
    op.create_index("ix_medicine_logs_user_id", "medicine_logs", ["user_id"])

    op.create_table("notification_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("medicine_id", sa.Integer(), sa.ForeignKey("medicines.id", ondelete="SET NULL"), nullable=True),
        sa.Column("schedule_id", sa.Integer(), sa.ForeignKey("medicine_schedules.id", ondelete="SET NULL"), nullable=True),
        sa.Column("channel", sa.String(length=20), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("sent_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_notification_logs_medicine_id", "notification_logs", ["medicine_id"])
    op.create_index("ix_notification_logs_schedule_id", "notification_logs", ["schedule_id"])
    op.create_index("ix_notification_logs_user_id", "notification_logs", ["user_id"])

    op.create_table("telegram_connect_codes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("is_used", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_telegram_connect_codes_code", "telegram_connect_codes", ["code"], unique=True)
    op.create_index("ix_telegram_connect_codes_user_id", "telegram_connect_codes", ["user_id"])


def downgrade():
    op.drop_table("telegram_connect_codes")
    op.drop_table("notification_logs")
    op.drop_table("medicine_logs")
    op.drop_table("medicine_schedules")
    op.drop_table("medicines")
    op.drop_table("family_members")
    op.drop_table("refresh_tokens")
    op.drop_table("email_verification_codes")
    op.drop_table("users")
