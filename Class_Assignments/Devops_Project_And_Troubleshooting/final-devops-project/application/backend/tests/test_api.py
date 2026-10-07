def test_health_is_up(client):
    assert client.get("/health").json() == {"status": "UP"}


def test_ready_checks_database(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "READY"}


def test_root_and_info(client):
    assert client.get("/").json()["service"] == "CampusDesk API"
    info = client.get("/api/info").json()
    assert info["environment"] == "local"
    assert "pod" in info


def test_create_ticket(client, ticket):
    assert ticket["id"] > 0
    assert ticket["status"] == "OPEN"
    assert ticket["category"] == "HARDWARE"


def test_create_ticket_validation(client):
    too_short = client.post("/api/tickets", json={"title": "x"})
    bad_priority = client.post("/api/tickets", json={"title": "Wi-Fi down", "priority": "PANIC"})
    assert too_short.status_code == 422
    assert bad_priority.status_code == 422


def test_list_and_get_ticket(client, ticket):
    listed = client.get("/api/tickets").json()
    assert [t["id"] for t in listed] == [ticket["id"]]
    assert client.get(f"/api/tickets/{ticket['id']}").json()["title"] == "Projector not working"


def test_filter_by_status(client, ticket):
    assert client.get("/api/tickets", params={"status_filter": "OPEN"}).json()
    assert client.get("/api/tickets", params={"status_filter": "RESOLVED"}).json() == []


def test_update_ticket(client, ticket):
    response = client.put(f"/api/tickets/{ticket['id']}", json={"status": "RESOLVED"})
    assert response.status_code == 200
    assert response.json()["status"] == "RESOLVED"
    assert response.json()["title"] == ticket["title"]


def test_delete_ticket(client, ticket):
    assert client.delete(f"/api/tickets/{ticket['id']}").status_code == 204
    assert client.get(f"/api/tickets/{ticket['id']}").status_code == 404


def test_missing_ticket_returns_404(client):
    assert client.get("/api/tickets/9999").status_code == 404
    assert client.put("/api/tickets/9999", json={"status": "OPEN"}).status_code == 404
    assert client.delete("/api/tickets/9999").status_code == 404


def test_stats(client, ticket):
    client.post("/api/tickets", json={"title": "Lab PC will not boot", "priority": "URGENT"})
    client.put(f"/api/tickets/{ticket['id']}", json={"status": "IN_PROGRESS"})
    assert client.get("/api/tickets/stats").json() == {
        "total": 2, "open": 1, "inProgress": 1, "resolved": 0, "urgent": 1,
    }


def test_metrics_exposed(client, ticket):
    body = client.get("/metrics").text
    assert "http_requests_total" in body
    assert 'campusdesk_tickets_created_total{category="HARDWARE",priority="HIGH"}' in body
