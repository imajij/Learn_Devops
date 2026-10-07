import pytest

from app.main import create_app


@pytest.fixture
def client():
    return create_app().test_client()


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_index_reports_version(client):
    body = client.get("/").get_json()
    assert body["service"] == "task-tracker"
    assert body["version"] == "1.0.0"


def test_create_list_and_complete(client):
    resp = client.post("/api/tasks", json={"title": "learn GitHub Actions", "priority": "high"})
    assert resp.status_code == 201
    task_id = resp.get_json()["id"]
    assert len(client.get("/api/tasks").get_json()) == 1
    assert client.post(f"/api/tasks/{task_id}/done").get_json()["done"] is True
    assert client.get("/api/stats").get_json()["percent_done"] == 100


def test_validation_error_returns_400(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 400


def test_unknown_task_returns_404(client):
    assert client.post("/api/tasks/42/done").status_code == 404
