ARG BASE_IMAGE
FROM $BASE_IMAGE

LABEL maintainer="Philipp Kutin <philipp.kutin@gmail.com>"

RUN apt update

## RCU runtime dependencies

# Install only the one necessary additional locale (code from Ubuntu at Docker Hub):
RUN apt install -y locales && \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

RUN apt install -y libgl1
# r2020-003:
RUN apt install -y libxcb-xinerama0 fontconfig

# Required Python modules
RUN bash -c "apt install -y python3-pyside2.qt{core,gui,widgets,svg,network,printsupport,uitools,xml}"
ARG ADDITIONAL_PACKAGES
RUN apt install -y $ADDITIONAL_PACKAGES

# imx_usb_loader:
RUN apt install -y libusb-1.0-0 sudo

## Set up the user and environment

ARG UID
ARG USER
RUN adduser --disabled-password --uid $UID $USER
# Allow the non-root user to invoke 'sudo' without password:
RUN adduser $USER sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

ENV DISPLAY=:0
ENV LANG=en_US.UTF-8

## Copy RCU source
WORKDIR /usr/local
COPY /rcu rcu

# imx_usb_loader: the version provided by reMarkable (commit 7f4809a8e6) differs from the
#  point where it branched off (commit 48a85c0b84) only in the configuration (*.conf) and
#  the U-Boot/Linux/device-tree/initramfs binaries, not in the application code itself.
#  Since we'll be using those of RCU, check out that base. Upstream master does not work as
#  of commit 30b43d6977 (May 17 2020; note, imx_usb_loader is deprecated in favor of 'uuu').

USER $USER
WORKDIR /home/$USER/temp

RUN sudo chown $USER:$USER . && \
	sudo apt install -y git make pkg-config gcc libusb-1.0-0-dev && \
	git clone https://github.com/boundarydevices/imx_usb_loader.git && \
	cd imx_usb_loader && \
	git checkout 48a85c0b84611c089cf870638fd1241619324b1d && \
	make imx_usb && \
	mkdir /tmp/imx_usb_build && mv imx_usb /tmp/imx_usb_build && \
	cd .. && rm -rf imx_usb_loader && \
	sudo apt remove -y git make pkg-config gcc libusb-1.0-0-dev && \
	sudo apt autoremove -y

ARG IMX_USB_SHA256
RUN sha256sum /tmp/imx_usb_build/imx_usb | grep -q "$IMX_USB_SHA256"

USER root
WORKDIR /usr/local/rcu/src

# Move over the 'imx_usb' binary built above.
RUN chown root:root /tmp/imx_usb_build/imx_usb && \
	mv /tmp/imx_usb_build/imx_usb /usr/local/rcu/recovery_os_build/imx_usb.linux && \
	rmdir /tmp/imx_usb_build

# Copy the license file so that RCU can display it in "About RCU" pane -> "Licenses" tab.
# The text differs from that of 3.8.5 packaged with the RCU source: for example, this here
# has a "Debian packaging" header, a section "A. HISTORY OF THE SOFTWARE" (noted as "as
# found in LICENSE in the original source" though) and is shorter (~320 lines vs. ~800).
# However, we *are* using the packaged Python, so it seems reasonable to present to the user
# the according license.
RUN cp -a /usr/share/doc/python3/copyright licenses/COPYING_PYTHON_3_9_7

USER $USER
