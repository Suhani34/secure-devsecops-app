#!/usr/bin/env bash

set -uo pipefail

PASS_COUNT=0
FAIL_COUNT=0


pass() {
    echo "[PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}


fail() {
    echo "[FAIL] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}


dc() {
    sudo docker compose "$@"
}


docker_cmd() {
    sudo docker "$@"
}


echo "=========================================="
echo " Secure DevSecOps Runtime Security Checks"
echo "=========================================="
echo


# --------------------------------------------------
# Container IDs
# --------------------------------------------------

API_ID="$(dc ps -q api)"
NGINX_ID="$(dc ps -q nginx)"
DB_ID="$(dc ps -q db)"
DBINIT_ID="$(dc ps -a -q db-init)"

# --------------------------------------------------
# 1. Service health
# --------------------------------------------------

wait_for_healthy() {

    service="$1"
    max_attempts=30
    delay=2

    for attempt in $(seq 1 "$max_attempts"); do

        id="$(dc ps -q "$service")"

        if [ -z "$id" ]; then
            echo "[INFO] $service container not found yet ($attempt/$max_attempts)"
            sleep "$delay"
            continue
        fi

        health="$(
            docker_cmd inspect "$id" \
              --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
              2>/dev/null \
            || echo "unknown"
        )"

        echo "[INFO] $service health=$health ($attempt/$max_attempts)"

        if [ "$health" = "healthy" ]; then
            pass "$service health check"
            return 0
        fi

        case "$health" in
            exited|dead)
                fail "$service stopped before becoming healthy"
                return 1
                ;;
        esac

        sleep "$delay"

    done

    fail "$service did not become healthy within $((max_attempts * delay)) seconds"
    return 1
}


for service in api nginx db; do
    wait_for_healthy "$service"
done


# --------------------------------------------------
# 2. Non-root execution
# --------------------------------------------------

API_UID="$(dc exec -T api id -u)"

if [ "$API_UID" != "0" ]; then
    pass "API runs non-root (UID $API_UID)"
else
    fail "API runs as root"
fi


NGINX_UID="$(dc exec -T nginx id -u)"

if [ "$NGINX_UID" != "0" ]; then
    pass "Nginx runs non-root (UID $NGINX_UID)"
else
    fail "Nginx runs as root"
fi


# --------------------------------------------------
# 3. Read-only root filesystem
# --------------------------------------------------

for pair in \
    "api:$API_ID" \
    "nginx:$NGINX_ID" \
    "db:$DB_ID" \
    "db-init:$DBINIT_ID"
do

    service="${pair%%:*}"
    id="${pair#*:}"

    readonly="$(
        docker_cmd inspect "$id" \
          --format='{{.HostConfig.ReadonlyRootfs}}'
    )"

    if [ "$readonly" = "true" ]; then
        pass "$service root filesystem is read-only"
    else
        fail "$service root filesystem is writable"
    fi

done


# --------------------------------------------------
# 4. Actual filesystem write test
# --------------------------------------------------

if dc exec -T api sh -c \
    'touch /app/phase17-write-test' \
    >/dev/null 2>&1
then
    fail "API unexpectedly wrote to /app"
else
    pass "API cannot write to /app"
fi


if dc exec -T api sh -c \
    'touch /tmp/phase17-test && rm /tmp/phase17-test'
then
    pass "API tmpfs is writable"
else
    fail "API tmpfs is not writable"
fi


if dc exec -T nginx sh -c \
    'touch /etc/nginx/phase17-write-test' \
    >/dev/null 2>&1
then
    fail "Nginx unexpectedly wrote to /etc/nginx"
else
    pass "Nginx cannot write to /etc/nginx"
fi


# --------------------------------------------------
# 5. No-new-privileges
# --------------------------------------------------

for service in api nginx db; do

    if dc exec -T "$service" sh -c \
        'grep -q "^NoNewPrivs:[[:space:]]*1" /proc/1/status'
    then
        pass "$service no-new-privileges enabled"
    else
        fail "$service no-new-privileges not detected"
    fi

done


# --------------------------------------------------
# 6. Capabilities
# --------------------------------------------------

API_CAPS="$(dc exec -T api sh -c \
    'awk "/^CapEff:/ {print \$2}" /proc/1/status')"

if [ "$API_CAPS" = "0000000000000000" ]; then
    pass "API effective capabilities are empty"
else
    fail "API effective capabilities: $API_CAPS"
fi


NGINX_CAPS="$(dc exec -T nginx sh -c \
    'awk "/^CapEff:/ {print \$2}" /proc/1/status')"

if [ "$NGINX_CAPS" = "0000000000000000" ]; then
    pass "Nginx effective capabilities are empty"
