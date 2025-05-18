FROM ruby:3.4.3-alpine
USER root
WORKDIR /build

COPY Gemfile /build/
COPY *.gemspec /build/

RUN gem update \
    && bundle config set jobs $(nproc) \
    && bundle install

COPY . /build

WORKDIR /
ENTRYPOINT [ "/build/bin/wayback_machine_downloader" ]