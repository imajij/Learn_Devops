import platform
from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return f"""<!DOCTYPE html>
<html><head><title>Python app</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:15%">
  <h1>Hello World</h1>
  <p>from a Python {platform.python_version()} / Flask container</p>
</body></html>"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
