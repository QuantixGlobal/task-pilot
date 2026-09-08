# SonarQube (local Docker)

Standalone local Community instance. Works on an **empty / new repo** — agent creates every file. Do not assume Makefile, `.env`, `.env.example`, or an existing compose file.

All generated files live under **`.sonar/`** (add that directory to `.gitignore`). Do **not** invent a token. Do **not** commit `.sonar/`.

| | |
| --- | --- |
| URL | `http://localhost:9000` |
| First login | `admin` / `admin` (must change on first use) |
| Local admin password | `Sonar-Local-9000!` |
| Project key | directory name of the repo (`basename "$PWD"`) |
| Quality gate | copy **Sonar way** → **Local**, fail if high-severity issues `> 0` |
| Secrets | `.sonar/local.env` |

### Agent (one-time)

Docker Desktop must already be running. `jq` required (`brew install jq` if missing). Linux only: `sysctl -n vm.max_map_count` must be `>= 262144` (`sudo sysctl -w vm.max_map_count=262144`).

Run from the repo root. Skip a step when it already succeeded.

**1. Local dir + compose + gitignore**

```bash
PROJECT_KEY=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
mkdir -p .sonar
grep -qxF '.sonar/' .gitignore 2>/dev/null || echo '.sonar/' >> .gitignore

cat > .sonar/docker-compose.yml <<EOF
services:
  sonarqube-db:
    image: postgres:15-alpine
    container_name: sonarqube-db-${PROJECT_KEY}
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - sonarqube_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar -d sonar"]
      interval: 10s
      timeout: 5s
      retries: 5
  sonarqube:
    image: sonarqube:lts-community
    container_name: sonarqube-${PROJECT_KEY}
    depends_on:
      sonarqube-db:
        condition: service_healthy
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:9000/api/system/status | grep -q '\"status\":\"UP\"'"]
      interval: 15s
      timeout: 10s
      retries: 20
      start_period: 60s
volumes:
  sonarqube_db_data:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:
EOF

echo "SONAR_HOST_URL=http://localhost:9000" > .sonar/local.env
echo "SONAR_PROJECT_KEY=${PROJECT_KEY}" >> .sonar/local.env
```

**2. Start stack and wait until UP** (~1–3 min first image pull)

```bash
docker compose -f .sonar/docker-compose.yml up -d
for i in $(seq 1 40); do
  curl -sf http://localhost:9000/api/system/status | grep -q '"status":"UP"' && break
  sleep 5
done
curl -sf http://localhost:9000/api/system/status | grep -q '"status":"UP"'
```

**3. Admin password** — only if `admin`/`admin` still works

```bash
curl -sf -u admin:admin http://localhost:9000/api/authentication/validate \
  | jq -e '.valid == true' >/dev/null \
&& curl -sS -u admin:admin -X POST http://localhost:9000/api/users/change_password \
  --data-urlencode "login=admin" \
  --data-urlencode "previousPassword=admin" \
  --data-urlencode "password=Sonar-Local-9000!"
```

If `admin`/`admin` is already rejected: ask the user for the current admin password **or** an existing User token. Write `SONAR_ADMIN_PASSWORD=...` or `SONAR_TOKEN=...` into `.sonar/local.env`, then continue.

**4. User token** — skip if `.sonar/local.env` already has a token that validates

```bash
set -a && source .sonar/local.env && set +a
if [[ -n "${SONAR_TOKEN:-}" ]] && curl -sf -u "${SONAR_TOKEN}:" http://localhost:9000/api/authentication/validate \
  | jq -e '.valid == true' >/dev/null; then
  echo "SONAR_TOKEN ok"
else
  PASS="${SONAR_ADMIN_PASSWORD:-Sonar-Local-9000!}"
  curl -sS -u "admin:${PASS}" -X POST http://localhost:9000/api/user_tokens/revoke -d "name=local" || true
  TOKEN=$(curl -sS -u "admin:${PASS}" -X POST http://localhost:9000/api/user_tokens/generate \
    -d "name=local" -d "type=USER_TOKEN" | jq -r '.token')
  [[ -n "$TOKEN" && "$TOKEN" != null ]]
  grep -qE '^SONAR_TOKEN=' .sonar/local.env \
    && sed -i.bak "s|^SONAR_TOKEN=.*|SONAR_TOKEN=${TOKEN}|" .sonar/local.env && rm -f .sonar/local.env.bak \
    || echo "SONAR_TOKEN=${TOKEN}" >> .sonar/local.env
fi
```

