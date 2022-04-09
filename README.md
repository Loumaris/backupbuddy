# postgresql backup buddy

[![Build and Publish docker](https://github.com/Loumaris/backupbuddy/actions/workflows/docker.yml/badge.svg)](https://github.com/Loumaris/backupbuddy/actions/workflows/docker.yml)
[![Docker](https://badgen.net/badge/icon/docker?icon=docker&label)]([https://https://docker.com/](https://hub.docker.com/repository/docker/loumaris/backupbuddy))


a small docker image which will run a `pg_dump` via ssh tunnel.

## setup

* clone this repository: `git clone https://github.com/Loumaris/backupbuddy.git`
* place your (passwordless) private key into `config/id_rsa`
  * Hint: create a separate public/private key pair for each backup instance
* copy the `config/config.env.example` to `config/config.env`
* update the settings in `config/config.env`
  * only the `TEAMS_WEBHOOK_URL` is optional
* test the backup via:
  ```
  docker run -v ${PWD}/config:/backup/config -v ${PWD}/data:/backup/data loumaris/backupbuddy
  ```
* add the docker command to your cron daemon