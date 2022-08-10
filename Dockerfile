# docker/Dockerfile
FROM php:8.0-fpm

ARG APCU_VERSION=5.1.18

# Get frequently used tools
RUN apt-get update && apt-get install -y \
    build-essential \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libssl-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libonig-dev \
    locales \
    zip \
    unzip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    git \
    curl \
    wget \
    zsh


RUN docker-php-ext-configure zip

RUN docker-php-ext-install \
    bcmath \
    mbstring \
    pcntl \
    intl \
    zip \
    pdo_mysql \
    opcache

# apcu for caching, xdebug for debugging and also phpunit coverage
RUN pecl install \
    apcu-${APCU_VERSION} \
    xdebug \
    && docker-php-ext-enable \
    apcu \
    xdebug

RUN docker-php-ext-install pdo pdo_mysql 
# Install Nginx
# install gnupg
RUN apt-get update && apt-get install -y \
    gnupg
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C
RUN echo "deb http://nginx.org/packages/ubuntu/ trusty nginx" >> /etc/apt/sources.list
RUN echo "deb-src http://nginx.org/packages/ubuntu/ trusty nginx" >> /etc/apt/sources.list
RUN apt-get update

RUN apt-get install -y nginx

ADD resources/default /etc/nginx/sites-enabled/
ADD resources/nginx.conf /etc/nginx/

#------------- Supervisor Process Manager ----------------------------------------------------
ADD resources/www.conf /etc/php/8.0/fpm/pool.d/www.conf
# Install supervisor
RUN apt-get install -y supervisor
RUN mkdir -p /var/log/supervisor
ADD resources/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# php-cs-fixer tool
RUN wget https://cs.symfony.com/download/php-cs-fixer-v2.phar -O /usr/local/bin/php-cs-fixer
RUN chmod +x /usr/local/bin/php-cs-fixer


# Copy existing app directory
COPY . /var/www/html
WORKDIR /var/www/html

# Configure non-root user.
ARG PUID=1001
ENV PUID ${PUID}
ARG PGID=1001
ENV PGID ${PGID}


RUN groupadd -g 1001 go \
    && useradd -m -u 1001 -g go go


RUN chown -R go:go /var/www
RUN chown -R 1001:1001 /var/log/supervisor
# Copy and run composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
RUN composer install --no-interaction
RUN cp .env.example .env
# For Laravel Installations
RUN php artisan key:generate
RUN mkdir -p /var/www/html/storage/logs
RUN mkdir -p /var/www/html/storage/framework/cache
RUN mkdir -p /var/www/html/storage/framework/sessions
RUN mkdir -p /var/www/html/storage/framework/views
RUN mkdir -p /var/www/html/storage/framework/testing
RUN chmod 777 -R storage
RUN rm -rf public/storage
RUN php artisan storage:link

# if storage/app/public exists, copy it to public/storage

RUN mkdir -p storage/app/public && chmod -R 777 storage/app/public
EXPOSE 80

ENTRYPOINT ["/usr/bin/supervisord"]
