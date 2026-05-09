# codai-plugins

Repositório de plugins/skills para Claude Code e OpenCode (compatíveis com ambos).

## Estrutura

Cada plugin é um diretório raiz com:

```
<plugin-slug>/
├── SKILL.md            # skill document (frontmatter Claude Code + OpenCode)
├── _meta.json          # metadados OpenCode (slug, version, ownerId, publishedAt)
├── run.sh              # script executável (quando o plugin usa bash)
└── docker-compose.yml  # quando o plugin gerencia um serviço Docker
```

## Plugins disponíveis

| Plugin | Descrição |
|--------|-----------|
| `codai` | Orquestrador — roteia comandos para os outros plugins |
| `proxy-manager` | nginx-proxy + rede Docker compartilhada |
| `mysql-manager` | MySQL 8.0 compartilhado entre instâncias |
| `postgres-manager` | PostgreSQL 16 compartilhado entre instâncias |
| `redis-manager` | Redis 7 compartilhado entre instâncias |
| `worktree-manager` | Instâncias Docker + git worktrees da app |

## Usar um plugin no seu projeto

### Claude Code
Copie o `SKILL.md` para `.claude/skills/<slug>/SKILL.md` no projeto.

### OpenCode / clawhub — instalar do registry
```bash
clawhub install <slug>
```

## Publicar no registry (clawhub sync)

O `clawhub sync` **não escaneia o diretório atual** por padrão — use a flag `--root`:

```bash
# dry-run (ver o que seria publicado)
npx clawhub sync --root ~/path/to/codai-plugins --dry-run

# publicar de fato
npx clawhub sync --root ~/path/to/codai-plugins
```

> **Não use** `clawhub publish <path>` (alias legacy) — ele exige `--version` explícito
> e não lê o frontmatter do SKILL.md. Use sempre `clawhub sync --root`.

## Publicar atualização

1. Atualize `version` no frontmatter do `SKILL.md` (ex: `1.0.0` → `1.1.0`)
2. Atualize `changelog` no frontmatter do `SKILL.md`
3. Atualize `publishedAt` em `_meta.json` (timestamp Unix em ms)
4. Commit + push
5. `npx clawhub sync --root ~/path/to/codai-plugins`

## Regras

- `run.sh` deve ser configurável via variáveis de ambiente com defaults sensatos.
- `docker-compose.yml` usa variáveis de ambiente — nunca valores hardcoded para produção.
- Nunca commitar `.env*`, credenciais, ou `node_modules/`.
- SKILL.md usa frontmatter compatível com ambos os runtimes.
