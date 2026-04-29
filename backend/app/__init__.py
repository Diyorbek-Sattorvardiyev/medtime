from __future__ import annotations

from flask import Flask
from marshmallow import ValidationError
from sqlalchemy import text

from app.config import Config
from app.extensions import api, cors, db, jwt, limiter, mail, migrate, scheduler
from app.jobs.reminders import register_scheduler_jobs
from app.routes.admin import blp as admin_blp
from app.routes.auth import blp as auth_blp
from app.routes.calendar import blp as calendar_blp
from app.routes.dashboard import blp as dashboard_blp
from app.routes.family import blp as family_blp
from app.routes.history import blp as history_blp
from app.routes.medicines import blp as medicines_blp
from app.routes.notifications import blp as notifications_blp
from app.routes.profile import blp as profile_blp
from app.routes.statistics import blp as statistics_blp
from app.routes.telegram import blp as telegram_blp
from app.utils.responses import error, success


def create_app(config_object=Config):
    app = Flask(__name__)
    app.config.from_object(config_object)

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    api.init_app(app)
    mail.init_app(app)
    cors.init_app(app, resources={r"/api/*": {"origins": "*"}})
    limiter.init_app(app)

    register_blueprints()
    register_error_handlers(app)
    register_jwt_handlers()

    if app.config["AUTO_MIGRATE"]:
        with app.app_context():
            db.create_all()

    if app.config["SCHEDULER_ENABLED"] and not scheduler.running:
        register_scheduler_jobs(app)
        scheduler.start()

    @app.get("/health")
    def health():
        db.session.execute(text("SELECT 1"))
        return success({"status": "up"}, "Server ishlayapti")

    return app


def register_blueprints():
    api.register_blueprint(admin_blp, url_prefix="/api/admin")
    api.register_blueprint(auth_blp, url_prefix="/api/auth")
    api.register_blueprint(profile_blp, url_prefix="/api/profile")
    api.register_blueprint(family_blp, url_prefix="/api/family-members")
    api.register_blueprint(medicines_blp, url_prefix="/api/medicines")
    api.register_blueprint(dashboard_blp, url_prefix="/api/dashboard")
    api.register_blueprint(calendar_blp, url_prefix="/api/calendar")
    api.register_blueprint(history_blp, url_prefix="/api/history")
    api.register_blueprint(statistics_blp, url_prefix="/api/statistics")
    api.register_blueprint(notifications_blp, url_prefix="/api/notifications")
    api.register_blueprint(telegram_blp, url_prefix="/api/telegram")


def register_error_handlers(app):
    @app.errorhandler(ValidationError)
    def handle_validation(err):
        return error("Kiritilgan ma'lumotlar noto'g'ri", err.messages, 422)

    @app.errorhandler(404)
    def handle_not_found(_err):
        return error("Resurs topilmadi", status_code=404)

    @app.errorhandler(500)
    def handle_server_error(_err):
        return error("Serverda ichki xatolik", status_code=500)


def register_jwt_handlers():
    @jwt.expired_token_loader
    def expired_token_callback(_jwt_header, _jwt_payload):
        return error("Token muddati tugagan", status_code=401)

    @jwt.invalid_token_loader
    def invalid_token_callback(reason):
        return error("Token noto'g'ri", {"reason": reason}, 401)

    @jwt.unauthorized_loader
    def missing_token_callback(reason):
        return error("Token yuborilmagan", {"reason": reason}, 401)
