FROM alpine:3.21.0

RUN apk add zola=0.19.2-r0

WORKDIR /srv
