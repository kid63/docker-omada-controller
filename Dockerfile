# rebased/repackaged base image that only updates existing packages
ARG BASE=mbentley/ubuntu:24.04
FROM ${BASE}
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"
LABEL org.opencontainers.image.source="https://github.com/kid63/docker-omada-controller"

COPY healthcheck.sh install.sh /

# valid values: amd64 (default) | arm64 | armv7l (deprecated)
ARG TARGETARCH
ARG ARCH=${TARGETARCH}

# install version (major.minor or full version); OMADA_URL set in install.sh
ARG INSTALL_VER="6.3.0.111"
LABEL org.opencontainers.image.version="${INSTALL_VER}"
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

# update Jackson
ARG JACKSON_VER="2.18.11"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in \
        jackson-annotations \
        jackson-core \
        jackson-databind \
        jackson-dataformat-xml \
        jackson-dataformat-yaml \
        jackson-datatype-jdk8 \
        jackson-datatype-jsr310 \
        jackson-module-parameter-names; do \
        case "${artifact}" in \
            jackson-annotations|jackson-core|jackson-databind) group="core" ;; \
            jackson-dataformat-*) group="dataformat" ;; \
            jackson-datatype-*) group="datatype" ;; \
            jackson-module-*) group="module" ;; \
        esac; \
        CURRENT_VER="$(basename "$(ls ${artifact}-*.jar | head -n1)" .jar | sed "s/^${artifact}-//")"; \
        if [ "$(printf '%s\n%s\n' "${JACKSON_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
            echo "${artifact} ${CURRENT_VER} is already >= ${JACKSON_VER}; keeping upstream version"; \
        else \
            rm -f "${artifact}-"*.jar; \
            wget -nv "https://repo1.maven.org/maven2/com/fasterxml/jackson/${group}/${artifact}/${JACKSON_VER}/${artifact}-${JACKSON_VER}.jar"; \
        fi; \
    done

# update LZ4
ARG LZ4_VER="1.11.4"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls lz4-java-*.jar | head -n1)" .jar | sed 's/^lz4-java-//')"; \
    if [ "$(printf '%s\n%s\n' "${LZ4_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "LZ4 ${CURRENT_VER} is already >= ${LZ4_VER}; keeping upstream version"; \
    else \
        rm -f lz4-java-*.jar; \
        wget -nv "https://repo1.maven.org/maven2/at/yawk/lz4/lz4-java/${LZ4_VER}/lz4-java-${LZ4_VER}.jar"; \
    fi

# update Micrometer
ARG MICROMETER_VER="1.15.12"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in \
        micrometer-commons \
        micrometer-core \
        micrometer-jakarta9 \
        micrometer-observation \
        micrometer-registry-prometheus; do \
        CURRENT_VER="$(basename "$(ls ${artifact}-*.jar | head -n1)" .jar | sed "s/^${artifact}-//")"; \
        if [ "$(printf '%s\n%s\n' "${MICROMETER_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
            echo "${artifact} ${CURRENT_VER} is already >= ${MICROMETER_VER}; keeping upstream version"; \
        else \
            rm -f "${artifact}-"*.jar; \
            wget -nv "https://repo1.maven.org/maven2/io/micrometer/${artifact}/${MICROMETER_VER}/${artifact}-${MICROMETER_VER}.jar"; \
        fi; \
    done

# update Apache HttpCore 5
ARG HTTPCORE_VER="5.4.3"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in httpcore5 httpcore5-h2; do \
        CURRENT_VER="$(basename "$(ls ${artifact}-*.jar | head -n1)" .jar | sed "s/^${artifact}-//")"; \
        if [ "$(printf '%s\n%s\n' "${HTTPCORE_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
            echo "${artifact} ${CURRENT_VER} is already >= ${HTTPCORE_VER}; keeping upstream version"; \
        else \
            rm -f "${artifact}-"*.jar; \
            wget -nv "https://repo1.maven.org/maven2/org/apache/httpcomponents/core5/${artifact}/${HTTPCORE_VER}/${artifact}-${HTTPCORE_VER}.jar"; \
        fi; \
    done

# update Spring Framework
ARG SPRING_FRAMEWORK_VER="6.2.19"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in \
        spring-aop \
        spring-beans \
        spring-context \
        spring-context-indexer \
        spring-context-support \
        spring-core \
        spring-expression \
        spring-jcl \
        spring-messaging \
        spring-tx \
        spring-web \
        spring-webmvc \
        spring-websocket; do \
        CURRENT_VER="$(basename "$(ls ${artifact}-*.jar | head -n1)" .jar | sed "s/^${artifact}-//")"; \
        if [ "$(printf '%s\n%s\n' "${SPRING_FRAMEWORK_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
            echo "${artifact} ${CURRENT_VER} is already >= ${SPRING_FRAMEWORK_VER}; keeping upstream version"; \
        else \
            rm -f "${artifact}-${CURRENT_VER}.jar"; \
            wget -nv "https://repo1.maven.org/maven2/org/springframework/${artifact}/${SPRING_FRAMEWORK_VER}/${artifact}-${SPRING_FRAMEWORK_VER}.jar"; \
        fi; \
    done

# update Spring Data Commons
ARG SPRING_DATA_COMMONS_VER="3.5.13"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls spring-data-commons-*.jar | head -n1)" .jar | sed 's/^spring-data-commons-//')"; \
    if [ "$(printf '%s\n%s\n' "${SPRING_DATA_COMMONS_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "Spring Data Commons ${CURRENT_VER} is already >= ${SPRING_DATA_COMMONS_VER}; keeping upstream version"; \
    else \
        rm -f "spring-data-commons-${CURRENT_VER}.jar"; \
        wget -nv "https://repo1.maven.org/maven2/org/springframework/data/spring-data-commons/${SPRING_DATA_COMMONS_VER}/spring-data-commons-${SPRING_DATA_COMMONS_VER}.jar"; \
    fi

# update Spring LDAP
ARG SPRING_LDAP_VER="3.3.8"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    CURRENT_VER="$(basename "$(ls spring-ldap-core-*.jar | head -n1)" .jar | sed 's/^spring-ldap-core-//')"; \
    if [ "$(printf '%s\n%s\n' "${SPRING_LDAP_VER}" "${CURRENT_VER}" | sort -V | tail -n1)" = "${CURRENT_VER}" ]; then \
        echo "Spring LDAP ${CURRENT_VER} is already >= ${SPRING_LDAP_VER}; keeping upstream version"; \
    else \
        rm -f "spring-ldap-core-${CURRENT_VER}.jar"; \
        wget -nv "https://repo1.maven.org/maven2/org/springframework/ldap/spring-ldap-core/${SPRING_LDAP_VER}/spring-ldap-core-${SPRING_LDAP_VER}.jar"; \
    fi

# update Spring Boot
ARG SPRING_BOOT_VER="3.5.15"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in \
        spring-boot \
        spring-boot-actuator \
        spring-boot-actuator-autoconfigure \
        spring-boot-autoconfigure \
        spring-boot-configuration-processor \
        spring-boot-loader \
        spring-boot-starter \
        spring-boot-starter-actuator \
        spring-boot-starter-aop \
        spring-boot-starter-data-mongodb \
        spring-boot-starter-freemarker \
        spring-boot-starter-json \
        spring-boot-starter-log4j2 \
        spring-boot-starter-quartz \
        spring-boot-starter-tomcat \
        spring-boot-starter-web; do \
        rm -f "${artifact}-"*.jar; \
        wget -nv "https://repo1.maven.org/maven2/org/springframework/boot/${artifact}/${SPRING_BOOT_VER}/${artifact}-${SPRING_BOOT_VER}.jar"; \
    done

# update Log4j2
ARG LOG4J_VER="2.25.5"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    for artifact in \
        log4j-api \
        log4j-core \
        log4j-jul \
        log4j-slf4j-impl \
        log4j-slf4j2-impl; do \
        rm -f "${artifact}-"*.jar; \
        wget -nv "https://repo1.maven.org/maven2/org/apache/logging/log4j/${artifact}/${LOG4J_VER}/${artifact}-${LOG4J_VER}.jar"; \
    done

# update Apache HttpClient 5
ARG HTTPCLIENT5_VER="5.6.3"
RUN set -eux; \
    cd /opt/tplink/EAPController/lib; \
    rm -f httpclient5-*.jar; \
    wget -nv "https://repo1.maven.org/maven2/org/apache/httpcomponents/client5/httpclient5/${HTTPCLIENT5_VER}/httpclient5-${HTTPCLIENT5_VER}.jar"

COPY entrypoint-unified.sh /entrypoint.sh

WORKDIR /opt/tplink/EAPController/lib
EXPOSE 8044 8088 8043 8843 19810/udp 27001/udp 29810/udp 29811 29812 29813 29814 29815 29816 29817
HEALTHCHECK --start-period=5m CMD /healthcheck.sh
VOLUME ["/opt/tplink/EAPController/data","/opt/tplink/EAPController/logs"]
ENTRYPOINT ["/entrypoint.sh"]
CMD ["java","-server","-Xms128m","-Xmx1024m","-XX:MaxHeapFreeRatio=60","-XX:MinHeapFreeRatio=30","-XX:+HeapDumpOnOutOfMemoryError","-XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof","-Djava.awt.headless=true","-cp","/opt/tplink/EAPController/lib/*:/opt/tplink/EAPController/properties","com.tplink.smb.omada.starter.OmadaLinuxMain"]
