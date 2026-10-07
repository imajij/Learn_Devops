FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
RUN adduser -D -u 10001 app
USER 10001
EXPOSE 8080
CMD ["python", "-u", "app.py"]
