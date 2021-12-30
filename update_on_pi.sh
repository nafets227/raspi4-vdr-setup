#!/bin/bash

# Setup Pi4 with vdr and latest softhddevice.drm plugin
# for discussion see https://www.vdr-portal.de/forum/index.php?thread/132858-raspberry-pi-4b-unterstützung/

function piwozi-verify-os {
	. /etc/os-release || return 1

	if [ "$ID" != "raspbian" ] ; then
		printf "Error: Unsupported Linux Distribution %s (only raspbian supported)\n" \
			"$ID"
		return 1
	elif [ "$VERSION_ID" != "11" ] ; then
		printf "Error. Unsupported raspbian version %s (only 11 supported)\n" \
			"$VERSION_ID"
		return 1
	fi

	return 0
}

function piwozi-updatesysconfig {
	sudo apt-get --yes install \
		cec-utils \
		ffmpeg \
		git \
		libcec-dev \
		libp8-platform-dev \
		|| return 1

	return 0
}

function piwozi-install-vdr {
	sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install \
		vdr vdr-dev \
		libavcodec-dev libavfilter-dev libavformat-dev \
		libasound2-dev libdrm-dev \
		libpugixml-dev && \
	true || return 1


	if ! [ -d vdr-plugin-softhddevice-drm ] ; then
		git clone https://github.com/zillevdr/vdr-plugin-softhddevice-drm.git --depth 10 &&
		cd vdr-plugin-softhddevice-drm &&
		true || return 1
	else
		cd vdr-plugin-softhddevice-drm &&
		git pull --ff-only &&
		true || return 1
	fi


	make -j$(nproc) &&
	sudo make install &&
	cd .. &&
	true || return 1

	if ! [ -d vdr-plugin-cecremote ] ; then
		git clone https://git.uli-eckhardt.de/vdr-plugin-cecremote.git &&
		cd vdr-plugin-cecremote &&
		true || return 1
	else
		cd vdr-plugin-cecremote &&
		git pull --ff-only &&
		true || return 1
	fi

	make -j$(nproc) &&
	sudo make install &&
	cd .. &&
	true || return 1

	return 0
}

function piwozi-install-vdradmin {
	sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install vdradmin-am &&

	sudo bash -c "cat >/var/lib/vdradmin-am/vdradmind.conf" <<-EOF &&
		PASSWORD = linvdr
		USERNAME = linvdr
		VDRCONFDIR = /var/lib/vdr
		VDR_HOST = localhost
		VDR_PORT = 6419
		VIDEODIR = /var/lib/video
		EOF

	sudo bash -c "cat >/etc/systemd/system/vdradmin-am.service" <<-EOF &&
		[Unit]
		Description=VDRAdmin-AM
		After=vdr.service

		[Service]
		# run as root user to enable creating needed directories.
		# User=vdr
		# ExecStartPre=mkdir -p /run/vdradmin /etc/vdradmin /var/cache/vdradmin /var/log/vdradmin /var/run/vdradmin
		ExecStart=/usr/bin/vdradmind -n

		[Install]
		WantedBy=multi-user.target
		EOF

	sudo systemctl daemon-reload &&
	sudo systemctl enable vdradmin-am &&
	sudo systemctl start vdradmin-am &&

	true || return 1

	return 0
}

function piwozi-sysconfig {
	# first enable groupmems without asking even root for its password
	sudo bash -c "cat >/etc/pam.d/groupmems" <<-EOF &&
		auth       sufficient pam_rootok.so
		EOF

	sudo groupmems -g audio -l | grep vdr || \
	sudo groupmems -g audio -a vdr &&

	sudo bash -c "cat >/etc/vdr/conf.d/99-nafets.conf" <<-EOF &&
		[softhddevice-drm]
		-a default:CARD=vc4hdmi0

		[cecremote]
		EOF

	sudo bash -c "cat >/etc/sudoers.d/011_vdrshutdown" <<-EOF &&
		vdr ALL=(ALL) NOPASSWD: ALL
		EOF

	sudo bash -c "cat >/etc/vdr/shutdown-hooks/S90.custom" <<-EOF &&
		printf "SHUTDOWNCMD='sudo systemctl poweroff'"
		exit 0
		EOF

	# @TODO set in /etc/vdr/setup.conf
	# MinEventTimeout = 0
	# MinUserInactivity = 0

	true || return 1

	return 0
}

##### main ####################################################################

pushd "$HOME"

if [ "$#" == "0" ] ; then # no parameter given -> defaults to install all
	piwozi-verify-os &&
	piwozi-updatesysconfig &&
	piwozi-install-vdr &&
	piwozi-sysconfig &&
	piwozi-install-vdradmin
else
	"$@"
fi

rc=$?
popd

if [ "$rc" -eq 0 ] ; then
	printf "==== %s ended successfully =====\n" "$0"
	exit 0
else
	printf "===== %s ended in ERROR =====\n" "$0"
	exit 1
fi
