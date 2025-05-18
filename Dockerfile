FROM ruby:3.4.4-alpine AS builder
USER root

RUN apk add --no-cache \
    build-base \
    ruby-dev \
    libffi-dev \
    yaml-dev

WORKDIR /build

COPY Gemfile Gemfile.lock ./
COPY *.gemspec ./

RUN gem update --system && \
    bundle config set jobs $(nproc) && \
    bundle install --jobs=$(nproc) --retry=3 --without development test

COPY . .

FROM ruby:3.4.3-alpine
USER root

RUN apk add --no-cache \
    libffi \
    yaml

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /build /app

WORKDIR /
ENTRYPOINT [ "/app/bin/wayback_machine_downloader" ]