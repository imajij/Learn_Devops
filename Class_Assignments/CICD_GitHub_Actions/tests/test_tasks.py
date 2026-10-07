import pytest

from app.tasks import TaskStore


def test_add_task_gets_incrementing_ids():
    store = TaskStore()
    first = store.add("write Dockerfile")
    second = store.add("write workflow", "high")
    assert first["id"] == 1 and second["id"] == 2
    assert second["priority"] == "high"
    assert first["done"] is False


def test_empty_title_is_rejected():
    with pytest.raises(ValueError):
        TaskStore().add("   ")


def test_bad_priority_is_rejected():
    with pytest.raises(ValueError):
        TaskStore().add("deploy", priority="urgent")


def test_complete_and_stats():
    store = TaskStore()
    store.add("a")
    store.add("b")
    store.add("c")
    store.complete(2)
    assert store.stats() == {"total": 3, "done": 1, "open": 2, "percent_done": 33}


def test_stats_on_empty_store():
    assert TaskStore().stats()["percent_done"] == 0


def test_complete_unknown_task():
    with pytest.raises(KeyError):
        TaskStore().complete(99)
