---
name: codai
slug: codai
version: 1.0.0
description: "Orchestration skill for the codai-dev local environment. Routes user commands to the right plugin (proxy-manager, mysql-manager, postgres-manager, redis-manager, worktree-manager, phpmyadmin-manager, pgadmin-manager, redis-commander). Use when the user asks to manage any part of the dev environment without specifying which plugin."
changelog: Initial release.
triggers:
  - "subir mysql"
  - "subir postgres"
  - "subir redis"
  - "subir proxy"
  - "subir ambiente"
  - "start mysql"
  - "start postgres"
  - "start redis"
  - "start environment"
  - "criar worktree"
  - "create worktree"
  - "remover worktree"
  - "remove worktree"
  - "dump main para"
  - "dump main to"
  - "subir worktree"
  - "parar instância"
  - "listar instâncias"
  - "status do ambiente"
  - "environment status"
  - "abrir phpmyadmin"
  - "start phpmyadmin"
  - "abrir pgadmin"
  - "start pgadmin"
  - "abrir redis commander"
  - "start redis commander"
  - "codai"
metadata: {"clawdbot":{"emoji":"⚙️","requires":{"bins":["docker","git"]},"os":["linux","darwin"]}}
---

# Codai

Orchestration skill for the codai-dev local development environment. Routes user requests to the correct plugin without requiring the user to remember which script handles what.

## Plugin Map

| What user asks | Plugin | Command |
|----------------|--------|---------|
| subir/start MySQL | `mysql-manager` | `./mysql/run.sh start` |
| parar/stop MySQL | `mysql-manager` | `./mysql/run.sh stop` |
| status MySQL | `mysql-manager` | `./mysql/run.sh status` |
| dump de main para `<x>` | `mysql-manager` | `./mysql/run.sh dump codai_main codai_<x>` |
| subir/start PostgreSQL | `postgres-manager` | `./postgres/run.sh start` |
| parar/stop PostgreSQL | `postgres-manager` | `./postgres/run.sh stop` |
| dump postgres para `<x>` | `postgres-manager` | `./postgres/run.sh dump codai_main codai_<x>` |
| subir/start Redis | `redis-manager` | `./redis/run.sh start` |
| parar/stop Redis | `redis-manager` | `./redis/run.sh stop` |
| flush Redis | `redis-manager` | `./redis/run.sh flush` |
| subir/start proxy | `proxy-manager` | `<plugin-root>/proxy-manager/run.sh start` |
| conectar proxy `<x>` | `proxy-manager` | `<plugin-root>/proxy-manager/run.sh connect <x>` |
| criar worktree `<x>` | `worktree-manager` | `<plugin-root>/worktree-manager/run.sh create-worktree <x>` |
| subir worktree `<x>` | `worktree-manager` | `<plugin-root>/worktree-manager/run.sh start <x>` |
| parar worktree `<x>` | `worktree-manager` | `<plugin-root>/worktree-manager/run.sh stop <x>` |
| remover worktree `<x>` | `worktree-manager` | `<plugin-root>/worktree-manager/run.sh remove-worktree <x>` |
| listar instâncias | `worktree-manager` | `<plugin-root>/worktree-manager/run.sh list` |
| abrir phpMyAdmin | `phpmyadmin-manager` | `<plugin-root>/phpmyadmin-manager/run.sh start` |
| parar phpMyAdmin | `phpmyadmin-manager` | `<plugin-root>/phpmyadmin-manager/run.sh stop` |
| abrir pgAdmin | `pgadmin-manager` | `<plugin-root>/pgadmin-manager/run.sh start` |
| parar pgAdmin | `pgadmin-manager` | `<plugin-root>/pgadmin-manager/run.sh stop` |
| abrir Redis Commander | `redis-commander` | `<plugin-root>/redis-commander/run.sh start` |
| parar Redis Commander | `redis-commander` | `<plugin-root>/redis-commander/run.sh stop` |
| status geral | todos | run each `status` in order |

## Plugin Paths

Plugin scripts use **absolute paths** from the session context (`<codai-plugin-paths>` block).
Replace `<plugin-root>` with the path shown in that block. Example:
```
/home/user/.claude/skills/mysql-manager/run.sh start
```

Never use `./run.sh` — relative paths fail when the skill is invoked from a different project.

## Startup Order

Always follow this sequence:

```bash
<plugin-root>/proxy-manager/run.sh start      # 1. creates nginx-proxy_net network
<plugin-root>/mysql-manager/run.sh start      # 2. MySQL (or postgres-manager / redis-manager)
<plugin-root>/worktree-manager/run.sh start main  # 3. main app instance
```

Optional web UIs (start after their respective database):
```bash
<plugin-root>/phpmyadmin-manager/run.sh start   # MySQL web UI → http://localhost:8081
<plugin-root>/pgadmin-manager/run.sh start      # PostgreSQL web UI → http://localhost:8082
<plugin-root>/redis-commander/run.sh start      # Redis web UI → http://localhost:8083
```

## Multi-Step Workflows

### Create and start a new worktree from scratch
```bash
<plugin-root>/worktree-manager/run.sh create-worktree <name>
<plugin-root>/worktree-manager/run.sh start <name>
```
Result: `http://<name>.frontend.localhost` and `http://<name>.backend.localhost`

### Dump main database to a feature branch
```bash
<plugin-root>/mysql-manager/run.sh dump codai_main codai_<name>
# For PostgreSQL:
<plugin-root>/postgres-manager/run.sh dump codai_main codai_<name>
```

### Remove a worktree completely (confirm first)
Confirm: "Remover worktree '<name>'? Isso apaga os containers, banco de dados, git worktree (branch `worktree/<name>`) e o env file."
```bash
<plugin-root>/worktree-manager/run.sh remove-worktree <name>
```

### Full environment status
```bash
<plugin-root>/worktree-manager/run.sh list
<plugin-root>/mysql-manager/run.sh status
<plugin-root>/proxy-manager/run.sh status
```

## Rules

- **Always confirm** before `remove-worktree` — it is irreversible.
- **Always report URLs** after starting a worktree: frontend and backend.
- **Check infra first**: if MySQL or proxy is not running, start them before trying to start an instance.
- **Startup order matters**: proxy → databases → app instances.
- If the user says "sobe tudo" or "start everything", start in order: proxy → mysql → run.sh start main.
- Never run `./mysql/run.sh drop-db codai_main` — it is the source of truth.

## Environment Variables (shared across plugins)

| Variable          | Default             | Used by                            |
|-------------------|---------------------|------------------------------------|
| `MYSQL_CONTAINER` | `codai_db`          | mysql-manager, worktree-manager    |
| `MYSQL_ROOT_PASS` | `secret`            | mysql-manager, worktree-manager    |
| `MYSQL_MAIN_DB`   | `codai_main`        | mysql-manager, worktree-manager    |
| `PROXY_CONTAINER` | `codai_nginx_proxy` | proxy-manager, worktree-manager    |
| `CODAI_NETWORK`   | `nginx-proxy_net`   | all plugins                        |
| `PROJECT_PREFIX`  | `codai-dev`         | proxy-manager, worktree-manager    |
