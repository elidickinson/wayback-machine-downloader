FROM ruby:3.4.4-alpine
USER root
WORKDIR /build

COPY Gemfile /build/
COPY *.gemspec /build/

RUN bundle config set jobs $(nproc) \
    && bundle install --without development test

COPY . /build

WORKDIR /
ENTRYPOINT [ "/build/bin/wayback_machine_downloader" ]
