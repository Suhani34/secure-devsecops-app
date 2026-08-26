import os

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app import main, models
from app.database import Base, build_database_url, get_db


TEST_DB_NAME = os.getenv("TEST_DB_NAME")


if not TEST_DB_NAME or not TEST_DB_NAME.endswith("_test"):
    raise RuntimeError(
        "TEST_DB_NAME must point to a dedicated test database ending in '_test'"
    )


test_engine = create_engine(
    build_database_url(TEST_DB_NAME),
    pool_pre_ping=True,
)


TestingSessionLocal = sessionmaker(
    bind=test_engine,
    autoflush=False,
    expire_on_commit=False,
)


Base.metadata.create_all(bind=test_engine)


def override_get_db():
    db = TestingSessionLocal()

    try:
        yield db
    finally:
        db.close()


main.app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def reset_database():
    with test_engine.begin() as connection:
        connection.execute(
            text("TRUNCATE TABLE tasks RESTART IDENTITY")
        )

    yield

    with test_engine.begin() as connection:
        connection.execute(
            text("TRUNCATE TABLE tasks RESTART IDENTITY")
        )
