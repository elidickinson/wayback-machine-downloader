FROM ruby:2.3-alpine
USER root
WORKDIR /build
COPY . /build

WORKDIR /
ENTRYPOINT [ "/build/bin/wayback_machine_downloader" ]