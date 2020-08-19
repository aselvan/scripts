#
# Dockerfile
#
# This builds a compact docker image of openjdk with selective java components
#
# build the image w/ the following command.
#   docker build --rm -t java .
#
# test the java vm w/ following command after build (it should print VM flags and version)
#   docker run --rm -it java java -XX:+PrintFlagsFinal -version
#
# Author:  Arul Selvan
# Version: Aug 16, 2020
#

# stage1:
# base image w/ full JDK
FROM openjdk:16-jdk-alpine3.12 AS jdkimage

# select a small subset of jvm components needed.
RUN $JAVA_HOME/bin/jlink \
  --module-path /opt/jdk/jmods \
  --verbose \
  --add-modules java.base,java.logging,java.xml,java.sql,java.naming,java.rmi,java.desktop,java.management,java.security.jgss \
  --output /opt/jdk-minimal \
  --compress 2 \
  --no-header-files

# stage2:
# base image w/ out JDK
FROM alpine:3.12
MAINTAINER Arul Selvan <github@selvans.net>
COPY --from=jdkimage /opt/jdk-minimal /opt/java
ENV JAVA_HOME=/opt/java
ENV PATH="/opt/java/bin:$PATH"

# install anything else we need on the vanila image
RUN apk add --update --no-cache tzdata

# TODO: 
# You can edit the following lines to copy your java app, libs, jars etc 
# and start on load

# 1. add your java application here
#ADD /path/to/your/java/app /home/yourapp

# 2. start your applicaiton on forground
#CMD ["/home/yourapp/bin/start.sh", "args"]
