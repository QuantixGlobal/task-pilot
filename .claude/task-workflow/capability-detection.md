# Capability detection

Do not hardcode a toolchain. Probe, then record the matrix in `00-meta.md`. Rule: **only record
commands you have confirmed exist**. If you cannot detect one, write `N/A` — never invent a command.

## How to probe

```bash
ls Makefile Taskfile.yml justfile package.json go.mod pyproject.toml Cargo.toml pom.xml 2>/dev/null
grep -E '^[a-zA-Z0-9_.-]+:' Makefile 2>/dev/null | cut -d: -f1 | sort -u   # make targets
jq -r '.scripts | keys[]' package.json 2>/dev/null                          # npm scripts
ls sonar-project.properties .sonarcloud.properties 2>/dev/null
ls .golangci.yml .eslintrc* biome.json ruff.toml .flake8 2>/dev/null
ls .github/workflows .gitlab-ci.yml 2>/dev/null
```

CI config (`.gitlab-ci.yml`, `.github/workflows/*`) is the most reliable source for "which commands
actually gate a merge". Trust it over guesses inferred from file names.

## Matrix to fill in

| Capability | Command | Present? |
|---|---|---|
| build | | |
| lint | | |
| lint, new issues only | | |
| unit test | | |
| unit test, single package | | |
| integration test | | |
| sonar | | |
| format | | |

## Ecosystem notes

**Go** — `go build ./...`; `golangci-lint run ./...`; new issues only:
`golangci-lint run --new-from-rev=<base>`; unit `go test -cover ./...`; single package
`go test ./service/user/...`. Integration tests are usually separated by a build tag
(`go test -tags integration ./...`) and **require live infrastructure** (DB, Redis). Check
`docker-compose.yml` and the environment before running, or a failure will look like a code bug.

**Node/TS** — `tsc --noEmit` is the most useful "build" step; the test runner comes from `scripts`;
eslint supports `--quiet`. There is no standard notion of integration tests — read `scripts`.

**Python** — `ruff check`, `mypy`, `pytest`; integration is usually a marker (`pytest -m integration`).

**QA automation / pure frontend** — often have NO integration tests and possibly no Sonar.
Record `N/A` and move on; this is not a gap.

## Integration tests — rule

Run them only when the target/marker/tag is **actually detected**. If they exist but depend on
infrastructure (DB, Redis, containers), verify that infrastructure is already up; if it is not,
**ask the user** rather than running `docker compose up` yourself — starting infrastructure is a
heavy action and may collide with their local data.
