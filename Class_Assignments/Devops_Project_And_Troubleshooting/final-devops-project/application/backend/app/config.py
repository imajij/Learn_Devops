"""Runtime settings.

Non-secret values (DB host, app environment, banner text) come from a Kubernetes
ConfigMap; the database password comes from a Secret. Locally / in tests you can
set DATABASE_URL directly and it wins over the individual DB_* parts.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "CampusDesk API"
    app_version: str = "1.0.0"
    app_env: str = "local"
    support_banner: str = "Campus IT helpdesk - raise a ticket and we will pick it up."

    database_url: str | None = None
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "campusdesk"
    db_user: str = "campusdesk"
    db_password: str = ""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def sqlalchemy_url(self) -> str:
        if self.database_url:
            return self.database_url
        return (
            f"postgresql+psycopg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()
