#!/bin/sh
set -e

echo "source env settings..."
source /backup/config/config.env

FILE=`date +"%Y-%m-%d-%H_%M"`

OUTPUT_FILE=${BACKUP_DIR}/${FILE}_${DB_NAME}
OUTPUT_TAR_FILE=${BACKUP_DIR}/${FILE}_data.tar.gz
PARALLEL_DUMP_JOBS="${PG_PARALLEL_DUMP_JOBS:=2}"  # If variable not set or null, set it to default.

if [ -n "$SSH_HOST" ]; then
echo "create ssh tunnel..."
  chmod 600 /backup/config/id_rsa
  ssh -4 \
      -i /backup/config/id_rsa \
      -o LogLevel=ERROR \
      -o StrictHostKeyChecking=no \
      -o ExitOnForwardFailure=yes \
      -f \
      -L 2342:localhost:${DB_PORT} ${SSH_USERNAME}@${SSH_HOST} -p ${SSH_PORT} sleep 10

  echo "dump database ${DB_NAME}..."
  PGPASSWORD=${DB_PASSWORD} pg_dump -Z0 -j ${PARALLEL_DUMP_JOBS} -Fd -c -h localhost --port 2342 -U ${DB_USER} ${DB_NAME} ${PG_OPTIONS} -O -x -f ${OUTPUT_FILE}
else
  echo "dump database ${DB_NAME}..."
  PGPASSWORD=${DB_PASSWORD} pg_dump -Z0 -j ${PARALLEL_DUMP_JOBS} -Fd -c -h ${DB_HOST} --port ${DB_PORT} -U ${DB_USER} ${DB_NAME} ${PG_OPTIONS} -O -x -f ${OUTPUT_FILE}
fi

tar -cf - ${OUTPUT_FILE} | pigz > ${OUTPUT_FILE}.tar.gz
rm -rf ${OUTPUT_FILE}

RESULT_PG_DUMP=$?
RESULT_BACKUP_DIR=0

if [ -n "$BACKUP_REMOTE_DIRECTORY" ]; then
  echo "backup directory ${BACKUP_REMOTE_DIRECTORY}..."
  ssh  -i /backup/config/id_rsa ${SSH_USERNAME}@${SSH_HOST} -p ${SSH_PORT} tar czf - ${BACKUP_REMOTE_DIRECTORY} > ${OUTPUT_TAR_FILE}
  RESULT_BACKUP_DIR=$?
fi

echo "clean up..."
find $BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*${FILE_SUFFIX}.gz" -exec rm -rf '{}' ';'

if [ -n "$TEAMS_WEBHOOK_URL" ]; then
  echo "ping MS Teams..."
  curl -s -H 'Content-Type: application/json' -d "{'text': 'Backup done for **$DB_NAME** on **$FILE**'}" $TEAMS_WEBHOOK_URL > /dev/null
fi

if [ -n "$DISCORD_WEBHOOK_URL" ]; then
  echo "ping discord..."
  if [ $RESULT_PG_DUMP -gt 0 ]
  then
    curl $DISCORD_WEBHOOK_URL -H "Content-Type: application/json" --data @<(cat <<EOF
{
      "embeds": [{
        "author": {
          "name": "Backup Buddy for ${DB_USER}",
          "icon_url": "https://i.imgur.com/V8ZjaMa.jpg"
        },
        "title": "${DB_NAME}",
        "description": ":red_circle: ERROR - backup database"
      }]
    }
EOF
) > /dev/null
  else
     curl $DISCORD_WEBHOOK_URL -H "Content-Type: application/json" --data @<(cat <<EOF
{
      "embeds": [{
        "author": {
          "name": "Backup Buddy for ${DB_USER}",
          "icon_url": "https://i.imgur.com/V8ZjaMa.jpg"
        },
        "title": "${DB_NAME}",
        "description": ":green_heart: SUCCESS - backup database"
      }]
    }
EOF
) > /dev/null
  fi

fi

if [ -n "$UPTIME_ROBOT_URL" ]; then
  echo "ping uptime robot..."
  curl -s -H 'Content-Type: application/json' $UPTIME_ROBOT_URL > /dev/null
fi


if [ -n "$SEND_NOTIFICATION_EMAIL" ]; then

  if [ $RESULT_PG_DUMP -gt 0 ]
  then
    MAIL_SUBJECT_PG_DUMP="ERROR - backup database ${DB_NAME}"
  else
    MAIL_SUBJECT_PG_DUMP="SUCCESS - backup database ${DB_NAME}"
  fi

  if [ $RESULT_BACKUP_DIR -gt 0 ]
  then
    MAIL_SUBJECT_BACKUP_DIR="ERROR - backup directory ${BACKUP_REMOTE_DIRECTORY}"
  else
    MAIL_SUBJECT_BACKUP_DIR="SUCCESS - backup directory ${BACKUP_REMOTE_DIRECTORY}"
  fi

  mail \
          -a "From: ${MAIL_SENDER_INFO}"  \
          -s "$MAIL_SUBJECT_PG_DUMP" \
          "${MAIL_RECEIVER}" < $MAIL_SUBJECT_PG_DUMP

  mail \
          -a "From: ${MAIL_SENDER_INFO}"  \
          -s "$MAIL_SUBJECT_PG_DUMP" \
          "${MAIL_RECEIVER}" < $MAIL_SUBJECT_BACKUP_DIR

fi