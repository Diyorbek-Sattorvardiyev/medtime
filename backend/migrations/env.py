from __future__ import annotations

from logging.config import fileConfig

from flask import current_app

from alembic import context

config = context.config
fileConfig(config.config_file_name)
target_db = current_app.extensions["migrate"].db
target_metadata = target_db.metadata


def get_engine():
    try:
        return target_db.engine
    except TypeError:
        return target_db.get_engine()


def run_migrations_offline():
    url = current_app.config.get("SQLALCHEMY_DATABASE_URI")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    with get_engine().connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
