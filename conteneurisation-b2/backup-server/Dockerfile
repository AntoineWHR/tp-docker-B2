FROM alpine:3.20

RUN apk add --no-cache bash openssh-server restic shadow

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
