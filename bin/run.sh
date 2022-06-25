#!/bin/sh
set -e

source /backup/config/config.env

chmod 600 /backup/config/id_rsa

FILE=`date +"%Y-%m-%d-%H_%M"`

OUTPUT_FILE=${BACKUP_DIR}/${FILE}_${DB_NAME}.psql

ssh -4 \
    -i /backup/config/id_rsa \
    -o LogLevel=ERROR \
    -o StrictHostKeyChecking=no \
    -o ExitOnForwardFailure=yes \
    -f \
    -L 2342:localhost:${DB_PORT} ${SSH_USERNAME}@${SSH_HOST} -p ${SSH_PORT} sleep 10

PGPASSWORD=${DB_PASSWORD} pg_dump -c -h localhost --port 2342 -U ${DB_USER} ${DB_NAME} ${PG_OPTIONS} -O -x -f ${OUTPUT_FILE}

gzip -8 $OUTPUT_FILE

find $BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*${FILE_SUFFIX}.gz" -exec rm -rf '{}' ';'

if [ -n "$TEAMS_WEBHOOK_URL" ]; then
  curl -s -H 'Content-Type: application/json' -d "{'text': 'Backup done for **$DB_NAME** on **$FILE**'}" $TEAMS_WEBHOOK_URL > /dev/null
fi

if [ -n "$UPTIME_ROBOT_URL" ]; then
  curl -s -H 'Content-Type: application/json' $UPTIME_ROBOT_URL > /dev/null
fi
