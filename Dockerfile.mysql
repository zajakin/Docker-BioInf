##########################################   nginx 
FROM debian:buster-slim

#LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ENV NGINX_VERSION   1.19.7
ENV NJS_VERSION     0.5.1
ENV PKG_RELEASE     1~buster

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system --gid 101 nginx \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates wget \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
        apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${PKG_RELEASE} \
    " \
    && case "$dpkgArch" in \
        amd64|i386|arm64) \
# arches officialy built by upstream
            echo "deb https://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list \
            && apt-get update \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published source packages
            echo "deb-src https://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list \
            \
# new directory for storing sources and .deb files
            && tempDir="$(mktemp -d)" \
            && chmod 777 "$tempDir" \
# (777 to ensure APT's "_apt" user can access it too)
            \
# save list of currently-installed packages so build dependencies can be cleanly removed later
            && savedAptMark="$(apt-mark showmanual)" \
            \
# build .deb files from upstream's source packages (which are verified by apt-get)
            && apt-get update \
            && apt-get build-dep -y $nginxPackages \
            && ( \
                cd "$tempDir" \
                && DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
                    apt-get source --compile $nginxPackages \
            ) \
# we don't remove APT lists here because they get re-downloaded and removed later
            \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
            && apt-mark showmanual | xargs apt-mark auto > /dev/null \
            && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
            \
# create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
            && ls -lAFh "$tempDir" \
            && ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
            && grep '^Package: ' "$tempDir/Packages" \
            && echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
# work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
#   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
#   ...
#   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
            && apt-get -o Acquire::GzipIndexes=false update \
            ;; \
    esac \
    \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        $nginxPackages \
                        gettext-base \
                        curl \
    && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then \
        apt-get purge -y --auto-remove \
        && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d

#COPY docker-entrypoint.sh /
RUN wget -O /docker-entrypoint.sh https://github.com/nginxinc/docker-nginx/raw/master/mainline/debian/docker-entrypoint.sh && chmod +x /docker-entrypoint.sh; \
#COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
	wget -O /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh https://github.com/nginxinc/docker-nginx/raw/master/mainline/debian/10-listen-on-ipv6-by-default.sh && chmod +x /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh; \
#COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
	wget -O /docker-entrypoint.d/20-envsubst-on-templates.sh https://github.com/nginxinc/docker-nginx/raw/master/mainline/debian/20-envsubst-on-templates.sh && chmod +x /docker-entrypoint.d/20-envsubst-on-templates.sh; \
#COPY 30-tune-worker-processes.sh /docker-entrypoint.d
	wget -O /docker-entrypoint.d/30-tune-worker-processes.sh https://github.com/nginxinc/docker-nginx/raw/master/mainline/debian/30-tune-worker-processes.sh && chmod +x /docker-entrypoint.d/30-tune-worker-processes.sh
#ENTRYPOINT ["/docker-entrypoint.sh"]

#EXPOSE 80

#STOPSIGNAL SIGQUIT

#CMD ["nginx", "-g", "daemon off;"]

############################################  supervisor

RUN sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list && \
  env DEBIAN_FRONTEND=noninteractive apt-get update && \
	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils && \
	env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends && \
	env DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --no-install-recommends && \
	env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		locales sudo mc htop shellinabox ssh tmux supervisor bash-completion bzip2 git wget && \
	apt-get autoremove -y && \
	apt-get autoclean -y
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.utf8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.utf8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.utf8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# lv_LV.UTF-8 UTF-8/lv_LV.utf8 UTF-8/' /etc/locale.gen && \
	locale-gen && \
	mkdir -p /run/sshd /var/log/supervisor && \
	echo "export VISIBLE=now" >> /etc/profile

