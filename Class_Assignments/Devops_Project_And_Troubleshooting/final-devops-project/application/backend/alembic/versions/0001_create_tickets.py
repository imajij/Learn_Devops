"""create tickets table"""
import sqlalchemy as sa
from alembic import op

revision = "0001_create_tickets"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "tickets",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("category", sa.String(length=20), nullable=False, server_default="SOFTWARE"),
        sa.Column("priority", sa.String(length=20), nullable=False, server_default="MEDIUM"),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="OPEN"),
        sa.Column("requester", sa.String(length=120), nullable=False, server_default="Anonymous"),
        sa.Column("location", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_tickets_status", "tickets", ["status"])


def downgrade():
    op.drop_index("ix_tickets_status", table_name="tickets")
    op.drop_table("tickets")
