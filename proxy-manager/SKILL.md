---
name: Proxy Manager
slug: proxy-manager
version: 1.0.0
description: "Manage the shared nginx-proxy Docker container and its network connections. Auto-discovers app containers via VIRTUAL_HOST labels. Start this first — it creates the shared Docker network used by mysql-manager and worktree-manager."
changelog: Initial release.
triggers:
  - "start proxy"
  - "stop proxy"
  - "nginx status"
  - "proxy status"
  - "conectar proxy"
  - "connect proxy"
  - "proxy-manager"
  - "rotas do nginx"
  - "nginx routes"
metadata: {"clawdbot":{"emoji":"🔀","requires":{"bins":["docker"]},"os":["linux","darwin"]}}
---

# Proxy Manager

Manages the shared nginx-proxy Docker container (`jwilder/nginx-proxy`) and the Docker network (`nginx-proxy_net`) used by all dev instances.

The proxy auto-discovers containers with `VIRTUAL_HOST` labels and creates routes. It also owns the shared Docker network that allows MySQL and app containers to communicate.

## Architecture

```
proxy-manager/
├── docker-compose.yml   # nginx-proxy container + codai_net network
└── run.sh               # lifecycle + network connection CLI
```

Start order: **proxy-manager first** (creates the network), then mysql-manager, then worktree-manager.

## Commands

```bash
./run.sh start                      # start nginx-proxy (creates codai_net network)
./run.sh stop                       # stop nginx-proxy
./run.sh status                     # show status, connected networks, active routes
./run.sh connect <instance>         # connect proxy to instance's Docker network
./run.sh disconnect <instance>      # disconnect proxy from instance network
./run.sh auto-connect               # connect proxy to ALL project networks
./run.sh reload                     # reload nginx config without restart
```

## How to Execute Tasks

### First-time setup
```bash
cd proxy-manager && ./run.sh start
```
Creates the shared `nginx-proxy_net` Docker network and starts the proxy on port 80.

### After starting an app instance
After `worktree-manager start <name>`, connect the proxy so routes become available:
```bash
./run.sh connect <name>
```
Routes: `http://<name>.frontend.localhost` and `http://<name>.backend.localhost`

### After restarting Docker or the host
Proxy reconnects automatically via `restart: unless-stopped`. If routes are missing, run:
```bash
./run.sh auto-connect
```

### Check active routes
```bash
./run.sh status
```

## Startup Order

1. `proxy-manager start` — creates network, starts proxy
2. `mysql-manager start` — joins the shared network
3. `worktree-manager start <instance>` — starts app containers
4. `proxy-manager connect <instance>` — activates routing

## Configuration

| Variable         | Default             | Purpose                          |
|------------------|---------------------|----------------------------------|
| `PROXY_CONTAINER`| `codai_nginx_proxy` | nginx-proxy container name       |
| `CODAI_NETWORK`  | `nginx-proxy_net`   | Shared Docker network name       |
| `PROJECT_PREFIX` | `codai-dev`         | Docker Compose project prefix    |

## How VIRTUAL_HOST Routing Works

1. App containers declare `VIRTUAL_HOST=<name>.frontend.localhost` as a label
2. `jwilder/nginx-proxy` reads Docker socket events and generates nginx config
3. Proxy container must share at least one Docker network with the app container
4. `./run.sh connect <instance>` connects proxy to the instance's network

## Rules

- Start proxy-manager **before** mysql-manager and worktree-manager.
- After `worktree-manager start <name>`, always run `proxy-manager connect <name>` to activate routes.
- `stop` does NOT remove the Docker network. Other containers on the network remain reachable.

## Related Plugins

- `mysql-manager` — shared MySQL container (start after proxy-manager)
- `worktree-manager` — app instances and git worktrees (start after both)
