FROM mariadb:10.3

RUN set -x \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends --no-install-suggests \
      curl \
      netcat \
      pigz \
      percona-toolkit \
      percona-xtrabackup \
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
    sed -i s/999/1000/g /etc/passwd ;\
    sed -i s/999/1000/g /etc/group ;\
    find / -group 999 -user 999 2>/dev/null | xargs chown -R 1000:1000; \
    chown -R mysql:mysql /etc/mysql ;\
    chmod -R go-w /etc/mysql ;\
    # Disable code that deletes progress file after SST
    sed -i 's#-p \$progress#-p \$progress-XXX#' /usr/bin/wsrep_sst_mariabackup

EXPOSE 3306 4444 4567 4567/udp 4568 8080 8081

HEALTHCHECK CMD /usr/local/bin/healthcheck.sh

ENV SST_METHOD=mariabackup

ENTRYPOINT ["start.sh"]
