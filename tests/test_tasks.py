from fastapi.testclient import TestClient

from app import main


client = TestClient(main.app)


def test_health_check():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

def test_get_tasks_when_empty():
    response = client.get("/tasks")

    assert response.status_code == 200
    assert response.json() == []

def test_create_task():
    response = client.post(
      "/tasks",
      json={
          "title": "Learn Docker",
          "description": "Understand Docker images and container"
      },
    )

    assert response.status_code == 201

    data = response.json()

    assert data["id"] == 1
    assert data["title"] == "Learn Docker"
    assert data["description"] == "Understand Docker images and container"
    assert data["completed"] is False

def test_create_task_without_description():
    response = client.post(
      "/tasks",
      json={
        "title": "Learn Github Actions",
      },
    )

    assert response.status_code == 201

    data = response.json()

    assert data["id"] == 1
    assert data["title"] == "Learn Github Actions"
    assert data["description"] is None
    assert data["completed"] is False

def test_create_task_without_title_is_rejected():
    response = client.post(
        "/tasks",
        json={
            "description": "Missing required title",
        },
    )

    tasks_response = client.get("/tasks")
    assert tasks_response.status_code == 200
    assert tasks_response.json() == []

def test_create_task_with_empty_title_is_rejected():
    response = client.post(
        "/tasks",
        json={
            "title": "",
        },
    )

    tasks_response = client.get("/tasks")
    assert tasks_response.status_code == 200
    assert tasks_response.json() == []

def test_create_task_with_too_long_title_is_rejected():
    response = client.post(
        "/tasks",
        json={
            "title": "A" * 101,
        },
    )
    tasks_response = client.get("/tasks")
    assert tasks_response.status_code == 200
    assert tasks_response.json() == []

def test_get_existing_task():
    create_response = client.post(
        "/tasks",
        json={
            "title": "Learn Docker",
            "description": "Understand containers",
        },
    )

    task_id = create_response.json()["id"]

    response = client.get(f"/tasks/{task_id}")

    assert response.status_code == 200
    assert response.json()["id"] == task_id
    assert response.json()["title"] == "Learn Docker"

def test_get_nonexistent_task_returns_404():
    response = client.get("/tasks/999")

    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}

def test_get_task_with_invalid_id_is_rejected():
    response = client.get("/tasks/abc")

    assert response.status_code == 422

def test_update_task():
    create_response = client.post(
        "/tasks",
        json={
            "title": "Learn Docker",
            "description": "Start Docker",
        },
    )

    task_id = create_response.json()["id"]

    response = client.put(
        f"/tasks/{task_id}",
        json={
            "title": "Learn Docker Security",
            "description": "Study non-root containers",
            "completed": True,
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["id"] == task_id
    assert data["title"] == "Learn Docker Security"
    assert data["description"] == "Study non-root containers"
    assert data["completed"] is True

    stored_response = client.get(f"/tasks/{task_id}")

    assert stored_response.status_code == 200
    assert stored_response.json()["completed"] is True

def test_update_nonexistent_task_returns_404():
    response = client.put(
        "/tasks/999",
        json={
            "title": "Does not exist",
            "description": None,
            "completed": True,
        },
    )

    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}

def test_update_task_with_empty_title_is_rejected():
    create_response = client.post(
        "/tasks",
        json={
            "title": "Original title",
        },
    )

    task_id = create_response.json()["id"]

    response = client.put(
        f"/tasks/{task_id}",
        json={
            "title": "",
            "description": "Invalid update",
            "completed": True,
        },
    )

    assert response.status_code == 422

    stored_response = client.get(f"/tasks/{task_id}")

    assert stored_response.json()["title"] == "Original title"

def test_delete_task():
    create_response = client.post(
        "/tasks",
        json={
            "title": "Delete me",
        },
    )

    task_id = create_response.json()["id"]

    response = client.delete(f"/tasks/{task_id}")

    assert response.status_code == 204
    assert response.content == b""

    get_response = client.get(f"/tasks/{task_id}")

    assert get_response.status_code == 404

def test_delete_nonexistent_task_returns_404():
    response = client.delete("/tasks/999")

    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}

def test_complete_task_crud_flow():
    create_response = client.post(
        "/tasks",
        json={
            "title": "DevSecOps Project",
            "description": "Build secure pipeline",
        },
    )

    assert create_response.status_code == 201

    task_id = create_response.json()["id"]

    get_response = client.get(f"/tasks/{task_id}")

    assert get_response.status_code == 200
    assert get_response.json()["title"] == "DevSecOps Project"

    update_response = client.put(
        f"/tasks/{task_id}",
        json={
            "title": "DevSecOps Project",
            "description": "Build secure pipeline",
            "completed": True,
        },
    )

    assert update_response.status_code == 200
    assert update_response.json()["completed"] is True

    delete_response = client.delete(f"/tasks/{task_id}")

    assert delete_response.status_code == 204

    final_response = client.get(f"/tasks/{task_id}")

    assert final_response.status_code == 404
