---
name: Worktree Manager
slug: worktree-manager
version: 1.0.0
description: "Manage Docker-based dev instances and git worktrees via run.sh. Use for starting, stopping, creating, or removing isolated dev environments per branch."
changelog: Initial release — full worktree lifecycle (create, start, stop, remove) with shared MySQL and nginx-proxy.
triggers:
  - "start instance"
  - "stop instance"
  - "create worktree"
  - "remove worktree"
  - "criar worktree"
  - "remover worktree"
  - "iniciar instância"
  - "parar instância"
  - "list instances"
  - "listar instâncias"
  - "run.sh"
metadata: {"clawdbot":{"emoji":"🌿","requires":{"bins":["docker","git"]},"os":["linux","darwin"]}}
---

# Worktree Manager

Manage Docker dev instances and git worktrees via `./run.sh` at the project root.

Each instance gets its own docker-compose stack (database + backend + frontend), isolated git branch, and `.env.worktree-<name>` file. All instances share a single MySQL container and an nginx-proxy for DNS-based routing.

## Architecture

```
main repo (./)
├── docker-compose.yml        # stack template (shared across instances)
├── run.sh                    # this plugin's entry point
├── .env.base                 # main instance env
├── .env.worktree-<name>      # per-worktree env
└── .worktrees/
    └── <name>/               # git worktree checkout

nginx-proxy/
└── docker-compose.yml        # MySQL + reverse proxy (shared infra)
```

- **main** → uses `.env.base`, project root as working dir
- **worktree** → uses `.env.worktree-<name>`, checked out at `.worktrees/<name>`
- URLs follow `http://<name>.frontend.localhost` / `http://<name>.backend.localhost`
- MySQL container name and credentials are configurable via env vars (defaults: `CODAI_MYSQL_CONTAINER`, `CODAI_MYSQL_ROOT_PASS`, `CODAI_MAIN_DB`)

## Commands

All commands run from the project root (`$CLAUDE_PROJECT_DIR`):

```bash
./run.sh list                        # show all instances and status
./run.sh start [main|<name>]         # create db, dump main→instance, start containers
./run.sh stop  [main|<name>]         # stop containers (db persists)
./run.sh restart [main|<name>]       # stop then start
./run.sh logs  [main|<name>]         # follow container logs
./run.sh create-worktree <name>      # git worktree + branch + env file
./run.sh remove-worktree <name>      # stop containers + remove worktree + drop db
```

Shared infra (nginx-proxy + MySQL):
```bash
cd nginx-proxy && docker compose up -d   # start proxy (once)
cd nginx-proxy && docker compose down    # stop proxy
docker ps | grep codai_db               # check MySQL
```

## How to Execute Tasks

### Starting an existing instance
1. Check nginx-proxy: `docker ps --filter name=codai_nginx_proxy --format '{{.Names}}'`
2. If not running: `cd nginx-proxy && docker compose up -d`
3. `./run.sh start <name>`
4. Report URLs: `http://<name>.frontend.localhost` and `http://<name>.backend.localhost`

### Creating a new worktree
1. Ensure nginx-proxy is running (start if needed)
2. `./run.sh create-worktree <name>` → creates branch `worktree/<name>`, dir `.worktrees/<name>`, env file
3. `./run.sh start <name>` → builds and starts containers with db snapshot from main
4. Report URLs

### Stopping an instance
1. `./run.sh stop <name>`

### Removing a worktree (destructive)
**Always confirm with user before removing** — deletes containers, volumes, git worktree, branch, and env file.
1. Confirm: "Remove worktree '<name>'? This deletes containers, volumes, branch `worktree/<name>`, and `.env.worktree-<name>`."
2. `./run.sh remove-worktree <name>`

### Listing instances
```bash
./run.sh list
```

## Rules

- Always check if nginx-proxy is running before starting an instance. Start it automatically if not.
- Always confirm before `remove-worktree` — it is irreversible.
- After `start`, always print frontend and backend URLs.
- If `./run.sh` is not executable: `chmod +x run.sh`
- `main` uses `.env.base`. Worktrees use `.env.worktree-<name>`.
- Env files are gitignored (`.env.worktree*`). Worktrees dir is gitignored (`.worktrees/`).

## Configuration

Override defaults via shell environment or `.env.base`:

| Variable               | Default      | Purpose                        |
|------------------------|--------------|--------------------------------|
| `CODAI_MYSQL_CONTAINER`| `codai_db`   | Shared MySQL container name    |
| `CODAI_MYSQL_ROOT_PASS`| `secret`     | MySQL root password            |
| `CODAI_MAIN_DB`        | `codai_main` | Source DB for snapshot on start|

## External Endpoints

| Endpoint | Data Sent | Purpose |
|----------|-----------|---------|
| Local Docker daemon | Container commands | Start/stop/manage instances |
| Local MySQL (shared) | SQL commands | DB creation and snapshot |

No external network requests. All operations are local.

## Security & Privacy

- All data stays local (Docker + MySQL on localhost).
- MySQL root password should be changed from default `secret` in production-adjacent environments.
- `.env.worktree-*` files are gitignored and must never be committed.

## Related Skills

- `using-git-worktrees` — git worktree mechanics and isolation patterns
- `paperclip-dev` — Paperclip-specific dev environment management

## Feedback

- If useful: `clawhub star worktree-manager`
- Stay updated: `clawhub sync`
