# Security Policy

## Security Controls

This project includes:

- automated tests and coverage enforcement
- Gitleaks secret scanning
- Semgrep static application security testing
- Trivy dependency scanning
- Trivy configuration scanning
- Trivy Docker image scanning
- non-root container execution
- read-only root filesystems
- Linux capability reduction
- no-new-privileges
- Docker network segmentation
- scoped database secrets
- least-privileged database access
- runtime security validation
- protected GitHub Security Gate

## Reporting Security Issues

If a security issue is discovered, please create a GitHub issue without including passwords, private credentials, access tokens or exploit secrets.

## Security Audit

The project security review is documented in:

[Final Security Audit](docs/SECURITY_AUDIT.md)
