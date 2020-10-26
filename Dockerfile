FROM ubuntu:20.10

LABEL maintainer="Philipp Kutin <philipp.kutin@gmail.com>"

RUN apt update

## RCU runtime dependencies

RUN apt install -y language-pack-en-base

RUN apt install -y libgl1
# r2020.003:
RUN apt install -y libxcb-xinerama0 fontconfig

## Required Python modules

RUN bash -c "apt install -y python3-pyside2.qt{core,gui,widgets,svg,network,printsupport,uitools,xml}"
RUN bash -c "apt install -y python3-{paramiko,pdfrw}"

## Set up the user and environment

ARG UID
ARG USER
RUN adduser --disabled-password --uid $UID $USER

ENV DISPLAY=:0
ENV LANG=en_US.UTF-8

USER $USER
WORKDIR /home/$USER

## Copy RCU source

COPY /rcu rcu
WORKDIR /home/$USER/rcu/src
