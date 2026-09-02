# Architecture

## Application Architecture

```mermaid
flowchart LR

    Client[Client]

    Nginx[Nginx Reverse Proxy]
    API[FastAPI Application]
    DB[(PostgreSQL)]

    Client -->|127.0.0.1:8080| Nginx
    Nginx -->|Frontend Network| API
    API -->|Internal Backend Network| DB
