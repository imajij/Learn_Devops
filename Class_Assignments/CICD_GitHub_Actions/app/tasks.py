"""Pure business logic (no Flask) so it is easy to unit test."""

VALID_PRIORITIES = ("low", "medium", "high")


class TaskStore:
    """A tiny in-memory task list."""

    def __init__(self):
        self._tasks = {}
        self._next_id = 1

    def add(self, title, priority="medium"):
        title = (title or "").strip()
        if not title:
            raise ValueError("title must not be empty")
        if priority not in VALID_PRIORITIES:
            raise ValueError(f"priority must be one of {VALID_PRIORITIES}")
        task = {"id": self._next_id, "title": title, "priority": priority, "done": False}
        self._tasks[task["id"]] = task
        self._next_id += 1
        return task

    def all(self):
        return list(self._tasks.values())

    def complete(self, task_id):
        if task_id not in self._tasks:
            raise KeyError(task_id)
        self._tasks[task_id]["done"] = True
        return self._tasks[task_id]

    def stats(self):
        tasks = self.all()
        done = sum(1 for t in tasks if t["done"])
        percent = round(done * 100 / len(tasks)) if tasks else 0
        return {"total": len(tasks), "done": done, "open": len(tasks) - done, "percent_done": percent}
