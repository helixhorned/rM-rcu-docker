
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
[this Stack Overflow question]: https://stackoverflow.com/questions/66319610/gpg-error-in-ubuntu-21-04-after-second-apt-get-update-during-docker-build
[Ubuntu bug 1916485]: https://bugs.launchpad.net/ubuntu/+source/libseccomp/+bug/1916485
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
   setup is first needed. Currently, it is specific to Linux running the `systemd-udevd`
   service. There are no plans for other OSs.

2. The build of `imx_usb` carried out in the container is verified by comparing its SHA256
   to known values, which currently are available only on architectures `aarch64` and
   `x86_64`.

3. A reasonably recent Docker/`libseccomp` must be present on the host: the symptoms
   described in [this Stack Overflow question] have [Ubuntu bug 1916485] as the underlying
   issue. This rules out Raspberry Pi OS Legacy (based on Debian Buster). On 32-bit RPi OS
   Buster, Docker is incapable of building the image due to [Docker issue 40734] (not
   re-tested with Bullseye). Hence, the [beta 64-bit Arm version] is recommended, where it
   builds and runs successfully.

</small>


Building
--------

~~~~~~~~~~
Usage: ./build.sh <RCU source archive>

 Creates a Docker image with the reMarkable Connection Utility extracted
 from the provided archive and all of its runtime dependencies installed.

 The image is based on 'ubuntu:impish-20211102' and named
 'remarkable-rcu:<tag>', where '<tag>' is e.g. 'r2021-001'.

 RCU can be obtained from the utility author's web page:
  http://www.davisr.me/projects/rcu/

 Source archives for RCU versions supported by this script are named:
  - source-rcu-r2020-003.tar.gz
  - rcu-r2021.001-source.tar.gz
  - rcu-r2021.002-source.tar.gz
 The actual version used is determined by a check on the SHA256 of the
 passed archive file, though.
~~~~~~~~~~


Running
-------

~~~~~~~~~~
Usage: ./run.sh [--shell|--help|-- (args to RCU's main.py ...)]

  A configuration file '$HOME/.config/davisr/rcu-docker.conf'
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

### **EXPERIMENTAL**: Backup functionality

1. Read and on approval, run `setup_udev_rules.sh` which will set up
   `/etc/udev/rules.d/50-remarkable.rules`.
2. Shut down and restart the system for the rules to take effect.
3. It should now be possible to take backups, which will reside on the host's
   `$HOME/.local/share/davisr/rcu/backups`.

Depending on the networking setup of the host, manual intervention may be needed at most
twice (at the beginning and the end of the backup): if in the log, a message like

```
reconnecting to restore os...
Unable to connect to 10.11.99.1: [Errno 101] Network is unreachable
could not connect to the recovery os. 11 retries left
```

appears, on Debian-based systems (like Raspberry Pi OS) it should be resolved by an
invocation of `sudo dhclient`.


Acknowledgements
----------------

Davis Remmel for creating RCU in the first place, and for giving guidance on running the
utility on not officially supported platforms.


License
-------

Copyright (C) 2020-2021 Philipp Kutin.

Distributed under the terms of the [MIT license](LICENSE.MIT.txt).

**Note**: the reMarkable Connection Utility itself is distributed under a different license.
