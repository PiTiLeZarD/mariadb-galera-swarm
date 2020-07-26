FROM mariadb:10.3@sha256:5416211266fbb970b0fb1781b37493b0eb850facc70e6c4c815c12ea9197fbf6
MAINTAINER Jonathan Adami <contact@jadami.com>

RUN set -x \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends --no-install-suggests wget lsb-release \
    && wget --no-check-certificate https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb \
    && dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb \
    && rm percona-release_latest.$(lsb_release -sc)_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
      curl \
      netcat \
      pigz \
      percona-toolkit \
      percona-xtrabackup-80 \
      pv \
    && curl -sSL -H "User-Agent: Mozilla/5.0" -o /tmp/qpress.tar http://www.quicklz.com/qpress-11-linux-x64.tar \
    && tar -C /usr/local/bin -xf /tmp/qpress.tar qpress \
    && chmod +x /usr/local/bin/qpress \
    && apt-get clean all \
    && rm -rf /tmp/* /var/cache/apk/* /var/lib/apt/lists/*


COPY conf.d/*                /etc/mysql/conf.d/
COPY *.sh                    /usr/local/bin/
COPY bin/galera-healthcheck  /usr/local/bin/galera-healthcheck
COPY primary-component.sql   /

RUN set -ex ;\
    # Fix permissions
    chown -R mysql:mysql /etc/mysql ;\
    chmod -R go-w /etc/mysql ;\
    # Disable code that deletes progress file after SST
    sed -i 's#-p \$progress#-p \$progress-XXX#' /usr/bin/wsrep_sst_mariabackup

EXPOSE 3306 4444 4567 4567/udp 4568 8080 8081

HEALTHCHECK CMD /usr/local/bin/healthcheck.sh

ENV SST_METHOD=mariabackup

ENTRYPOINT ["start.sh"]
