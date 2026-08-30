import os
from pathlib import Path
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from sqlalchemy.orm import DeclarativeBase, sessionmaker


load_dotenv()


def require_env(name: str) -> str:
    value = os.getenv(name)

    if not value:
        raise RuntimeError(f"Required environment variable {name} is not set")

    return value

def read_secret_or_env(name: str) -> str:
    direct_value = os.getenv(name)
    file_variable = f"{name}_FILE"
    secret_file = os.getenv(file_variable)

    if direct_value and secret_file:
        raise RuntimeError(
            f"Set either {name} or {file_variable}, not both"
        )

    if secret_file:
        path = Path(secret_file)

        try:
            value = path.read_text(
                encoding="utf-8"
            ).rstrip("\r\n")

        except OSError as exc:
            raise RuntimeError(
                f"Unable to read secret file for {name}: {path}"
            ) from exc

    elif direct_value:
        value = direct_value

    else:
        raise RuntimeError(
            f"Set either {name} or {file_variable}"
        )

    if not value:
        raise RuntimeError(
            f"Secret value for {name} is empty"
        )

    return value

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = require_env("DB_NAME")
DB_USER = require_env("DB_USER")
DB_PASSWORD = read_secret_or_env("DB_PASSWORD")


def build_database_url(database_name: str | None = None) -> URL:
    return URL.create(
        drivername="postgresql+psycopg",
        username=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST,
        port=DB_PORT,
        database=database_name or DB_NAME,
    )


engine = create_engine(
    build_database_url(),
    pool_pre_ping=True,
)


SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
