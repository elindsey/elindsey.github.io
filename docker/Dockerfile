FROM ruby:2-slim

LABEL repository="https://github.com/elindsey/jekyll-publish-action"

COPY Gemfile Gemfile.lock entrypoint.sh /

RUN gem install bundler && \
    apt-get update && \
    apt-get install -y \
        build-essential \
        git && \
    bundle install && \
    # clean up the intermediate object files from native extensions
    # their fully linked .so should already be in the gem's lib
    find /usr/local/bundle/gems -name 'Makefile' -printf "%h\0" | xargs -0 -I % make -C % clean && \
    apt-get autoremove -y build-essential

ENTRYPOINT ["/entrypoint.sh"]
