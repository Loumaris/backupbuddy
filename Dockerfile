FROM alpine:3.16

WORKDIR /backup

VOLUME /backup/data

VOLUME /backup/config

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
            curl \
            openssh \
            postgresql-client \
            pigz \
            ssmtp && \
    rm -rf /var/cache/apk/*

ADD bin/run.sh /backup/run.sh

RUN chmod a+x /backup/run.sh

CMD ["/backup/run.sh"]