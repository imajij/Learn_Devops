import pytest

from app.main import create_app

TOKEN = "unit-test-token"


@pytest.fixture
def client():
    return create_app(api_token=TOKEN).test_client()


def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}


def test_write_requires_token(client):
    assert client.post("/api/notes", json={"title": "x"}).status_code == 401
    bad = client.post("/api/notes", json={"title": "x"}, headers={"X-API-Token": "wrong"})
    assert bad.status_code == 401


def test_create_and_list(client):
    resp = client.post("/api/notes", json={"title": "gate", "tags": ["security"]},
                       headers={"X-API-Token": TOKEN})
    assert resp.status_code == 201
    assert client.get("/api/notes?tag=security").get_json()[0]["title"] == "gate"


def test_validation_error(client):
    resp = client.post("/api/notes", json={"title": ""}, headers={"X-API-Token": TOKEN})
    assert resp.status_code == 400


def test_no_token_configured_means_no_writes():
    client = create_app(api_token="").test_client()
    assert client.post("/api/notes", json={"title": "x"}, headers={"X-API-Token": ""}).status_code == 401


def test_resolve_rejects_shell_injection(client):
    assert client.get("/api/admin/resolve?host=example.com;cat /etc/passwd").status_code == 400


def test_resolve_localhost(client):
    body = client.get("/api/admin/resolve?host=localhost").get_json()
    assert body["ok"] is True and body["addresses"]
