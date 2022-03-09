FROM alpine:3.14

WORKDIR /backup

VOLUME /backup/data

VOLUME /backup/config

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
            curl \
            openssh \
            postgresql-client && \
    rm -rf /var/cache/apk/*

ADD bin/backup.sh /backup/run.sh

RUN chmod a+x /backup/run.sh

CMD ["/backup/run.sh"]