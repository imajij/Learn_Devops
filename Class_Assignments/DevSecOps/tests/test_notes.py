import pytest

from app.notes import NoteStore


def test_add_and_search_by_tag():
    store = NoteStore()
    store.add("k8s", "kind cluster", ["devops", "k8s"])
    store.add("trivy", "image scan", ["security"])
    assert [n["title"] for n in store.search("security")] == ["trivy"]
    assert len(store.search()) == 2


def test_tags_are_deduplicated_and_sorted():
    note = NoteStore().add("t", tags=["b", "a", "b"])
    assert note["tags"] == ["a", "b"]


@pytest.mark.parametrize("title", ["", "   ", "x" * 81])
def test_bad_titles_rejected(title):
    with pytest.raises(ValueError):
        NoteStore().add(title)


def test_bad_tag_rejected():
    with pytest.raises(ValueError):
        NoteStore().add("t", tags=["<script>"])
