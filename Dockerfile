FROM alpine:latest

RUN apk add --no-cache \
    gleam \
    rebar3

WORKDIR /app
COPY . .

ENTRYPOINT sh
