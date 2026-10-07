# ---- Task Tracker image ----
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# do not run as root inside the container
RUN useradd --create-home appuser
USER appuser

ARG BUILD_SHA=local
ENV BUILD_SHA=${BUILD_SHA} APP_ENV=production
EXPOSE 5000
HEALTHCHECK --interval=10s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health')"
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app.main:app"]
