# MedReminder Backend

Flask + SQLAlchemy asosidagi dori eslatma API. Default baza SQLite (`medtime.sqlite3`), lekin `DATABASE_URL` orqali PostgreSQL ham ishlatish mumkin.

## Texnologiyalar

- Flask app factory: `create_app`
- SQLite/PostgreSQL + SQLAlchemy
- Flask-Migrate / Alembic
- Flask-JWT-Extended access va refresh tokenlar
- Flask-Smorest Swagger UI: `/docs`
- Marshmallow validation
- Flask-Mail email verification va reminder email
- APScheduler har 1 daqiqalik reminder job
- Flask-CORS, Flask-Limiter
- Gunicorn production start

## O'rnatish

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

`.env` ichida kamida quyidagilarni sozlang:

```env
SECRET_KEY=change-me
JWT_SECRET_KEY=change-me-too
DATABASE_URL=sqlite:///medtime.sqlite3
RETURN_VERIFICATION_CODE=true
SCHEDULER_ENABLED=true
```

SMTP sozlanmasa backend crash qilmaydi. Email yuborish urinishlari failed holatida loglanadi.

## Migratsiya

```bash
flask --app run.py db upgrade
```

Yangi model o'zgarishidan keyin:

```bash
flask --app run.py db migrate -m "change message"
flask --app run.py db upgrade
```

Tez development uchun `.env`da `AUTO_MIGRATE=true` qo'yish mumkin, lekin productionda migratsiya komandasi ishlatilgani ma'qul.

## Ishga tushirish

```bash
flask --app run.py run --host 0.0.0.0 --port 5000
```

Health check:

```bash
curl http://localhost:5000/health
```

Swagger:

```text
http://localhost:5000/docs
```

## Production

```bash
gunicorn run:app
```

Procfile:

```text
web: gunicorn run:app
```

## API response formati

Success:

```json
{ "success": true, "message": "...", "data": {} }
```

Error:

```json
{ "success": false, "message": "...", "errors": {} }
```

## Asosiy endpointlar

- `POST /api/auth/register`
- `POST /api/auth/verify-email`
- `POST /api/auth/resend-code`
- `POST /api/auth/login`
- `POST /api/auth/google`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/auth/forgot-password`
- `POST /api/auth/reset-password`
- `GET|PUT /api/profile`
- `PUT /api/profile/notification-settings`
- `PUT /api/profile/email`
- `POST|GET /api/family-members`
- `GET|PUT|DELETE /api/family-members/<id>`
- `POST|GET /api/medicines`
- `GET|PUT|DELETE /api/medicines/<id>`
- Dorilar `stock_quantity`, `refill_threshold`, `refill_reminder_enabled` maydonlari orqali refill eslatmani qo'llaydi.
- `POST /api/medicines/<id>/mark-taken`
- `POST /api/medicines/<id>/mark-missed`
- `POST /api/medicines/<id>/snooze`
- `POST /api/medicines/actions/bulk`
- `GET /api/dashboard/today`
- `GET /api/calendar?month=YYYY-MM`
- `GET /api/calendar/day?date=YYYY-MM-DD`
- `GET /api/history`
- `GET /api/statistics?period=7|30|90`
- `GET /api/notifications`
- `GET /api/telegram/connect-link`
- `POST /api/telegram/webhook`
- `DELETE /api/telegram/disconnect`

## Flutter bilan ishlatish

Flutter client `AuthApi.defaultBaseUrl` orqali backendga ulanadi. Android emulator uchun odatda:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Telefon real qurilmada bo'lsa backend kompyuter IP manzilini ishlating:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:5000
```
