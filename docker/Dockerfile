FROM ruby:2-slim

LABEL repository="https://github.com/elindsey/jekyll-publish-action"

COPY Gemfile entrypoint.sh /

RUN gem install bundler && \
    apt-get update && \
    apt-get install -y \
        build-essential \
        git && \
    bundle install

ENTRYPOINT ["/entrypoint.sh"]
