FROM dunglas/frankenphp:1-php8.3-alpine

RUN apk add --no-cache bash

RUN install-php-extensions \
    gd \
    intl \
    pdo_mysql \
    mysqli \
    zip \
    bcmath \
    soap \
    opcache \
    exif \
    pcntl \
    xdebug \
    ftp \
    sockets \
    @composer

RUN echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.start_with_request=trigger" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/custom.ini && \
    echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/custom.ini

ARG USER_ID=1000

RUN adduser -D -u ${USER_ID} appuser && \
    setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp && \
    mkdir -p /data/caddy /config/caddy && \
    chown -R appuser:appuser /data/caddy /config/caddy

USER appuser

WORKDIR /app
