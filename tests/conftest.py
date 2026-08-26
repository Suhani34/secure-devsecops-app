import pytest

from app import main

@pytest.fixture(autouse=True)
def reset_task_state():
	main.tasks.clear()
	main.next_task_id = 1

	yield

	main.tasks.clear()
	main.next_task_id = 1
