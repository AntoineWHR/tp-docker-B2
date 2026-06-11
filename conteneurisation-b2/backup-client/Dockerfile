FROM alpine:3.20

RUN apk add --no-cache bash coreutils curl openssh-client postgresql-client restic tzdata

COPY backup_all.sh /usr/local/bin/backup_all.sh
COPY restore_latest.sh /usr/local/bin/restore_latest.sh
COPY crontab /etc/crontabs/root
RUN chmod +x /usr/local/bin/backup_all.sh /usr/local/bin/restore_latest.sh

CMD ["crond", "-f", "-l", "2"]
