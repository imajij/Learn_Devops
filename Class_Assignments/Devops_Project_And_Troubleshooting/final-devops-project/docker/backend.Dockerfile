# CampusDesk API image.  Build from the project root:
#   docker build -f docker/backend.Dockerfile -t campusdesk-backend:dev .
FROM python:3.12.15-slim

ARG APP_VERSION=1.0.0
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    APP_VERSION=${APP_VERSION}

WORKDIR /app
COPY application/backend/requirements.txt .
RUN pip install -r requirements.txt \
 && useradd --create-home --uid 10001 --shell /usr/sbin/nologin campusdesk

COPY application/backend/alembic.ini ./
COPY application/backend/alembic ./alembic
COPY application/backend/app ./app

USER 10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
# Migrate the schema first, then serve. exec makes uvicorn PID 1 so it receives SIGTERM.
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --no-access-log"]
