#!/bin/bash
# Worktree Manager — codai-plugins
#
# Gerencia instâncias docker-compose + git worktrees com MySQL compartilhado.
# Cada instância tem seu próprio banco dentro do mesmo MySQL container.
# Ao iniciar um worktree, o banco é criado e populado com dump da instância main.
#
# Uso:
#   ./run.sh list                        # lista instâncias e status
#   ./run.sh start [main|<nome>]         # cria banco, dumpa main→instância, sobe containers
#   ./run.sh stop  [main|<nome>]         # para containers (banco persiste)
#   ./run.sh logs  [main|<nome>]         # segue logs
#   ./run.sh restart [main|<nome>]       # para e sobe novamente
#   ./run.sh create-worktree <nome>      # cria worktree git + branch + env file
#   ./run.sh remove-worktree <nome>      # para containers + remove worktree + apaga banco
#
# Variáveis de configuração (com defaults):
#   CODAI_MYSQL_CONTAINER  — nome do container MySQL compartilhado (padrão: codai_db)
#   CODAI_MYSQL_ROOT_PASS  — senha root do MySQL (padrão: secret)
#   CODAI_MAIN_DB          — banco fonte para snapshot ao criar worktree (padrão: codai_main)

set -euo pipefail

ACTION="${1:-list}"
INSTANCE="${2:-}"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"

MYSQL_CONTAINER="${CODAI_MYSQL_CONTAINER:-codai_db}"
MYSQL_ROOT_PASS="${CODAI_MYSQL_ROOT_PASS:-secret}"
MAIN_DB="${CODAI_MAIN_DB:-codai_main}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

env_file() {
    local name="$1"
    if [ "$name" = "main" ]; then
        echo "$BASE_DIR/.env.base"
    else
        echo "$BASE_DIR/.env.worktree-$name"
    fi
}

require_instance() {
    if [ -z "$INSTANCE" ]; then
        echo "Erro: informe o nome da instância. Ex: $0 $ACTION <nome>"
        exit 1
    fi
}

