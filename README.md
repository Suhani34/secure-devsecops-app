# Secure DevSecOps Task API

A security-focused FastAPI and PostgreSQL application demonstrating an end-to-end DevSecOps workflow including secure containerization, secret management, SAST, dependency scanning, image vulnerability scanning, runtime hardening and enforced CI security gates.

## Project Overview

The application is a containerized REST API backed by PostgreSQL and accessed through an Nginx reverse proxy.

The project focuses primarily on implementing and validating security controls throughout the software development lifecycle.

## Technology Stack

### Application

- Python 3.12
- FastAPI
- Uvicorn
- SQLAlchemy
- Psycopg
- PostgreSQL

### Infrastructure

- Docker
- Docker Compose
- Nginx
- Linux

### Testing

- Pytest
- HTTPX
- pytest-cov

### Security

- Gitleaks
- Semgrep
- Trivy
- Docker runtime hardening

### CI/CD

- GitHub Actions
- GitHub branch rulesets
- Required Security Gate

## Architecture

```mermaid
flowchart LR

    Client[Client]

    Nginx[Nginx Reverse Proxy]
    API[FastAPI Application]
    DB[(PostgreSQL)]

    Client -->|127.0.0.1:8080| Nginx
    Nginx -->|frontend| API
    API -->|internal backend| DB
