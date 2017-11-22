FROM openjdk:8
# Configuration variables.
ENV JIRA_HOME     /var/atlassian/jira
ENV JIRA_INSTALL  /opt/atlassian/jira
ENV JIRA_VERSION  7.3.8
# 定义临时文件夹，用于存放上传的文件
ENV TEMP_PATH     /temp/jira
# 准备JIRA的安装工作
# 1. 创建/temp/jira临时目录
# 2. 将需要的文件上传到临时文件，有破解文件和JIRA的安装包等等
# 3. 将sources.list.163文件上传，用于替换成163源
# To Ready JIRA
RUN mkdir -p  /temp/jira
#COPY mysql-connector-java-5.1.39-bin.jar         /temp/jira/mysql-connector-java-5.1.39-bin.jar
COPY atlassian-extras-3.2.jar                    /temp/jira/atlassian-extras-3.2.jar
#COPY postgresql-9.4.1212.jar                     /temp/jira/postgresql-9.4.1212.jar
#COPY atlassian-jira-software-7.3.8.tar.gz        /temp/jira/atlassian-jira-software-7.3.8.tar.gz
COPY sources.list.163                            /temp/jira/sources.list.163
# 安装JIRA的运行命令，主要做了以下工作：
# 1. 将debain的原始源替换成国内的163源
# 2. 将下载获取JIRA更换为上传JIRA的源码包，因为下载JIRA的速度实在有点感人
# Install Atlassian JIRA and helper tools and setup initial home
# directory structure.
RUN set -x \
    && mv                      /etc/apt/sources.list /etc/apt/sources.list.back \
    && cp                      "${TEMP_PATH}/sources.list.163" /etc/apt/sources.list \
    # && echo "deb http://mirrors.163.com/debian jessie-backports main" > /etc/apt/sources.list.d/jessie-backports.list \
    && apt-get update --quiet \
    && apt-get install --quiet --yes --no-install-recommends xmlstarlet \
    && apt-get install --quiet --yes --no-install-recommends -t jessie-backports libtcnative-1 \
    && apt-get clean \
    && mkdir -p                "${JIRA_HOME}" \
    && mkdir -p                "${JIRA_HOME}/caches/indexes" \
    && chmod -R 700            "${JIRA_HOME}" \
    && chown -R daemon:daemon  "${JIRA_HOME}" \
    && mkdir -p                "${JIRA_INSTALL}/conf/Catalina" \
#    && cp                      "${TEMP_PATH}/atlassian-jira-software-${JIRA_VERSION}.tar.gz" "./atlassian-jira-software-${JIRA_VERSION}.tar.gz" \
#    && tar -zxvf               "./atlassian-jira-software-${JIRA_VERSION}.tar.gz" --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-7.3.8.tar.gz" | tar -xzvf --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://www.atlassian.com/software/jira/downloads/binary/atlassian-servicedesk-3.9.0-tar.gz"   | tar -xzvf --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.39.tar.gz" | tar -xzvf --directory "${JIRA_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.39/mysql-connector-java-5.1.39-bin.jar" \
    && rm -f                   "${JIRA_INSTALL}/lib/postgresql-9.1-903.jdbc4-atlassian-hosted.jar" \
    && curl -Ls                "https://jdbc.postgresql.org/download/postgresql-9.4.1212.jar" -o "${JIRA_INSTALL}/lib/postgresql-9.4.1212.jar" \
    && chmod -R 700            "${JIRA_INSTALL}/conf" \
    && chmod -R 700            "${JIRA_INSTALL}/logs" \
    && chmod -R 700            "${JIRA_INSTALL}/temp" \
    && chmod -R 700            "${JIRA_INSTALL}/work" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/conf" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/logs" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/temp" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/work" \
    && sed --in-place          "s/java version/openjdk version/g" "${JIRA_INSTALL}/bin/check-java.sh" \
    && echo -e                 "\njira.home=$JIRA_HOME" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0"           "${JIRA_INSTALL}/conf/server.xml"
# 使用补丁包替换掉原来的JAR包
# Hack
RUN set -x \
    && rm -rf                  "${JIRA_INSTALL}/atlassian-jira/WEB-INF/lib/atlassian-extras-3.2.jar" \
    && cp                      "${TEMP_PATH}/atlassian-extras-3.2.jar" "${JIRA_INSTALL}/atlassian-jira/WEB-INF/lib/atlassian-extras-3.2.jar"
# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER daemon:daemon
# Expose default HTTP connector port.
EXPOSE 8080
# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/atlassian/jira", "/opt/atlassian/jira/logs"]
# Set the default working directory as the installation directory.
WORKDIR /var/atlassian/jira
COPY "docker-entrypoint.sh" "/"
ENTRYPOINT ["/docker-entrypoint.sh"]
# Run Atlassian JIRA as a foreground process by default.
CMD ["/opt/atlassian/jira/bin/catalina.sh", "run"]
