# codai-plugins

Repositório de plugins/skills para Claude Code e OpenCode (compatíveis com ambos).

## Estrutura

Cada plugin é um diretório raiz com:

```
<plugin-slug>/
├── SKILL.md       # skill document (frontmatter compatível com Claude Code + OpenCode)
├── _meta.json     # metadados OpenCode (slug, version, ownerId, publishedAt)
└── run.sh         # script executável (quando o plugin usa bash)
```

## Plugins disponíveis

| Plugin | Descrição |
|--------|-----------|
| `worktree-manager` | Gerencia instâncias Docker + git worktrees via run.sh |

## Usar um plugin no seu projeto

### Claude Code
Copie o `SKILL.md` para `.claude/skills/<slug>/SKILL.md` no projeto alvo.

### OpenCode / clawhub
```bash
clawhub install <slug>
```

## Publicar atualização

Após editar um plugin:
1. Atualize `version` em `_meta.json` e no frontmatter do `SKILL.md`
2. Atualize `changelog` no frontmatter do `SKILL.md`
3. Atualize `publishedAt` em `_meta.json` com o timestamp Unix em ms
4. Commit + push para o GitHub

## Regras

- `run.sh` deve ser genérico e configurável via variáveis de ambiente com defaults sensatos.
- Nunca commitar `.env*`, credenciais, ou `node_modules/`.
- SKILL.md deve ter frontmatter compatível com ambos os runtimes (triggers para Claude Code, metadata para OpenCode).
