# Azurewind's PostgreSQL image with Chinese full text searchi using pg_jieba

FROM postgres
ARG CN_MIRROR=0

# Uncomment the following command if you have bad internet connection
# and first download the files into data directory
# COPY data/pg_jieba.zip /pg_jieba.zip

RUN if [ $CN_MIRROR = 1 ] ; then DEBIAN_VERSION=$(dpkg --status tzdata|grep Provides|cut -f2 -d'-') \
&& echo "using mirrors for $DEBIAN_VERSION" \
&& echo "deb http://ftp.cn.debian.org/debian/ $DEBIAN_VERSION main non-free contrib \n\
deb http://ftp.cn.debian.org/debian/ $DEBIAN_VERSION-updates main non-free contrib \n\
deb http://ftp.cn.debian.org/debian/ $DEBIAN_VERSION-backports main non-free contrib \n\
deb http://ftp.cn.debian.org/debian-security/ $DEBIAN_VERSION/updates main non-free contrib \n\
deb-src http://ftp.cn.debian.org/debian/ $DEBIAN_VERSION main non-free contrib \n\
deb-src http://ftp.cn.debian.org/debian/ $DEBIAN_VERSION-updates main non-free contrib \n\
deb-src http://ftp.cn.debian.org/debian/ $DEBIAN_VERSION-backports main non-free contrib \n\
deb-src http://ftp.cn.debian.org/debian-security/ $DEBIAN_VERSION/updates main non-free contrib" > /etc/apt/sources.list; else echo "No mirror"; fi

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
      postgresql-server-dev-$PG_MAJOR \
      gcc \
      make \
      libc-dev \
      g++ \
      git \
      cmake \
      curl \
      ca-certificates \
      openssl \
	&& rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/jaiminpan/pg_jieba \
  && cd /pg_jieba \
  && git submodule update --init --recursive 

RUN git clone https://github.com/jaiminpan/pg_scws

RUN cd /pg_jieba \
  && mkdir -p build \
  && cd build \
  && curl -L https://raw.githubusercontent.com/ssfdust/psql_jieba_swsc/master/FindPostgreSQL.cmake > $(find /usr -name "FindPostgreSQL.cmake") \
  && cmake .. \
  && make \
  && make install \
  && cd /pg_scws \
  && USE_PGXS=1 make \
  && USE_PGXS=1 make install \
  && echo "  \n\
  # echo \"timezone = 'Asia/Shanghai'\" >> /var/lib/postgresql/data/postgresql.conf \n\
  echo \"shared_preload_libraries = 'pg_jieba'\" >> /var/lib/postgresql/data/postgresql.conf" \
  > /docker-entrypoint-initdb.d/init-dict.sh \
# The following command is not required if load database from backup
  && echo "CREATE EXTENSION pg_jieba;create extension pg_scws;" > /docker-entrypoint-initdb.d/init-jieba.sql \
# RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
#   && echo "Asia/Shanghai" >  /etc/timezone
  && apt-get purge -y gcc make libc-dev postgresql-server-dev-$PG_MAJOR g++ git cmake curl\
  && apt-get autoremove -y \
  && rm -rf \
    /pg_jieba

