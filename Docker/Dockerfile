FROM iron/ruby
RUN apk update && apk upgrade \
    && apk add build-base ruby-rdoc ruby-irb ruby-dev libffi-dev zlib-dev libxml2-dev libxslt nodejs \
    && rm -rf /var/cache/apk/* 
RUN gem install bundler
ADD Gemfile* /tmp/
WORKDIR /tmp
RUN bundle install

VOLUME ["/blog"]
WORKDIR /blog

EXPOSE 4000

