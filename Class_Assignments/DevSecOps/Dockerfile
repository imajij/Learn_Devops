# Alpine base: far fewer OS packages than Debian slim, so far fewer CVEs to carry
FROM python:3.12-alpine
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
RUN adduser -D -u 10001 appuser
USER 10001
ARG BUILD_SHA=local
ENV BUILD_SHA=${BUILD_SHA} PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app.main:app"]
