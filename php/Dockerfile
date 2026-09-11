# Official PHP-FPM image
# PHP_VERSION can be passed from the .env file
ARG PHP_VERSION=8.2-fpm
FROM php:${PHP_VERSION}

# Install required packages and PHP extensions
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    wget \
    mariadb-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli opcache zip pdo pdo_mysql

# gosu: run commands as a non-root user
ENV GOSU_VERSION 1.17
RUN set -eux; \
	dpkgArch="$(dpkg --print-architecture)"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version

# Install Xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Entrypoint and translation scripts
COPY entrypoint.sh wp-update-translations.sh /usr/local/bin/
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/wp-update-translations.sh \
    && chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/wp-update-translations.sh

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm"]
