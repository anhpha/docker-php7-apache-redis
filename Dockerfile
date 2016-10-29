FROM phavo/docker-php7-apache:latest

RUN groupadd -r redis && useradd -r -g redis redis
RUN apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
	&& rm -rf /var/lib/apt/lists/*



ENV REDIS_VERSION 3.2.4
ENV REDIS_DOWNLOAD_URL http://download.redis.io/releases/redis-3.2.4.tar.gz
ENV REDIS_DOWNLOAD_SHA1 f0fe685cbfdb8c2d8c74613ad8a5a5f33fba40c9

# for redis-sentinel see: http://redis.io/topics/sentinel
RUN set -ex \
	\
	&& buildDeps=' \
		gcc \
		libc6-dev \
		make \
	' \
	&& apt-get update \
	&& apt-get install -y $buildDeps --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL" \
	&& echo "$REDIS_DOWNLOAD_SHA1 *redis.tar.gz" | sha1sum -c - \
	&& mkdir -p /usr/src/redis \
	&& tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1 \
	&& rm redis.tar.gz \
	\
# Disable Redis protected mode [1] as it is unnecessary in context
# of Docker. Ports are not automatically exposed when running inside
# Docker, but rather explicitely by specifying -p / -P.
# [1] https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
	&& grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' /usr/src/redis/src/server.h \
	&& sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' /usr/src/redis/src/server.h \
	&& grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' /usr/src/redis/src/server.h \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
	\
	&& make -C /usr/src/redis \
	&& make -C /usr/src/redis install \
	&& mkdir /etc/redis \
	&& cp -f /usr/src/redis/*.conf /etc/redis \
	\
	&& rm -r /usr/src/redis \
	\
	&& apt-get purge -y --auto-remove $buildDeps

RUN mkdir /data && chown redis:redis /data
VOLUME /data
WORKDIR /data

RUN sed -i 's/^\(daemonize .*\)$/daemonize yes/' /etc/redis/redis.conf

#Overide supervisor
ADD docker/supervisord.conf /etc/supervisord.conf

#install redis php extension
RUN apt-get update \
&& apt-get install -y php-redis

# By default, start supervisord
CMD ["/bin/bash", "/start.sh"]