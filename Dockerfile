FROM node:20.9.0-slim as app_node
COPY --chown=www-data:www-data ./package.json ./package-lock.json /app/
WORKDIR /app
RUN npm ci
FROM composer:2.6.5 as app_files
COPY --from=mlocati/php-extension-installer:2.1.61 /usr/bin/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions
WORKDIR /app
# install necessary alpine packages
RUN apk update \
    && install-php-extensions zip \
    	mysqli \
    	pdo \
    	pdo_mysql \
    	gd \
    	calendar \
        xml \
        zip \
        bcmath
COPY --chown=www-data:www-data ./composer.json ./composer.lock /app/
RUN composer install --verbose --prefer-dist --no-interaction --ignore-platform-reqs --no-scripts
COPY --chown=www-data:www-data ./ /app/
RUN composer install --verbose --prefer-dist --no-interaction --ignore-platform-reqs
FROM php:8.2.12-zts-alpine3.18
ARG APP_ENV=local
COPY --from=mlocati/php-extension-installer:2.1.61 /usr/bin/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions
# install necessary alpine packages
RUN apk update \
    && install-php-extensions zip \
    	mysqli \
    	pdo \
    	pdo_mysql \
    	gd \
    	calendar \
        xml \
        zip \
        bcmath
RUN if [ $APP_ENV = prod ]; then mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; else mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"; fi
VOLUME /app/
COPY --from=app_node  --chown=www-data:www-data /app/node_modules /app/node_modules
COPY --from=app_files --chown=www-data:www-data /app/ /app/
WORKDIR /app
CMD /usr/local/bin/php -d variables_order=EGPCS /var/www/html/artisan serve --host=0.0.0.0 --port=80
