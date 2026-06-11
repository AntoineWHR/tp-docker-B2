FROM nginx:1.27-alpine

RUN apk add --no-cache bash curl postgresql-client

COPY check_db.sh /usr/local/bin/check_db.sh
RUN chmod +x /usr/local/bin/check_db.sh
