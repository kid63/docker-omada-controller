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
# ensure minimum Bouncy Castle version
ARG BOUNCYCASTLE_VER="1.85"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls bcprov-jdk18on-*.jar | head -n1)" .jar | sed 's/^bcprov-jdk18on-//')"; \
    if [ "$(printf '%s\n%s\n' "${BOUNCYCASTLE_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "Bouncy Castle ${CURRENT_VER} is already >= ${BOUNCYCASTLE_VER}; keeping upstream version"; \
    else \
        rm -f bcprov-jdk18on-*.jar bcpkix-jdk18on-*.jar bcutil-jdk18on-*.jar; \
        for artifact in bcprov-jdk18on bcpkix-jdk18on bcutil-jdk18on; do \
            wget -nv "https://repo1.maven.org/maven2/org/bouncycastle/${artifact}/${BOUNCYCASTLE_VER}/${artifact}-${BOUNCYCASTLE_VER}.jar"; \
        done; \
    fi

# update FreeMarker
# ensure minimum FreeMarker version
ARG FREEMARKER_VER="2.3.35"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls freemarker-*.jar | head -n1)" .jar | sed 's/^freemarker-//')"; \
    if [ "$(printf '%s\n%s\n' "${FREEMARKER_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "FreeMarker ${CURRENT_VER} is already >= ${FREEMARKER_VER}; keeping upstream version"; \
    else \
        rm -f freemarker-*.jar; \
        wget -nv "https://repo1.maven.org/maven2/org/freemarker/freemarker/${FREEMARKER_VER}/freemarker-${FREEMARKER_VER}.jar"; \
    fi

# update Thymeleaf
# ensure minimum Thymeleaf version
ARG THYMELEAF_VER="3.1.5.RELEASE"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls thymeleaf-*.jar | head -n1)" .jar | sed 's/^thymeleaf-//')"; \
    if [ "$(printf '%s\n%s\n' "${THYMELEAF_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "Thymeleaf ${CURRENT_VER} is already >= ${THYMELEAF_VER}; keeping upstream version"; \
    else \
        rm -f thymeleaf-*.jar; \
        wget -nv "https://repo1.maven.org/maven2/org/thymeleaf/thymeleaf/${THYMELEAF_VER}/thymeleaf-${THYMELEAF_VER}.jar"; \
    fi

# update Tomcat
# ensure minimum Tomcat version
ARG TOMCAT_VER="10.1.59"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls tomcat-embed-core-*.jar | head -n1)" .jar | sed 's/^tomcat-embed-core-//')"; \
    if [ "$(printf '%s\n%s\n' "${TOMCAT_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "Tomcat ${CURRENT_VER} is already >= ${TOMCAT_VER}; keeping upstream version"; \
    else \
        rm -f tomcat-embed-core-*.jar \
              tomcat-embed-el-*.jar \
              tomcat-embed-jasper-*.jar \
              tomcat-embed-websocket-*.jar \
              tomcat-annotations-api-*.jar; \
        for artifact in tomcat-embed-core tomcat-embed-el tomcat-embed-jasper tomcat-embed-websocket; do \
            wget -nv "https://repo1.maven.org/maven2/org/apache/tomcat/embed/${artifact}/${TOMCAT_VER}/${artifact}-${TOMCAT_VER}.jar"; \
        done; \
        wget -nv "https://repo1.maven.org/maven2/org/apache/tomcat/tomcat-annotations-api/${TOMCAT_VER}/tomcat-annotations-api-${TOMCAT_VER}.jar"; \
    fi

# update Netty libraries
# ensure minimum Netty version
ARG NETTY_VER="4.1.137.Final"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls netty-common-*.jar | head -n1)" .jar | sed 's/^netty-common-//')"; \
    if [ "$(printf '%s\n%s\n' "${NETTY_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "Netty ${CURRENT_VER} is already >= ${NETTY_VER}; keeping upstream version"; \
    else \
        for old in netty-*-"${CURRENT_VER}"*.jar; do \
            artifact="${old%%-${CURRENT_VER}*}"; \
            suffix="${old#${artifact}-${CURRENT_VER}}"; \
            new="${artifact}-${NETTY_VER}${suffix}"; \
            wget -nv "https://repo1.maven.org/maven2/io/netty/${artifact}/${NETTY_VER}/${new}"; \
            rm -f "${old}"; \
        done; \
    fi

COPY entrypoint-unified.sh /entrypoint.sh

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8044 8088 8043 8843 19810/udp 27001/udp 29810/udp 29811 29812 29813 29814 29815 29816 29817
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof","-Djava.awt.headless=true","-cp","/opt/tplink/EAPController/lib/*:/opt/tplink/EAPController/properties","com.tplink.smb.omada.starter.OmadaLinuxMain"]
