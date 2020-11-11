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

WORKDIR /home/$USER

## Copy RCU source

# NOTE: the created files are owned by root.
COPY /rcu rcu
WORKDIR /home/$USER/rcu/src

# Copy the license file so that RCU can display it in "About RCU" pane -> "Licenses" tab.
# The text differs from that of 3.8.5 packaged with the RCU source: for example, this here
# has a "Debian packaging" header, a section "A. HISTORY OF THE SOFTWARE" (noted as "as
# found in LICENSE in the original source" though) and is shorter (~320 lines vs. ~800).
# However, we *are* using the packaged Python, so it seems reasonable to present to the user
# the according license.
RUN cp -a /usr/share/doc/python3/copyright licenses/COPYING_PYTHON_3_8_6

USER $USER
