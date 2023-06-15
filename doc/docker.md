Upsilon docker development environment setup.

# Setup steps

Change directory to `build`.

## Installing OpenFPGALoader

Install [openFPGALoader][1]. This utility entered the Ubuntu repositories
in 23.04. Install and compile it if you do not have it. Install the udev rule
so that admin access is not required to load FPGA bitstreams.

[1]: https://trabucayre.github.io/openFPGALoader/index.html

## Setup Rootless Docker

Docker allows you to run programs in containers, which are isolated
environments. Upsilon development (at the Maglab) uses Docker for
reproducibility: the environment can be set up automatically, and re-setup
whenever needed.

If you have issues with docker, try adding to `~/.config/docker/daemon.json`

    {
       "storage-driver": "fuse-overlayfs"
    }


## Download and Install Python3

Install `python3-venv` (or `python3-virtualenv`) and `python3-pip`.

## Clone External Repositories

Run `make clone`. You may need to download the upsilon repositories
and put them in the same folder as the Makefile.

## Setup Network

Plug in your router/switch to an ethernet port on your computer. If your
computer is usually wired to the network, you will need another ethernet
port (a PCI card is ideal, but a USB-Ethernet port works).

Set the ethernet port to static ip `192.168.1.100/24`, netmask 255.255.255.0,
gateway `192.168.1.1`. Make sure this is not the default route. Make sure
to adjust your firewall to allow traffic on the 192.168.1.0/24 range.

If your local network already uses the 192.168.1.0/24 range, then you must
modify `upsilon/firmware/soc.py` to use different IPs. You must rebuild the
SoC after doing this.

## Setup Images

Run `make images` to create all docker images.

## Setup and Run Containers

For `NAME` in `hardware`, `opensbi`, `buildroot`:

1. Run `make $NAME-container` to build the container. You usually only need
   to do this once.
2. If the container already exists, do `docker container start upsilon-$NAME`.
3. Run `make $NAME-copy` to copy Upsilon's code into the container.
4. Run `make $NAME-execute` to build the data.
5. Run `make $NAME-get` to retrieve the build artefacts.

If you do not delete the container you can run

	make $NAME-copy $NAME-execute $NAME-get

when you need to rebuild. If you need shell access, run `make $NAME-shell`.

## Flash FPGA

Plug in your FPGA into the USB slot. Then run

	openFPGALoader -c digilent upsilon/boot/digilent_arty.bit

## Launch TFTP Server

Install py3tftp (`pip3 install --user py3tftp`). Then run `make tftp` to
launch the TFTP server. Keep this terminal open.

## Launch FPGA Shell

Run `litex_term /dev/ttyUSB1`. You should get messages in the window with
the TFTP server that the FPGA has connected to the server. Eventually you
will get a login prompt: you have sucessfully loaded Upsilon onto your FPGA.

## SSH Access

Add the following to your SSH config:

	Host upsilon
		HostName 192.168.1.50
		StrictHostKeyChecking no
		UserKnownHostsFile /dev/null
		User root
		LogLevel QUIET

When the FPGA is connected you can access it with `ssh upsilon` (password
`upsilon`).
