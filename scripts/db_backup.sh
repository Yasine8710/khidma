#!/bin/sh
# Logical backup and restore drill for the Khidma database (#56).
# The Supabase Free plan has no automatic backups, so run `backup` regularly
# and keep the files off-site. Files (Storage buckets) are not included.
#
#   SUPABASE_DB_URL=postgresql://postgres.<ref>:<password>@<pooler-host>:5432/postgres \
#     scripts/db_backup.sh backup            # writes backups/<stamp>/{roles,schema,data}.sql
#   RESTORE_DB_URL=<scratch project, session pooler> \
#     scripts/db_backup.sh restore backups/<stamp>   # restores and prints the time taken
#
# Needs the Supabase CLI and psql. Never point RESTORE_DB_URL at production.
set -eu

cmd="${1:-}"
case "$cmd" in
  backup)
    : "${SUPABASE_DB_URL:?set SUPABASE_DB_URL (session pooler, port 5432)}"
    dir="${BACKUP_DIR:-backups}/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$dir"
    start=$(date +%s)
    supabase db dump --db-url "$SUPABASE_DB_URL" -f "$dir/roles.sql" --role-only
    supabase db dump --db-url "$SUPABASE_DB_URL" -f "$dir/schema.sql"
    supabase db dump --db-url "$SUPABASE_DB_URL" -f "$dir/data.sql" --use-copy --data-only
    echo "backup: $dir ($(( $(date +%s) - start )) s)"
    ;;
  restore)
    : "${RESTORE_DB_URL:?set RESTORE_DB_URL (a scratch project)}"
    dir="${2:?usage: db_backup.sh restore <backup dir>}"
    start=$(date +%s)
    psql --single-transaction --variable ON_ERROR_STOP=1 \
      --file "$dir/roles.sql" --file "$dir/schema.sql" \
      --command 'SET session_replication_role = replica' \
      --file "$dir/data.sql" --dbname "$RESTORE_DB_URL"
    echo "restore: done in $(( $(date +%s) - start )) s"
    ;;
  *)
    echo "usage: db_backup.sh backup | restore <backup dir>" >&2
    exit 2
    ;;
esac
