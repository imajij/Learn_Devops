"""Note storage and validation (pure Python, easy to unit test)."""
import re

MAX_TITLE = 80
MAX_BODY = 2000
TAG_RE = re.compile(r"^[a-z0-9-]{1,20}$")


class NoteStore:
    def __init__(self):
        self._notes = []

    def add(self, title, body="", tags=None):
        title = (title or "").strip()
        tags = tags or []
        if not title or len(title) > MAX_TITLE:
            raise ValueError(f"title must be 1-{MAX_TITLE} characters")
        if len(body) > MAX_BODY:
            raise ValueError(f"body must be at most {MAX_BODY} characters")
        bad = [t for t in tags if not TAG_RE.match(t)]
        if bad:
            raise ValueError(f"invalid tags: {bad}")
        note = {"id": len(self._notes) + 1, "title": title, "body": body, "tags": sorted(set(tags))}
        self._notes.append(note)
        return note

    def search(self, tag=None):
        if tag is None:
            return list(self._notes)
        return [n for n in self._notes if tag in n["tags"]]