else
    fail "Nginx effective capabilities: $NGINX_CAPS"
fi


# --------------------------------------------------
# 7. Privileged mode
# --------------------------------------------------

for pair in \
    "api:$API_ID" \
    "nginx:$NGINX_ID" \
    "db:$DB_ID"
do

    service="${pair%%:*}"
    id="${pair#*:}"

    privileged="$(
        docker_cmd inspect "$id" \
          --format='{{.HostConfig.Privileged}}'
    )"

    if [ "$privileged" = "false" ]; then
        pass "$service privileged mode disabled"
    else
        fail "$service is privileged"
    fi

done


# --------------------------------------------------
# 8. Host port exposure
# --------------------------------------------------

NGINX_PORT="$(dc port nginx 8080 2>/dev/null || true)"

if [ "$NGINX_PORT" = "127.0.0.1:8080" ]; then
    pass "Nginx exposed only on localhost:8080"
else
    fail "Unexpected Nginx port mapping: $NGINX_PORT"
fi

API_PUBLISHED_PORTS="$(
    docker_cmd inspect "$API_ID" \
      --format='{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}}={{json $bindings}} {{end}}{{end}}'
)"

if [ -z "$API_PUBLISHED_PORTS" ]; then
    pass "API has no host-published port"
else
    fail "API has host-published ports: $API_PUBLISHED_PORTS"
fi


DB_PUBLISHED_PORTS="$(
    docker_cmd inspect "$DB_ID" \
      --format='{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}}={{json $bindings}} {{end}}{{end}}'
)"

if [ -z "$DB_PUBLISHED_PORTS" ]; then
    pass "PostgreSQL has no host-published port"
else
    fail "PostgreSQL has host-published ports: $DB_PUBLISHED_PORTS"
fi



# --------------------------------------------------
# 9. Network segmentation
# --------------------------------------------------

API_NETWORKS="$(
    docker_cmd inspect "$API_ID" \
      --format='{{range $name, $_ := .NetworkSettings.Networks}}{{$name}} {{end}}'
)"

NGINX_NETWORKS="$(
    docker_cmd inspect "$NGINX_ID" \
      --format='{{range $name, $_ := .NetworkSettings.Networks}}{{$name}} {{end}}'
)"

DB_NETWORKS="$(
    docker_cmd inspect "$DB_ID" \
      --format='{{range $name, $_ := .NetworkSettings.Networks}}{{$name}} {{end}}'
)"


if [[ "$API_NETWORKS" == *frontend* ]] \
    && [[ "$API_NETWORKS" == *backend* ]]
then
    pass "API connected to frontend and backend"
else
    fail "Unexpected API networks: $API_NETWORKS"
fi


if [[ "$NGINX_NETWORKS" == *frontend* ]] \
    && [[ "$NGINX_NETWORKS" != *backend* ]]
then
    pass "Nginx isolated to frontend"
else
    fail "Unexpected Nginx networks: $NGINX_NETWORKS"
fi


if [[ "$DB_NETWORKS" == *backend* ]] \
    && [[ "$DB_NETWORKS" != *frontend* ]]
then
    pass "PostgreSQL isolated to backend"
else
    fail "Unexpected PostgreSQL networks: $DB_NETWORKS"
fi


# --------------------------------------------------
# 10. Secret scoping
# --------------------------------------------------

if dc exec -T api sh -c \
    'test -r /run/secrets/db_password &&
     test ! -e /run/secrets/postgres_admin_password'
then
    pass "API receives only application DB secret"
else
    fail "API secret scope is incorrect"
fi


if dc exec -T nginx sh -c \
    'test ! -e /run/secrets/db_password &&
     test ! -e /run/secrets/postgres_admin_password'
then
    pass "Nginx receives no database secrets"
else
    fail "Nginx unexpectedly has database secrets"
fi


# --------------------------------------------------
# 11. Application connectivity
# --------------------------------------------------

if curl \
    --fail \
    --silent \
    http://127.0.0.1:8080/health \
    >/dev/null
then
    pass "Application health endpoint reachable"
else
    fail "Application health endpoint failed"
fi


if curl \
    --fail \
    --silent \
    http://127.0.0.1:8080/ready \
    >/dev/null
then
    pass "Application readiness endpoint reachable"
else
    fail "Application readiness endpoint failed"
fi


# --------------------------------------------------
# Summary
# --------------------------------------------------

echo
echo "=========================================="
echo " Results"
echo "=========================================="

echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

echo

if [ "$FAIL_COUNT" -ne 0 ]; then
    echo "RUNTIME SECURITY VALIDATION FAILED"
    exit 1
fi

echo "RUNTIME SECURITY VALIDATION PASSED"
exit 0
