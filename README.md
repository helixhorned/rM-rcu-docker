
rM-rcu-docker: reMarkable Connection Utility in a Docker wrapping
=================================================================

Introduction
------------

[reMarkable Connection Utility]: http://www.davisr.me/projects/rcu/

`rM-rcu-docker` allows to run the [reMarkable Connection Utility] natively on non-x86_64
devices by installing it together with its dependencies inside a Docker container. The
primary targets are Linux distributions for AArch64 hardware, in particular the various
Raspberry Pi models.


Requirements
------------

[official Ubuntu Docker image]: https://hub.docker.com/_/ubuntu
[Docker issue 40734]: https://github.com/moby/moby/issues/40734
[beta 64-bit Arm version]: https://downloads.raspberrypi.org/raspios_arm64/images/

* A supported combination of OS and processor architecture <sup>**[1]**</sup>
* Docker
* The source archive for a supported RCU release
* sufficient disk space for the created Docker image (order of magnitude: 1 GB)

<sup>**[1]**</sup> <small>The `Dockerfile` itself is based on an Ubuntu image. In theory,
this allows to create images based on it on any processor architecture for which there is an
[official Ubuntu Docker image], assuming that all required packages are available. However,
there are practical limitations:

1. In order for the backup functionality to work (**EXPERIMENTAL** here!), some host-side
   setup is first needed. Currently, it is specific to Linux and there are no plans for
   other OSs.

2. The build of `imx_usb` carried out in the container is verified by comparing its SHA256
   to known values, which currently are available only on architectures `aarch64` and
   `x86_64`.

3. Docker on 32-bit Raspberry Pi OS is incapable of building the image due to [Docker issue
   40734]. However, Docker of the [beta 64-bit Arm version] builds and runs it successfully.
</small>


Building
--------

~~~~~~~~~~
Usage: ./build.sh <RCU source archive>

 Creates a Docker image with the reMarkable Connection Utility extracted
 from the provided archive and all of its runtime dependencies installed.

 The image is based on 'ubuntu:groovy-20210524' and named
 'remarkable-rcu:<tag>', where '<tag>' is e.g. 'r2021-001'.

 RCU can be obtained from the utility author's web page:
  http://www.davisr.me/projects/rcu/

 Source archives for RCU versions supported by this script are named:
  - source-rcu-r2020-003.tar.gz
  - rcu-r2021.001-source.tar.gz
 The actual version used is determined by a check on the SHA256 of the
 passed archive file, though.
~~~~~~~~~~


Running
-------

~~~~~~~~~~
Usage: ./run.sh [--shell|--help]

  A configuration file '$HOME/rcu-docker.conf'
  may be created manually containing lines of the form
      mount-ro=<directory-suffix>
  or
      mount-rw=<directory-suffix>
  (without leading whitespace) specifying directories under the
  host home directory to be mounted into the container.
  For each <directory-suffix>, the path '$HOME/<directory-suffix>'
  must be canonical: redundant slashes, symlinks, and '.' or '..'
  as components are not allowed.
~~~~~~~~~~


Acknowledgements
----------------

Davis Remmel for creating RCU in the first place, and for giving guidance on running the
utility on not officially supported platforms.


License
-------

Copyright (C) 2020-2021 Philipp Kutin.

Distributed under the terms of the [MIT license](LICENSE.MIT.txt).

**Note**: the reMarkable Connection Utility itself is distributed under a different license.