##########################################   mysql:5.7
#FROM debian:buster-slim

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-get update && apt-get install -y --no-install-recommends gnupg dirmngr && rm -rf /var/lib/apt/lists/*

# add gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.12
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

RUN mkdir /docker-entrypoint-initdb.d

RUN apt-get update && apt-get install -y --no-install-recommends \
# for MYSQL_RANDOM_ROOT_PASSWORD
		pwgen \
# for mysql_ssl_rsa_setup
		openssl \
# FATAL ERROR: please install the following Perl modules before executing /usr/local/mysql/scripts/mysql_install_db:
# File::Basename
# File::Copy
# Sys::Hostname
# Data::Dumper
		perl \
# install "xz-utils" for .sql.xz docker-entrypoint-initdb.d files
		xz-utils \
	&& rm -rf /var/lib/apt/lists/*

RUN set -ex; \
# gpg: key 5072E1F5: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
	key='A4A9406876FCBD3C456770C88C718D3B5072E1F5'; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	gpg --batch --export "$key" > /etc/apt/trusted.gpg.d/mysql.gpg; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	apt-key list > /dev/null

ENV MYSQL_MAJOR 5.7
ENV MYSQL_VERSION 5.7.33-1debian10

RUN echo 'deb http://repo.mysql.com/apt/debian/ buster mysql-5.7' > /etc/apt/sources.list.d/mysql.list

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter
RUN { \
		echo mysql-community-server mysql-community-server/data-dir select ''; \
		echo mysql-community-server mysql-community-server/root-pass password ''; \
		echo mysql-community-server mysql-community-server/re-root-pass password ''; \
		echo mysql-community-server mysql-community-server/remove-test-db select false; \
	} | debconf-set-selections \
	&& apt-get update \
	&& apt-get install -y mysql-server \
#		mysql-server="${MYSQL_VERSION}" \
# comment out a few problematic configuration values
	&& find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/' \
# don't reverse lookup hostnames, they are usually another container
	&& echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 1777 /var/run/mysqld /var/lib/mysql

VOLUME /var/lib/mysql

#COPY docker-entrypoint.sh /usr/local/bin/
RUN wget -O /docker-entrypoint.d/05-mysql-docker-entrypoint.sh https://github.com/docker-library/mysql/raw/master/5.7/docker-entrypoint.sh && chmod +x /docker-entrypoint.d/05-mysql-docker-entrypoint.sh

#RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat
#ENTRYPOINT ["docker-entrypoint.sh"]

#EXPOSE 3306 33060
#CMD ["mysqld"]

##########################################   php 
#FROM php:7.3-fpm as php
#FROM debian:buster-slim

# prevent Debian's PHP packages from being installed
# https://github.com/docker-library/php/pull/542
RUN set -eux; \
	{ \
		echo 'Package: php*'; \
		echo 'Pin: release *'; \
		echo 'Pin-Priority: -1'; \
	} > /etc/apt/preferences.d/no-debian-php

# dependencies required for running "phpize"
# (see persistent deps below)
ENV PHPIZE_DEPS \
		autoconf \
		dpkg-dev \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkg-config \
		re2c

# persistent / runtime deps
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		$PHPIZE_DEPS \
		ca-certificates \
		curl \
		xz-utils \
	; \
	rm -rf /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
	[ ! -d /var/www/html ]; \
	mkdir -p /var/www/html; \
	chown www-data:www-data /var/www/html; \
	chmod 777 /var/www/html

ENV PHP_EXTRA_CONFIGURE_ARGS --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --disable-cgi

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -pie"

ENV GPG_KEYS 42670A7FE4D0441C8E4632349E4FDC074A4EF02D 5A52880781F755608BF815FC910DEB46F53EA312

ENV PHP_VERSION 7.3.18
ENV PHP_URL="https://www.php.net/distributions/php-7.3.18.tar.xz" PHP_ASC_URL="https://www.php.net/distributions/php-7.3.18.tar.xz.asc"
ENV PHP_SHA256="7b3e2479a8d6fd7666dcdef8aec50d49c4599cc6ee86e48d41724cfd99cc9e58"

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends gnupg dirmngr; \
	rm -rf /var/lib/apt/lists/*; \
	\
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	curl -fsSL -o php.tar.xz "$PHP_URL"; \
	\
	if [ -n "$PHP_SHA256" ]; then \
		echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
	fi; \
	\
#	if [ -n "$PHP_ASC_URL" ]; then \
#		curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
#		export GNUPGHOME="$(mktemp -d)"; \
#		for key in $GPG_KEYS; do \
#			gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
#		done; \
#		gpg --batch --verify php.tar.xz.asc php.tar.xz; \
#		gpgconf --kill all; \
#		rm -rf "$GNUPGHOME"; \
#	fi; \
#	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

#COPY docker-php-source /usr/local/bin/
RUN wget -O /usr/local/bin/docker-php-source https://github.com/docker-library/php/raw/master/7.3/buster/fpm/docker-php-source && chmod +x /usr/local/bin/docker-php-source

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libargon2-dev \
		libcurl4-openssl-dev \
		libedit-dev \
		libonig-dev \
		libsodium-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
		zlib1g-dev \
		${PHP_EXTRA_BUILD_DEPS:-} \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	export \
		CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS" \
	; \
	docker-php-source extract; \
	cd /usr/src/php; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
# https://bugs.php.net/bug.php?id=74125
	if [ ! -d /usr/include/curl ]; then \
		ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
	fi; \
	./configure \
		--build="$gnuArch" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		\
# make sure invalid --configure-flags are fatal errors instead of just warnings
		--enable-option-checking=fatal \
		\
# https://github.com/docker-library/php/issues/439
		--with-mhash \
		\
# https://github.com/docker-library/php/issues/822
		--with-pic \
		\
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
		--enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
		--with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
		--with-sodium=shared \
# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
		--with-pdo-sqlite=/usr \
		--with-sqlite3=/usr \
		\
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
		--with-pdo-mysql=mysqlnd \
		--with-mysqli=mysqlnd \
# in PHP 7.4+, the pecl/pear installers are officially deprecated (requiring an explicit "--with-pear")
		--with-pear \
		\
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
		$(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
		--with-libdir="lib/$debMultiarch" \
		\
		${PHP_EXTRA_CONFIGURE_ARGS:-} \
	; \
	make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; \
	make clean; \
	\
# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	cp -v php.ini-* "$PHP_INI_DIR/"; \
	\
	cd /; \
	docker-php-source delete; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
# update pecl channel definitions https://github.com/docker-library/php/issues/443
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
	\
# smoke test
	php --version

#COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/
RUN wget -O /usr/local/bin/docker-php-ext-install   https://github.com/docker-library/php/raw/master/7.3/buster/fpm/docker-php-ext-install   && chmod +x /usr/local/bin/docker-php-ext-install; \
	wget -O /usr/local/bin/docker-php-ext-enable    https://github.com/docker-library/php/raw/master/7.3/buster/fpm/docker-php-ext-enable    && chmod +x /usr/local/bin/docker-php-ext-enable; \
	wget -O /usr/local/bin/docker-php-ext-configure https://github.com/docker-library/php/raw/master/7.3/buster/fpm/docker-php-ext-configure && chmod +x /usr/local/bin/docker-php-ext-configure; \
	wget -O /docker-entrypoint.d/25-docker-php-entrypoint.sh https://github.com/docker-library/php/raw/master/7.3/buster/fpm/docker-php-entrypoint && chmod +x /docker-entrypoint.d/25-docker-php-entrypoint.sh

# sodium was built as a shared module (so that it can be replaced later if so desired), so let's enable it too (https://github.com/docker-library/php/issues/598)
RUN docker-php-ext-enable sodium

#ENTRYPOINT ["docker-php-entrypoint"]
WORKDIR /var/www/html

RUN set -eux; \
	cd /usr/local/etc; \
	if [ -d php-fpm.d ]; then \
		# for some reason, upstream's php-fpm.conf.default has "include=NONE/etc/php-fpm.d/*.conf"
		sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
		cp php-fpm.d/www.conf.default php-fpm.d/www.conf; \
	else \
		# PHP 5.x doesn't use "include=" by default, so we'll create our own simple config that mimics PHP 7+ for consistency
		mkdir php-fpm.d; \
		cp php-fpm.conf.default php-fpm.d/www.conf; \
		{ \
			echo '[global]'; \
			echo 'include=etc/php-fpm.d/*.conf'; \
		} | tee php-fpm.conf; \
	fi; \
	{ \
		echo '[global]'; \
		echo 'error_log = /proc/self/fd/2'; \
		echo; echo '; https://github.com/docker-library/php/pull/725#issuecomment-443540114'; echo 'log_limit = 8192'; \
		echo; \
		echo '[www]'; \
		echo '; if we send this to /proc/self/fd/1, it never appears'; \
		echo 'access.log = /proc/self/fd/2'; \
		echo; \
		echo 'clear_env = no'; \
		echo; \
		echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
		echo 'catch_workers_output = yes'; \
		echo 'decorate_workers_output = no'; \
	} | tee php-fpm.d/docker.conf; \
	{ \
		echo '[global]'; \
		echo 'daemonize = no'; \
		echo; \
		echo '[www]'; \
		echo 'listen = 9000'; \
	} | tee php-fpm.d/zz-docker.conf

RUN env DEBIAN_FRONTEND=noninteractive apt update -y && env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libzip-dev libxml2-dev zip nodejs npm mysql-client automake autoconf wget tar; \
	docker-php-ext-install zip pdo bcmath pdo_mysql tokenizer xml \
#	   && wget http://xdebug.org/files/xdebug-2.9.0.tgz \
#    && tar -xvzf xdebug-2.9.0.tgz \
#    && cd xdebug-2.9.0 \
#    && phpize && ./configure && make \
#    && mkdir /src && cp modules/xdebug.so /src/xdebug.so \
#    && mkdir -p /usr/local/lib/php/extensions/no-debug-non-zts-20190902/
#	&& cp /src/xdebug.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902/xdebug.so \
#	&& cp /src/xdebug.so /usr/local/lib/php/extensions/no-debug-non-zts-20180731/xdebug.so \
	&& php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer && chmod +x /usr/local/bin/composer

###############################################################

RUN {	echo '[supervisord]'; \
		echo 'user=root'; \
		echo 'nodaemon=true'; \
		echo 'redirect_stderr=true'; \
		echo ''; \
		echo '[supervisorctl]'; \
		echo 'serverurl=unix:///tmp/supervisor.sock'; \
		echo ''; \
		echo '[unix_http_server]'; \
		echo 'file = /tmp/supervisor.sock'; \
		echo 'chmod = 0777'; \
		echo 'chown= nobody:nogroup'; \
		echo ''; \
		echo '[inet_http_server]'; \
		echo 'port=0.0.0.0:8000'; \
	} > /etc/supervisor/conf.d/supervisord.conf; \
	{	echo '[program:sshd]'; \
		echo 'command=/usr/sbin/sshd -D'; \
		echo 'stdout_logfile=/var/log/sshd.log'; \
		echo 'autostart=true'; \
		echo 'autorestart=true'; \
		echo 'user=root'; \
		echo 'stopsignal=SIGQUIT'; \
		echo 'numprocs=1'; \
		echo 'redirect_stderr=true'; \
	} > /etc/supervisor/conf.d/sshd.conf; \
	{	echo '[program:mysqld]'; \
		echo 'command=/usr/bin/mysqld_safe'; \
		echo 'stdout_logfile=/var/log/mysqld.log'; \
		echo 'autostart=true'; \
		echo 'autorestart=true'; \
		echo 'user=mysql'; \
		echo 'stopsignal=SIGQUIT'; \
		echo 'numprocs=1'; \
		echo 'redirect_stderr=true'; \
	} > /etc/supervisor/conf.d/mysqld.conf; \
	{	echo '[program:nginx]'; \
		echo "command=/usr/sbin/nginx -g 'daemon off;'"; \
		echo 'stdout_logfile=/var/log/nginx.log'; \
		echo 'autostart=true'; \
		echo 'autorestart=true'; \
		echo 'user=root'; \
		echo 'stopsignal=SIGQUIT'; \
		echo 'numprocs=1'; \
		echo 'redirect_stderr=true'; \
	} > /etc/supervisor/conf.d/nginx.conf; \
	{	echo '[program:php-fpm]'; \
		echo 'command=php-fpm'; \
		echo 'stdout_logfile=/var/log/php-fpm.log'; \
		echo 'autostart=true'; \
		echo 'autorestart=true'; \
		echo 'user=root'; \
		echo 'stopsignal=SIGQUIT'; \
		echo 'numprocs=1'; \
		echo 'redirect_stderr=true'; \
	} > /etc/supervisor/conf.d/php-fpm.conf; \
	{	echo '[program:restart_server]'; \
		echo 'command=/usr/bin/pkill supervisord'; \
		echo 'stdout_logfile=/var/log/restart_server.log'; \
		echo 'autostart=false'; \
		echo 'autorestart=false'; \
		echo 'user=root'; \
		echo 'startsecs=0'; \
		echo 'stopsignal=KILL'; \
		echo 'numprocs=1'; \
		echo 'redirect_stderr=true'; \
	} > /etc/supervisor/conf.d/restart_server.conf

#RUN cat /usr/local/etc/php/php.ini-production | sed 's/^;extension=mysqli/extension=mysqli/' | sed 's/^;extension=pdo_mysql/extension=pdo_mysql/' > /usr/local/etc/php/php.ini; \
#	useradd -G sudo --create-home -s /bin/bash -m ${MYSQL_USER} && echo "${MYSQL_USER}:${MYSQL_PASSWORD}" | chpasswd

EXPOSE 22 80

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/usr/bin/supervisord"]
