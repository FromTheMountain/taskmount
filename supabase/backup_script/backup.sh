#!/bin/bash

DB_HOST="aws-1-eu-west-1.pooler.supabase.com"
DB_PORT="6543"
DB_NAME="postgres"
DB_USER="postgres.uzpjlgqxviloapddvqji"
DB_SCHEMA="public"
DEST_FILE="$HOME/Documents/Taskmount/db_backup_$(date +%Y%m%d%H%M%S).sql"

# Password comes from .pgpass file
pg_dump -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USER --schema $DB_SCHEMA > "$DEST_FILE"

if [ $? -eq 0 ]; then
  echo "Backup successful: $DEST_FILE"
else
  echo "Backup failed" >&2
fi
