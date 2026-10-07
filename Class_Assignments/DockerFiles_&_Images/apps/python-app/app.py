import platform
from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return (
        "<h1>Hello World from Docker multi-stage build</h1>"
        f"<p>Python {platform.python_version()} + Flask, served by gunicorn</p>"
    )
