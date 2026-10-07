"""Flask HTTP layer for the Task Tracker."""
import os

from flask import Flask, jsonify, request

from app import __version__
from app.tasks import TaskStore


def create_app():
    app = Flask(__name__)
    store = TaskStore()

    @app.get("/")
    def index():
        return jsonify(
            service="task-tracker",
            version=__version__,
            environment=os.getenv("APP_ENV", "dev"),
            build=os.getenv("BUILD_SHA", "local"),
        )

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/api/tasks")
    def list_tasks():
        return jsonify(store.all())

    @app.post("/api/tasks")
    def add_task():
        body = request.get_json(silent=True) or {}
        try:
            task = store.add(body.get("title"), body.get("priority", "medium"))
        except ValueError as err:
            return jsonify(error=str(err)), 400
        return jsonify(task), 201

    @app.post("/api/tasks/<int:task_id>/done")
    def complete_task(task_id):
        try:
            return jsonify(store.complete(task_id))
        except KeyError:
            return jsonify(error="task not found"), 404

    @app.get("/api/stats")
    def stats():
        return jsonify(store.stats())

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
