"""CampusDesk API - a small IT helpdesk ticket service (FastAPI + PostgreSQL)."""
import logging
import socket
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from .config import settings
from .db import Base, SessionLocal, engine, get_db
from .models import Ticket
from .schemas import StatsOut, TicketCreate, TicketOut, TicketUpdate

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("campusdesk")

TICKETS_CREATED = Counter(
    "campusdesk_tickets_created_total", "Tickets created", ["category", "priority"]
)
TICKETS_RESOLVED = Counter("campusdesk_tickets_resolved_total", "Tickets moved to RESOLVED")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # In containers Alembic runs before Uvicorn; create_all keeps tests/dev self-contained.
    Base.metadata.create_all(bind=engine)
    log.info("CampusDesk %s starting (env=%s, db_host=%s)",
             settings.app_version, settings.app_env, settings.db_host)
    yield


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)
Instrumentator(excluded_handlers=["/metrics"]).instrument(app).expose(app, endpoint="/metrics")


def _get_or_404(db: Session, ticket_id: int) -> Ticket:
    ticket = db.get(Ticket, ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return ticket


@app.get("/")
def root():
    return {"service": settings.app_name, "version": settings.app_version, "docs": "/docs"}


@app.get("/health")
def health():
    """Liveness: the process is up. Never touches the database."""
    return {"status": "UP"}


@app.get("/ready")
def ready():
    """Readiness: only report READY when the database answers."""
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001 - any DB error means "not ready"
        log.warning("readiness check failed: %s", exc.__class__.__name__)
        return JSONResponse(status_code=503, content={"status": "NOT_READY"})
    return {"status": "READY"}


@app.get("/api/info")
def info():
    return {
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.app_env,
        "banner": settings.support_banner,
        "pod": socket.gethostname(),
    }


@app.get("/api/tickets", response_model=list[TicketOut])
def list_tickets(status_filter: str | None = None, db: Session = Depends(get_db)):
    query = select(Ticket).order_by(Ticket.id.desc())
    if status_filter:
        query = query.where(Ticket.status == status_filter)
    return list(db.scalars(query))


@app.get("/api/tickets/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)):
    rows = db.execute(select(Ticket.status, func.count(Ticket.id)).group_by(Ticket.status)).all()
    counts = {row_status: count for row_status, count in rows}
    urgent = db.scalar(
        select(func.count(Ticket.id)).where(Ticket.priority == "URGENT", Ticket.status != "RESOLVED")
    )
    return StatsOut(
        total=sum(counts.values()),
        open=counts.get("OPEN", 0),
        inProgress=counts.get("IN_PROGRESS", 0),
        resolved=counts.get("RESOLVED", 0),
        urgent=urgent or 0,
    )


@app.get("/api/tickets/{ticket_id}", response_model=TicketOut)
def get_ticket(ticket_id: int, db: Session = Depends(get_db)):
    return _get_or_404(db, ticket_id)


@app.post("/api/tickets", response_model=TicketOut, status_code=status.HTTP_201_CREATED)
def create_ticket(payload: TicketCreate, db: Session = Depends(get_db)):
    ticket = Ticket(**payload.model_dump())
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    TICKETS_CREATED.labels(ticket.category, ticket.priority).inc()
    log.info("ticket created id=%s category=%s priority=%s", ticket.id, ticket.category, ticket.priority)
    return ticket


@app.put("/api/tickets/{ticket_id}", response_model=TicketOut)
def update_ticket(ticket_id: int, payload: TicketUpdate, db: Session = Depends(get_db)):
    ticket = _get_or_404(db, ticket_id)
    changes = payload.model_dump(exclude_unset=True)
    if changes.get("status") == "RESOLVED" and ticket.status != "RESOLVED":
        TICKETS_RESOLVED.inc()
    for key, value in changes.items():
        setattr(ticket, key, value)
    db.commit()
    db.refresh(ticket)
    log.info("ticket updated id=%s fields=%s", ticket.id, sorted(changes))
    return ticket


@app.delete("/api/tickets/{ticket_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_ticket(ticket_id: int, db: Session = Depends(get_db)):
    ticket = _get_or_404(db, ticket_id)
    db.delete(ticket)
    db.commit()
    log.info("ticket deleted id=%s", ticket_id)