**5. Quality gate + project** (idempotent)

```bash
set -a && source .sonar/local.env && set +a
AUTH=(-u "${SONAR_TOKEN}:")
curl -sf "${AUTH[@]}" http://localhost:9000/api/qualitygates/list \
  | jq -e '.qualitygates[] | select(.name=="Local")' >/dev/null \
|| curl -sS -X POST "${AUTH[@]}" http://localhost:9000/api/qualitygates/copy \
  -d "sourceName=Sonar way" -d "name=Local"
for METRIC in new_software_quality_high_issues new_critical_violations software_quality_high_issues critical_violations; do
  curl -sf "${AUTH[@]}" -G http://localhost:9000/api/metrics/search --data-urlencode "q=${METRIC}" \
    | jq -e --arg k "$METRIC" '.metrics[] | select(.key==$k)' >/dev/null || continue
  curl -sS -X POST "${AUTH[@]}" http://localhost:9000/api/qualitygates/create_condition \
    -d "gateName=Local" -d "metric=${METRIC}" -d "op=GT" -d "error=0" || true
  break
done
curl -sf "${AUTH[@]}" -G http://localhost:9000/api/projects/search \
  --data-urlencode "projects=${SONAR_PROJECT_KEY}" \
  | jq -e --arg k "$SONAR_PROJECT_KEY" '.components[] | select(.key==$k)' >/dev/null \
|| curl -sS -X POST "${AUTH[@]}" http://localhost:9000/api/projects/create \
  -d "project=${SONAR_PROJECT_KEY}" -d "name=${SONAR_PROJECT_KEY}"
curl -sS -X POST "${AUTH[@]}" http://localhost:9000/api/qualitygates/select \
  -d "gateName=Local" -d "projectKey=${SONAR_PROJECT_KEY}"
```

**6. Optional — scanner properties** (only if the repo has no `sonar-project.properties` yet)

```bash
set -a && source .sonar/local.env && set +a
test -f sonar-project.properties || cat > sonar-project.properties <<EOF
sonar.projectKey=${SONAR_PROJECT_KEY}
sonar.sources=.
sonar.exclusions=**/*_test.go,**/*_test.ts,**/*_test.js,**/node_modules/**,**/.sonar/**
EOF
```

### User

Nothing on success. Do not open http://localhost:9000 unless step 3 failed (password already changed).

### Smoke test

```bash
set -a && source .sonar/local.env && set +a
curl -sf -u "${SONAR_TOKEN}:" http://localhost:9000/api/authentication/validate | jq -e '.valid == true'
curl -sf -u "${SONAR_TOKEN}:" -G http://localhost:9000/api/qualitygates/get_by_project \
  --data-urlencode "project=${SONAR_PROJECT_KEY}" | jq -e '.qualityGate.name=="Local"'
```

Done when both succeed.

Optional first scan (Docker scanner — no local `sonar-scanner` install):

```bash
set -a && source .sonar/local.env && set +a
docker run --rm --network host \
  -e SONAR_HOST_URL=http://localhost:9000 \
  -e SONAR_TOKEN \
  -v "$PWD:/usr/src" -w /usr/src \
  sonarsource/sonar-scanner-cli:11
```

Stop: `docker compose -f .sonar/docker-compose.yml down`.

Community Edition has no branch/PR analysis. Local scan is mainline-only.

---
