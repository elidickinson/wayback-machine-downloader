FROM ruby:3.1.6-alpine
USER root
WORKDIR /build
COPY . /build

WORKDIR /
ENTRYPOINT [ "/build/bin/wayback_machine_downloader" ]