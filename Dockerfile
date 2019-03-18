FROM ruby:2.6.1 as builder

RUN apt-get update -qq && apt-get install -y postgresql-client libgmp10-dev libgmp10 sash busybox dnsutils && \
    apt-get remove -y git &&  \
    apt-get install -y git && \
    mkdir -p /app/highway && \
    mkdir -p /gems/highway && cd /gems/highway && \
    git config --global http.sslVerify "false" && \
    git clone --single-branch --branch cms-added https://github.com/CIRALabs/ruby-openssl.git && \
    git clone --single-branch --branch binary_http_multipart https://github.com/AnimaGUS-minerva/multipart_body.git && \
    git clone --single-branch --branch ecdsa_interface_openssl https://github.com/AnimaGUS-minerva/ruby_ecdsa.git && \
    git clone --single-branch --branch v0.6.0 https://github.com/mcr/ChariWTs.git

# build custom openssl with ruby-openssl patches

# remove directory with broken opensslconf.h,
# build in /src, as we do not need openssl once installed
RUN rm -rf /usr/include/x86_64-linux-gnu/openssl && \
    mkdir -p /src/highway && \
    cd /src/highway && \ 
    git clone -b dtls-listen-refactor-1.1.1b git://github.com/mcr/openssl.git && \
    cd /src/highway/openssl && \
    ./Configure --prefix=/usr --openssldir=/usr/lib/ssl --libdir=lib/linux-x86_64 no-idea no-mdc2 no-rc5 no-zlib no-ssl3 enable-unit-test linux-x86_64 && \
    id && make && \
    cd /src/highway/openssl && make install_sw && \
    gem install rake-compiler --source=http://rubygems.org && \
    cd /gems/highway/ruby-openssl && rake compile

WORKDIR /app/highway
RUN gem install bundler --source=http://rubygems.org

# install gems with extensions explicitely so that layers are cached.
RUN gem install -v1.10.1 nokogiri --source=http://rubygems.org && \
    gem install -v1.2.7 eventmachine --source=http://rubygems.org && \
    gem install -v2.3.1 nio4r --source=http://rubygems.org && \
    gem install -v3.1.12 bcrypt --source=http://rubygems.org && \
    gem install -v1.10.0 ffi --source=http://rubygems.org && \
    gem install -v0.21.0 pg --source=http://rubygems.org && \
    gem install -v1.7.2 thin --source=http://rubygems.org && \
    gem install -v0.1.3  websocket-extensions --source=http://rubygems.org && \
    gem install -v0.5.9.3 cbor --source=http://rubygems.org
ADD ./docker/Gemfile /app/highway/Gemfile
ADD ./docker/Gemfile.lock /app/highway/Gemfile.lock
ADD ./docker/Rakefile /app/highway/Rakefile
RUN bundle _2.0.1_ install --system --no-deployment --gemfile=/app/highway/Gemfile && \
    bundle _2.0.1_ check

RUN rm -f /app/highway/tmp/pids/server.pid

FROM docker-registry.infra.01.k-ciralabs.ca/lestienne/distroless-ruby:2.6.1-dnsutils

COPY --from=builder /app /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /usr/local/lib/ruby /usr/local/lib/ruby
COPY --from=builder /usr/share/zoneinfo/UTC /etc/localtime
COPY --from=builder /gems/highway /gems/highway
COPY --from=builder /bin/sash     /bin/sash
COPY --from=builder /usr/bin/env  /usr/bin/env
COPY --from=builder /bin/busybox  /bin/busybox

ENV PATH="/usr/local/bundle/bin:${PATH}"

COPY . /app/highway
ADD ./docker/Gemfile /app/highway/Gemfile
ADD ./docker/Gemfile.lock /app/highway/Gemfile.lock
ENV GEM_HOME="/usr/local/bundle"

WORKDIR /app/highway

EXPOSE 9443

CMD ["bundle", "_2.0.1_", "exec", "thin", "start", "--ssl",      \
    "--address", "0.0.0.0", "--port", "9443",                         \
    "--ssl-cert-file", "/app/certificates/server_prime256v1.crt",\
    "--ssl-key-file",  "/app/certificates/server_prime256v1.key" ]

