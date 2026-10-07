"""Tests run against a throw-away SQLite file, never the real PostgreSQL database."""
import os
import tempfile

_DB_FILE = os.path.join(tempfile.mkdtemp(prefix="campusdesk-test-"), "test.db")
os.environ["DATABASE_URL"] = f"sqlite:///{_DB_FILE}"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture()
def ticket(client):
    response = client.post(
        "/api/tickets",
        json={"title": "Projector not working", "category": "HARDWARE",
              "priority": "HIGH", "requester": "Ajij", "location": "Room B-204"},
    )
    assert response.status_code == 201
    return response.json()
