# Threat Model

## Assets

The primary assets protected by this project are:

- application source code
- database credentials
- PostgreSQL data
- application dependencies
- Docker images
- CI/CD pipeline integrity
- Git history
- container runtime

## Threats and Security Controls

| Threat | Control |
|---|---|
| Secret committed to Git | Gitleaks + `.gitignore` |
| Secret copied into Docker image | `.dockerignore` + image verification |
| Vulnerable Python dependency | Trivy SCA |
| Vulnerable OS package | Trivy image scanning |
| Insecure source-code pattern | Semgrep SAST |
| Mutable GitHub Action | Full commit SHA pinning |
| Vulnerable code merged | Required Security Gate |
| Container running as root | Non-root users |
| Container filesystem modification | Read-only root filesystem |
| Privilege escalation | `no-new-privileges` |
| Linux capability abuse | Capability dropping |
| Direct PostgreSQL exposure | Internal network + no host port |
| Nginx directly accessing DB | Docker network segmentation |
| API receiving administrator credentials | Secret scoping |
| Database privilege escalation | Least-privileged application role |
| Resource exhaustion | CPU, memory and PID limits |
| Log disk exhaustion | Docker log rotation |
| Runtime hardening regression | Automated runtime security validation |
| EOL operating system | Trivy `--exit-on-eol` |

## Trust Boundaries

```text
User
 │
 ▼
Nginx
-------------------
Frontend Boundary
-------------------
 │
 ▼
FastAPI
-------------------
Backend Boundary
-------------------
 │
 ▼
PostgreSQL
