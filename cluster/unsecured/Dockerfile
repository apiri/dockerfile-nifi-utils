FROM apachenifi:1.1.1

ADD    ./sh/ /opt/nifi/sh
RUN    ls -la /opt/nifi

USER root

RUN    whoami && chown -R nifi:nifi /opt/nifi

USER nifi

CMD    ["/opt/nifi/sh/start.sh"]
