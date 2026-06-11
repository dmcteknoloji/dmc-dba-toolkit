#!/usr/bin/env bash
# Start a database engine in Docker, wait until it accepts connections, and
# write the client-command override the runner needs to /tmp/dmc-engine.env.
# Used by .github/workflows/test.yml; mirrors the local Docker workflow so what
# CI runs is exactly what a developer can reproduce on their machine.
set -euo pipefail

engine="${1:?usage: start-engine.sh <engine>}"
PW="DmcDbaToolkit!2026"

wait_for() { # wait_for <description> <command...>
  local desc="$1"; shift
  for i in $(seq 1 60); do
    if "$@" >/dev/null 2>&1; then echo "  $desc ready (${i}s)"; return 0; fi
    sleep 1
  done
  echo "::error::$desc never became ready"; docker logs --tail 50 "$CID" || true; exit 1
}

case "$engine" in
  mssql)
    CID=dmc-mssql
    docker run -d --name "$CID" -p 1433:1433 \
      -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=$PW" \
      mcr.microsoft.com/mssql/server:2022-latest >/dev/null
    SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
    wait_for "SQL Server" docker exec "$CID" $SQLCMD -S localhost -U sa -P "$PW" -C -Q "SELECT 1"
    echo "export DMC_MSSQL_CMD='docker exec -i $CID $SQLCMD -S localhost -U sa -P $PW -d master -C -b'" > /tmp/dmc-engine.env
    ;;
  postgresql)
    CID=dmc-pg
    docker run -d --name "$CID" -p 5432:5432 \
      -e "POSTGRES_PASSWORD=$PW" postgres:16 \
      -c shared_preload_libraries=pg_stat_statements >/dev/null
    wait_for "PostgreSQL" docker exec "$CID" pg_isready -U postgres
    # pg_stat_statements is the canonical query-stats source; several scripts
    # read it. Enable it so the suite exercises them instead of skipping.
    docker exec "$CID" psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" >/dev/null
    echo "export DMC_PG_CMD='docker exec -i $CID psql -U postgres -d postgres -v ON_ERROR_STOP=1 -P pager=off'" > /tmp/dmc-engine.env
    ;;
  mysql)
    CID=dmc-mysql
    docker run -d --name "$CID" -p 3306:3306 \
      -e "MYSQL_ROOT_PASSWORD=$PW" mysql:8 >/dev/null
    # During init MySQL runs a temporary server with --skip-networking that
    # already accepts socket logins, then restarts the real server. A socket
    # SELECT 1 can therefore pass against the temp server, in the gap before
    # the real one is up. Gate over TCP instead: only the real, networked
    # server answers on the port, so this clears the whole init dance.
    wait_for "MySQL" docker exec "$CID" mysql -h127.0.0.1 -P3306 --protocol=TCP -uroot -p"$PW" -e "SELECT 1"
    echo "export DMC_MYSQL_CMD='docker exec -i $CID mysql -uroot -p$PW --table mysql'" > /tmp/dmc-engine.env
    ;;
  mongodb)
    CID=dmc-mongo
    docker run -d --name "$CID" -p 27017:27017 mongo:7 >/dev/null
    wait_for "MongoDB" docker exec "$CID" mongosh --quiet --eval "db.runCommand({ping:1}).ok"
    echo "export DMC_MONGO_CMD='docker exec -i $CID mongosh mongodb://localhost:27017 --quiet'" > /tmp/dmc-engine.env
    ;;
  *)
    echo "::error::unknown engine $engine"; exit 2 ;;
esac

echo "  override: $(cat /tmp/dmc-engine.env)"
