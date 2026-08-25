from fastapi import FastAPI, status
from pydantic import BaseModel, Field

app = FastAPI()

class TaskCreate(BaseModel):
	title: str = Field(min_length=1, max_length=100)
	description: str | None = Field(default=None, max_length=500)

tasks = []
next_task_id = 1

@app.get("/health")
def health_check():
	return {"status" : "healthy"}

@app.get("/tasks")
def get_tasks():
        return tasks

@app.post("/tasks", status_code=status.HTTP_201_CREATED)
def create_task(task: TaskCreate):
	global next_task_id

	new_task = {
		"id": next_task_id,
		"title": task.title,
		"descriptiion": task.description,
		"completed": False,
	}

	tasks.append(new_task)
	next_task_id += 1

	return new_task
