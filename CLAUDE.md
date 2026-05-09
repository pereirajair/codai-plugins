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

| Plugin | Descrição | Ordem de start |
|--------|-----------|----------------|
| `proxy-manager` | nginx-proxy + rede Docker compartilhada | 1º |
| `mysql-manager` | MySQL 8.0 compartilhado entre instâncias | 2º |
| `worktree-manager` | Instâncias Docker + git worktrees da app | 3º |

## Startup completo do ambiente

```bash
proxy-manager/run.sh start       # cria rede + sobe nginx-proxy
mysql-manager/run.sh start       # sobe MySQL (entra na rede criada pelo proxy)
worktree-manager/run.sh start    # sobe instância main da app
```

## Usar um plugin no seu projeto

### Claude Code
Copie o `SKILL.md` para `.claude/skills/<slug>/SKILL.md` no projeto.

### OpenCode / clawhub
```bash
clawhub install <slug>
```

## Publicar atualização

1. Atualize `version` em `_meta.json` e no frontmatter do `SKILL.md`
2. Atualize `changelog` no frontmatter do `SKILL.md`
3. Atualize `publishedAt` em `_meta.json` (timestamp Unix em ms)
4. Commit + push

## Regras

- `run.sh` deve ser configurável via variáveis de ambiente com defaults sensatos.
- `docker-compose.yml` usa variáveis de ambiente — nunca valores hardcoded para produção.
- Nunca commitar `.env*`, credenciais, ou `node_modules/`.
- SKILL.md usa frontmatter compatível com ambos os runtimes.