db_name_for() {
    local name="$1"
    local env_f
    env_f="$(env_file "$name")"
    local db_name
    db_name=$(grep '^DB_NAME=' "$env_f" 2>/dev/null | cut -d= -f2 || true)
    if [ -z "$db_name" ]; then
        local safe
        safe=$(echo "$name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
        db_name="${MAIN_DB%%_*}_$safe"
    fi
    echo "$db_name"
}

require_mysql() {
    if ! docker ps --filter "name=^${MYSQL_CONTAINER}$" --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
        echo "MySQL (${MYSQL_CONTAINER}) não está rodando."
        echo "Iniciando infraestrutura..."
        docker compose -f "$BASE_DIR/nginx-proxy/docker-compose.yml" up -d
        echo "Aguardando MySQL ficar pronto..."
        until docker exec "$MYSQL_CONTAINER" mysqladmin ping -uroot -p"$MYSQL_ROOT_PASS" --silent 2>/dev/null; do
            sleep 2
        done
        echo "MySQL pronto."
    fi
}

ensure_db() {
    local db="$1"
    docker exec "$MYSQL_CONTAINER" mysql -uroot -p"$MYSQL_ROOT_PASS" \
        -e "CREATE DATABASE IF NOT EXISTS \`$db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
        2>/dev/null
}

dump_main_to() {
    local dest_db="$1"
    local table_count
    table_count=$(docker exec "$MYSQL_CONTAINER" mysql -uroot -p"$MYSQL_ROOT_PASS" -sN \
        -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MAIN_DB';" 2>/dev/null || echo 0)
    if [ "$table_count" -gt 0 ]; then
        echo "Copiando $MAIN_DB → $dest_db..."
        docker exec "$MYSQL_CONTAINER" sh -c \
            "mysqldump -uroot -p'$MYSQL_ROOT_PASS' \`$MAIN_DB\` | mysql -uroot -p'$MYSQL_ROOT_PASS' \`$dest_db\`"
        echo "Banco $dest_db atualizado com snapshot de $MAIN_DB."
    else
        echo "$MAIN_DB está vazio — $dest_db iniciará com banco limpo (migrações serão aplicadas pelo backend)."
    fi
}

compose_up() {
    local name="$1"
    local env_f
    env_f="$(env_file "$name")"
    docker compose \
        --project-name "codai-dev-$name" \
        -f "$COMPOSE_FILE" \
        --env-file "$env_f" \
        up --build -d
}

compose_down() {
    local name="$1"
    local env_f
    env_f="$(env_file "$name")"
    docker compose \
        --project-name "codai-dev-$name" \
        -f "$COMPOSE_FILE" \
        --env-file "$env_f" \
        down 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Comandos
# ---------------------------------------------------------------------------

case "$ACTION" in

    list)
        echo "=== Instâncias ==="
        echo ""
        if docker ps --filter "name=^${MYSQL_CONTAINER}$" --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
            echo "  MySQL (${MYSQL_CONTAINER})  running  → localhost"
        else
            echo "  MySQL (${MYSQL_CONTAINER})  stopped  (inicie: cd nginx-proxy && docker compose up -d)"
        fi
        echo ""
        shopt -s nullglob
        for env_f in "$BASE_DIR/.env.base" "$BASE_DIR"/.env.worktree-*; do
            [ -f "$env_f" ] || continue
            if [ "$env_f" = "$BASE_DIR/.env.base" ]; then
                name="main"
            else
                name="${env_f##*/.env.worktree-}"
            fi
            project="codai-dev-$name"
            db=$(db_name_for "$name")
            running=$(docker compose --project-name "$project" -f "$COMPOSE_FILE" --env-file "$env_f" ps --status running -q 2>/dev/null | wc -l | tr -d ' ')
            if [ "$running" -gt 0 ]; then
                status="running ($running containers)"
            else
                status="stopped"
            fi
            if [ "$name" = "main" ]; then
                extra="db: $db  (instância principal)"
            elif [ -d "$BASE_DIR/.worktrees/$name" ]; then
                branch=$(git -C "$BASE_DIR/.worktrees/$name" branch --show-current 2>/dev/null || echo "?")
                extra="db: $db  branch: $branch"
            else
                extra="db: $db  worktree ausente"
            fi
            printf "  %-12s %s  %s\n" "$name" "$status" "$extra"
        done
        echo ""
        echo "Comandos:"
        echo "  ./run.sh create-worktree <nome>   cria worktree"
        echo "  ./run.sh start <nome>              inicia"
        echo "  ./run.sh stop  <nome>              para containers"
        echo "  ./run.sh remove-worktree <nome>    remove tudo"
        ;;

    start)
        INSTANCE="${INSTANCE:-main}"
        ENV_FILE="$(env_file "$INSTANCE")"
        if [ ! -f "$ENV_FILE" ]; then
            echo "Erro: $ENV_FILE não encontrado."
            [ "$INSTANCE" != "main" ] && echo "      Use './run.sh create-worktree $INSTANCE' primeiro."
            exit 1
        fi
        DB="$(db_name_for "$INSTANCE")"

        require_mysql
        ensure_db "$DB"

        if [ "$INSTANCE" != "main" ]; then
            dump_main_to "$DB"
        fi

        echo "Subindo containers da instância '$INSTANCE'..."
        compose_up "$INSTANCE"
        echo ""
        echo "Instância '$INSTANCE' iniciada!"
        echo "  → http://${INSTANCE}.frontend.localhost"
        echo "  → http://${INSTANCE}.backend.localhost"
        echo "  DB: $DB (compartilhado em ${MYSQL_CONTAINER})"
        ;;

    stop)
        INSTANCE="${INSTANCE:-main}"
        echo "Parando containers da instância '$INSTANCE' (banco persiste)..."
        compose_down "$INSTANCE"
        echo "Instância '$INSTANCE' parada."
        ;;

    logs)
        INSTANCE="${INSTANCE:-main}"
        ENV_FILE="$(env_file "$INSTANCE")"
        docker compose \
            --project-name "codai-dev-$INSTANCE" \
            -f "$COMPOSE_FILE" \
            --env-file "$ENV_FILE" \
            logs -f
        ;;

    restart)
        INSTANCE="${INSTANCE:-main}"
        "$0" stop "$INSTANCE"
        sleep 2
        "$0" start "$INSTANCE"
        ;;

    create-worktree)
        require_instance
        NAME="$INSTANCE"
        if [ "$NAME" = "main" ]; then
            echo "Erro: 'main' é a instância principal e não pode ser um worktree."
            exit 1
        fi
        WORKTREE_PATH="$BASE_DIR/.worktrees/$NAME"
        ENV_FILE="$(env_file "$NAME")"
        SAFE=$(echo "$NAME" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
        DB="${MAIN_DB%%_*}_$SAFE"

        if [ -f "$ENV_FILE" ]; then
            echo "$ENV_FILE já existe — pulando criação."
        else
            printf 'INSTANCE_NAME=%s\nDB_NAME=%s\n' "$NAME" "$DB" > "$ENV_FILE"
            echo "Env criado: $ENV_FILE  (banco: $DB)"
        fi

        if [ -d "$WORKTREE_PATH" ]; then
            echo "Worktree já existe em $WORKTREE_PATH — pulando."
        else
            mkdir -p "$BASE_DIR/.worktrees"
            BRANCH="worktree/$NAME"
            if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
                git worktree add "$WORKTREE_PATH" "$BRANCH"
            else
                git worktree add -b "$BRANCH" "$WORKTREE_PATH"
            fi
            echo "Worktree criado: $WORKTREE_PATH  (branch: $BRANCH)"
        fi

        echo ""
        echo "Para iniciar:  ./run.sh start $NAME"
        echo "URLs:          http://${NAME}.frontend.localhost"
        echo "               http://${NAME}.backend.localhost"
        ;;

    remove-worktree)
        require_instance
        NAME="$INSTANCE"
        if [ "$NAME" = "main" ]; then
            echo "Erro: não é possível remover a instância 'main'."
            exit 1
        fi
        WORKTREE_PATH="$BASE_DIR/.worktrees/$NAME"
        ENV_FILE="$(env_file "$NAME")"
        DB="$(db_name_for "$NAME")"

        echo "Parando containers da instância '$NAME'..."
        compose_down "$NAME"

        if docker ps --filter "name=^${MYSQL_CONTAINER}$" --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
            docker exec "$MYSQL_CONTAINER" mysql -uroot -p"$MYSQL_ROOT_PASS" \
                -e "DROP DATABASE IF EXISTS \`$DB\`;" 2>/dev/null && \
                echo "Banco $DB removido."
        fi

        if [ -d "$WORKTREE_PATH" ]; then
            git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || rm -rf "$WORKTREE_PATH"
            git worktree prune
            echo "Worktree removido: $WORKTREE_PATH"
        else
            echo "Worktree não encontrado: $WORKTREE_PATH"
        fi

        if [ -f "$ENV_FILE" ]; then
            rm "$ENV_FILE"
            echo "Env removido: $ENV_FILE"
        fi

        echo "Worktree '$NAME' removido."
        ;;

    *)
        echo "Uso: $0 {list|start|stop|logs|restart|create-worktree|remove-worktree} [instância]"
        exit 1
        ;;
esac
