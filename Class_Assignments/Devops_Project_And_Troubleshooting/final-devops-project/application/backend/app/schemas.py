from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Status = Literal["OPEN", "IN_PROGRESS", "RESOLVED"]
Priority = Literal["LOW", "MEDIUM", "HIGH", "URGENT"]
Category = Literal["HARDWARE", "SOFTWARE", "NETWORK", "ACCOUNT"]


class TicketCreate(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    description: str = ""
    category: Category = "SOFTWARE"
    priority: Priority = "MEDIUM"
    status: Status = "OPEN"
    requester: str = Field(default="Anonymous", min_length=1, max_length=120)
    location: str = Field(default="", max_length=120)


class TicketUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=200)
    description: str | None = None
    category: Category | None = None
    priority: Priority | None = None
    status: Status | None = None
    requester: str | None = Field(default=None, min_length=1, max_length=120)
    location: str | None = Field(default=None, max_length=120)


class TicketOut(TicketCreate):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class StatsOut(BaseModel):
    total: int
    open: int
    inProgress: int
    resolved: int
    urgent: int
