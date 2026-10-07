"""HTTP layer of the Secure Notes API."""
import hmac
import os
import re
import socket

from flask import Flask, jsonify, request

from app import __version__
from app.notes import NoteStore

HOSTNAME_RE = re.compile(r"^(?=.{1,253}$)[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$")


def create_app(api_token=None):
    app = Flask(__name__)
    store = NoteStore()
    token = api_token if api_token is not None else os.getenv("API_TOKEN", "")

    def authorized():
        sent = request.headers.get("X-API-Token", "")
        return bool(token) and hmac.compare_digest(sent, token)

    @app.get("/")
    def index():
        return jsonify(service="secure-notes", version=__version__,
                       build=os.getenv("BUILD_SHA", "local"), pod=os.getenv("HOSTNAME", "?"))

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/api/notes")
    def list_notes():
        return jsonify(store.search(request.args.get("tag")))

    @app.post("/api/notes")
    def add_note():
        if not authorized():
            return jsonify(error="missing or wrong X-API-Token"), 401
        data = request.get_json(silent=True) or {}
        try:
            note = store.add(data.get("title"), data.get("body", ""), data.get("tags"))
        except ValueError as err:
            return jsonify(error=str(err)), 400
        return jsonify(note), 201

    @app.get("/api/admin/resolve")
    def resolve():
        # network check for operators: /api/admin/resolve?host=example.com
        # no shell, no subprocess: validate the name, then ask the resolver directly
        host = request.args.get("host", "localhost")
        if not HOSTNAME_RE.match(host):
            return jsonify(error="invalid host name"), 400
        try:
            addrs = sorted({info[4][0] for info in socket.getaddrinfo(host, None)})
        except socket.gaierror:
            return jsonify(host=host, ok=False, addresses=[])
        return jsonify(host=host, ok=True, addresses=addrs)

    return app


app = create_app()

if __name__ == "__main__":
    # local development only; the container runs gunicorn (see Dockerfile)
    app.run(host="127.0.0.1", port=8080)
