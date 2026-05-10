# codai-plugins

Skills/plugins para gerenciar o ambiente de desenvolvimento local com Docker. Compatíveis com Claude Code, OpenCode e OpenClaw.

## Plugins disponíveis

| Plugin | Descrição | Porta |
|--------|-----------|-------|
| `proxy-manager` | nginx-proxy + rede Docker compartilhada | 80 |
| `mysql-manager` | MySQL 8.0 compartilhado | 3307 |
| `postgres-manager` | PostgreSQL 16 compartilhado | 5433 |
| `redis-manager` | Redis 7 compartilhado | 6380 |
| `phpmyadmin-manager` | Web UI para MySQL (phpMyAdmin) | 8081 |
| `pgadmin-manager` | Web UI para PostgreSQL (pgAdmin 4) | 8082 |
| `redis-commander` | Web UI para Redis (Redis Commander) | 8083 |
| `worktree-manager` | Instâncias Docker + git worktrees | — |
| `codai` | Orquestrador — roteia comandos para os outros plugins | — |

## Ordem de inicialização

```bash
# Infraestrutura (sempre primeiro)
proxy-manager start       # cria a rede Docker compartilhada
mysql-manager start       # MySQL (opcional: postgres-manager, redis-manager)

# App
worktree-manager start main

# Web UIs (opcional, após o banco correspondente)
phpmyadmin-manager start  # http://localhost:8081
pgadmin-manager start     # http://localhost:8082
redis-commander start     # http://localhost:8083
```

## Instalar no Claude Code

### Como plugin completo (com hooks — recomendado)

```bash
claude plugin marketplace add pereirajair/codai-plugins
claude plugin install codai-plugins
```

Instala todas as skills e ativa o hook que injeta os caminhos absolutos dos scripts em toda sessão.

### Via clawhub (skill avulsa)

```bash
npx clawhub install <slug>
# exemplo:
npx clawhub install mysql-manager
```

### Manualmente

Copie o `SKILL.md` do plugin para `.claude/skills/<slug>/SKILL.md` no seu projeto (ou em `~/.claude/skills/<slug>/SKILL.md` para uso global).

## Como os caminhos dos scripts funcionam

Cada plugin tem um `run.sh` que gerencia o container Docker. Quando instalado via clawhub ou manualmente em `~/.claude/skills/`, o Claude Code injeta um hook `SessionStart` que informa o caminho absoluto de cada script na sessão. Isso permite usar os plugins a partir de qualquer projeto sem precisar copiar arquivos.

## Publicar no registry (clawhub sync)

```bash
# dry-run
npx clawhub sync --root ~/path/to/codai-plugins/skills --dry-run

# publicar
npx clawhub sync --root ~/path/to/codai-plugins/skills
```

### Publicar uma atualização

1. Atualize `version` no frontmatter do `SKILL.md`
2. Atualize `changelog` no frontmatter do `SKILL.md`
3. Atualize `publishedAt` em `_meta.json`
4. Commit + push
5. `npx clawhub sync --root ~/path/to/codai-plugins`

## Estrutura de cada plugin

```
<plugin-slug>/
├── SKILL.md            # skill document (frontmatter + documentação)
├── _meta.json          # metadados OpenCode/clawhub
├── run.sh              # script executável (lifecycle do container)
└── docker-compose.yml  # definição do serviço Docker
```

## Variáveis de ambiente compartilhadas

| Variável | Default | Usado por |
|----------|---------|-----------|
| `CODAI_NETWORK` | `nginx-proxy_net` | todos os plugins |
| `MYSQL_CONTAINER` | `codai_db` | mysql-manager, worktree-manager, phpmyadmin-manager |
| `MYSQL_ROOT_PASSWORD` | `secret` | mysql-manager, phpmyadmin-manager |
| `POSTGRES_CONTAINER` | `codai_postgres` | postgres-manager, pgadmin-manager |
| `REDIS_CONTAINER` | `codai_redis` | redis-manager, redis-commander |
| `REDIS_PASSWORD` | `redispass` | redis-manager, redis-commander |
| `PROXY_CONTAINER` | `codai_nginx_proxy` | proxy-manager, worktree-manager |

## Licença

MIT — veja [LICENSE](LICENSE).
