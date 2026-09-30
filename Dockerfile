# rebased/repackaged base image that only updates existing packages
ARG BASE=mbentley/ubuntu:24.04
FROM ${BASE}
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"
LABEL org.opencontainers.image.source="https://github.com/mbentley/docker-omada-controller"

COPY healthcheck.sh install.sh /

# valid values: amd64 (default) | arm64 | armv7l (deprecated)
ARG ARCH=amd64

# install version (major.minor or full version); OMADA_URL set in install.sh
ARG INSTALL_VER="6.3.0.45"
ARG NO_MONGODB=false

# optional cache busting build arg (value is not actually used anywhere)
ARG MONGODB_VER

# install omada controller (instructions taken from install.sh)
RUN /install.sh &&\
  rm /install.sh

# update Bouncy Castle libraries
ARG BOUNCYCASTLE_VER="1.85"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in bcprov-jdk18on bcpkix-jdk18on bcutil-jdk18on; do \
        wget -nv "https://repo1.maven.org/maven2/org/bouncycastle/${artifact}/${BOUNCYCASTLE_VER}/${artifact}-${BOUNCYCASTLE_VER}.jar"; \
        rm -f "${artifact}-1.84.jar"; \
    done

# update FreeMarker
ARG FREEMARKER_VER="2.3.35"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    wget -nv "https://repo1.maven.org/maven2/org/freemarker/freemarker/${FREEMARKER_VER}/freemarker-${FREEMARKER_VER}.jar"; \
    rm -f freemarker-2.3.34.jar

# update Thymeleaf
ARG THYMELEAF_VER="3.1.5.RELEASE"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    wget -nv "https://repo1.maven.org/maven2/org/thymeleaf/thymeleaf/${THYMELEAF_VER}/thymeleaf-${THYMELEAF_VER}.jar"; \
    rm -f thymeleaf-3.1.4.RELEASE.jar

# update Tomcat
ARG TOMCAT_VER="10.1.59"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in tomcat-embed-core tomcat-embed-el tomcat-embed-jasper tomcat-embed-websocket; do \
        wget -nv "https://repo1.maven.org/maven2/org/apache/tomcat/embed/${artifact}/${TOMCAT_VER}/${artifact}-${TOMCAT_VER}.jar"; \
        rm -f "${artifact}-10.1.55.jar"; \
    done; \
    wget -nv "https://repo1.maven.org/maven2/org/apache/tomcat/tomcat-annotations-api/${TOMCAT_VER}/tomcat-annotations-api-${TOMCAT_VER}.jar"; \
    rm -f tomcat-annotations-api-10.1.55.jar

# update Netty libraries
ARG NETTY_OLD_VER="4.1.133.Final"
ARG NETTY_VER="4.1.137.Final"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for old in netty-*-"${NETTY_OLD_VER}"*.jar; do \
        artifact="${old%%-${NETTY_OLD_VER}*}"; \
        suffix="${old#${artifact}-${NETTY_OLD_VER}}"; \
        new="${artifact}-${NETTY_VER}${suffix}"; \
        wget -nv "https://repo1.maven.org/maven2/io/netty/${artifact}/${NETTY_VER}/${new}"; \
        rm -f "${old}"; \
    done

COPY entrypoint-unified.sh /entrypoint.sh

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8044 8088 8043 8843 19810/udp 27001/udp 29810/udp 29811 29812 29813 29814 29815 29816 29817
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof","-Djava.awt.headless=true","-cp","/opt/tplink/EAPController/lib/*:/opt/tplink/EAPController/properties","com.tplink.smb.omada.starter.OmadaLinuxMain"]
