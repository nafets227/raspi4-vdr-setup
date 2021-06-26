#!/bin/bash

# Setup Pi4 with vdr and latest softhddevice.drm plugin
# for discussion see https://www.vdr-portal.de/forum/index.php?thread/132858-raspberry-pi-4b-unterstützung/

function piwozi-updatesysconfig {
	# we replace existing /boot/config.txt, default can be restored by deleting and
	# reinstalling the package raspberrypi-bootloader
	sudo bash -c "cat >/boot/config.txt" <<-EOF &&
		# Version from nafets227/raspi-by Stefan Schallenberg install script
		#### comment dtoverlay=vc4-fkms-3d above
		dtoverlay=vc4-kms-v3d-pi4,cma-512
		dtoverlay=rpivid-v4l2
		disable_fw_kms_setup=1
		# End Version from nafets227/raspi-by Stefan Schallenberg install script
		EOF

	sudo apt-get --yes install git || return 1

	return 0
}

##### Build and install updated FFMpeg #######################################
# @TODO maybe create an own Debian package. See
# Debian package git: https://salsa.debian.org/multimedia-team/ffmpeg.git
# for the official debian package as base.
# call as pi in its home directory!
function piwozi-rebuild-ffmpeg {

	# enable source handling with apt
	if ! fgrep "Stefan Schallenberg" /etc/apt/sources.list ; then
		sudo bash -c "cat >>/etc/apt/sources.list" <<-EOF &&
			# Stefan Schallenberg 2.1.2021
			deb-src http://raspbian.raspberrypi.org/raspbian/ buster main contrib non-free rpi
			EOF
		sudo apt-get update &&
		true || return 1
	fi

	# install prereqs of standard Debian package
	sudo apt-get --yes build-dep ffmpeg &&

	# install needed tools
	# additional prereq: librtmp
	sudo apt-get --yes install \
		autoconf \
		frei0r-plugins-dev \
		ladspa-sdk \
		libaom-dev \
		libc6-dev \
		libcdio-paranoia-dev \
		librtmp-dev \
		libtool \
		&&

	true || return 1

	# Alternative to compiling chromaprint is to patch /var/lib/dpkg/status
	# to delete dependencies to libav* of libchromaprint
	# libchromaprint1 and libchromaprint-dev can then be installed using
	# apt-get download ... ; dpkg -i ...
	# warning about no being able to configure packages can be ignored

	# But for now we compile chromaprint:
	sudo apt-get --yes install cmake || return 1
	if ! [ -d chromaprint ] ; then
		git clone https://github.com/acoustid/chromaprint.git &&
		cd chromaprint &&
		true || return 1
		# Start cmake first time to workaround a bug when running
		# in qemu-static-bin
		# https://bugs.launchpad.net/qemu/+bug/1805913
		# https://gitlab.kitware.com/cmake/cmake/-/issues/20568
		cmake -DHAVE_AV_FRAME_ALLOC=1 -DHAVE_AV_FRAME_FREE=1 .
	else
		cd chromaprint &&
		git pull --ff-only &&
		true || return 1
	fi
	cmake -DHAVE_AV_FRAME_ALLOC=1 -DHAVE_AV_FRAME_FREE=1 . &&
	make -j$(nproc) &&
	sudo make install &&
	cd .. &&
	true || return 1

	# additional prereq: fdk-aac
	if ! [ -d fdk-aac ] ; then
		git clone https://github.com/mstorsjo/fdk-aac.git --depth 10 &&
		cd fdk-aac &&
		true || return 1
	else
		cd fdk-aac &&
		git pull --ff-only &&
		true || return 1
	fi
	[ -e ./configure ] || ./autogen.sh || return 1
	[ -e Makefile ] || ./configure --enable-shared || return 1
	make -j$(nproc) &&
	sudo make install &&
	cd .. || return 1

	# additional prereq: kvazaar
	if ! [ -d kvazaar ] ; then
		git clone https://github.com/ultravideo/kvazaar.git --depth 10 &&
		cd kvazaar &&
		true || return 1
	else
		cd kvazaar &&
		git pull --ff-only &&
		true || return 1
	fi
	[ -e ./configure ] || ./autogen.sh || return 1
	[ -e Makefile ] || ./configure --enable-shared || return 1
	make -j$(nproc) &&
	sudo make install &&
	cd .. || return 1

	# additional prereq: zimg
	if ! [ -d zimg ] ; then
		git clone https://github.com/sekrit-twc/zimg.git --depth 10 &&
		cd zimg &&
		true || return 1
	else
		cd zimg &&
		git pull --ff-only &&
		true || return 1
	fi
	[ -e ./configure ] || ./autogen.sh || return 1
	[ -e Makefile ] || ./configure --enable-shared || return 1
	make -j$(nproc) &&
	sudo make install &&
	cd .. || return 1

	##### now ffmpeg itself ##########
	if ! [ -d rpi-ffmpeg ] ; then
		git clone https://github.com/jc-kynesim/rpi-ffmpeg.git \
			--depth 10 \
			--branch dev/4.3.1/drm_prime_1 \
			&&
		cd rpi-ffmpeg &&
		true || return 1
	else
		cd rpi-ffmpeg &&
		git pull --ff-only &&
		true || return 1
	fi
	sed -i 's#<drm/drm_fourcc.h#<libdrm/drm_fourcc.h#' \
		libavutil/hwcontext_drm.c \
		|| return 1

#	       	--libdir=/usr/lib/arm-linux-gnueabihf
#	       	--cpu=arm1176jzf-s
#	       	--arch=arm
#		--prefix=/usr @TODO needed???
#		--toolchain=hardened
#		--incdir=/usr/include/arm-linux-gnueabihf

# @TODO solve dependencies and readd:
#	       	--enable-avisynth \
#	       	--enable-libmysofa \

# needed ??
#--extra-libs="-lpthread -lm -latomic -lbcm_host -lvcos -lvchiq_arm" \
#--extra-ldflags="-L/usr/local/lib -L/opt/vc/lib" \
#		-lvcos -lvchiq_arm" \
	[ -e config.h ] || ./configure \
		--extra-version='-rpi+beta' \
		--extra-ldflags="-L/opt/vc/lib" \
		--extra-libs="-lbcm_host -lvcos" \
	       	--enable-shared \
	       	--enable-gpl \
	       	--enable-gnutls \
	       	--enable-libx265 \
		\
	       	--disable-stripping \
	       	--enable-avresample \
	       	--disable-filter=resample \
	       	--enable-ladspa \
	       	--enable-libaom \
	       	--enable-libass \
	       	--enable-libbluray \
	       	--enable-libbs2b \
	       	--enable-libcaca \
	       	--enable-libcdio \
	       	--enable-libcodec2 \
	       	--enable-libflite \
	       	--enable-libfontconfig \
	       	--enable-libfreetype \
	       	--enable-libfribidi \
	       	--enable-libgme \
	       	--enable-libgsm \
	       	--enable-libjack \
	       	--enable-libmp3lame \
	       	--enable-libopenjpeg \
	       	--enable-libopenmpt \
	       	--enable-libopus \
	       	--enable-libpulse \
	       	--enable-librsvg \
	       	--enable-librubberband \
	       	--enable-libshine \
	       	--enable-libsnappy \
	       	--enable-libsoxr \
	       	--enable-libspeex \
	       	--enable-libssh \
	       	--enable-libtheora \
	       	--enable-libtwolame \
	       	--enable-libvidstab \
	       	--enable-libvorbis \
	       	--enable-libvpx \
	       	--enable-libwavpack \
	       	--enable-libwebp \
	       	--enable-libxml2 \
	       	--enable-libxvid \
	       	--enable-libzmq \
	       	--enable-libzvbi \
	       	--enable-lv2 \
	       	--enable-omx \
	       	--enable-openal \
	       	--enable-opengl \
	       	--enable-sdl2 \
	       	--enable-omx-rpi \
	       	--enable-mmal \
	       	--enable-neon \
	       	--enable-rpi \
	       	--enable-libdc1394 \
	       	--enable-libdrm \
	       	--enable-libiec61883 \
	       	--enable-chromaprint \
	       	--enable-frei0r \
	       	--enable-libx264 \
		\
		--enable-sand \
		--enable-v4l2_m2m \
		--enable-v4l2-request \
		--enable-libudev \
		--enable-libdrm \
		--disable-rpi \
		--enable-gpl \
		--enable-pic \
		--enable-avfilter \
		--enable-nonfree \
		--enable-gpl \
		--enable-iconv \
		--enable-network \
		--enable-pthreads \
		--disable-vdpau \
		--disable-vaapi \
		--enable-libopencore-amrnb \
		--enable-libopencore-amrwb \
		--enable-version3 &&
	make -j$(nproc) &&

	sudo apt --yes remove \
		ffmpeg \
		ffmpeg-doc \
		libavcodec-dev \
		libavcodec-extra \
		libavcodec-extra58 \
		libavcodec58 \
		libavdevice-dev \
		libavdevice58 \
		libavfilter-dev \
		libavfilter-extra \
		libavfilter-extra7 \
		libavfilter7 \
		libavformat-dev \
		libavformat58 \
		libavresample-dev \
		libavresample4 \
		libavutil-dev \
		libavutil56 \
		libpostproc-dev \
		libpostproc55 \
		libswresample-dev \
		libswresample3 \
		libswscale-dev \
		libswscale5 \
		&&

	sudo make install &&
	cd .. &&

	true || return 1

	return 0
}

function piwozi-install-libcec {
	# dont use standard libcec, since too old and not enable Linux API:
	# sudo apt-get --yes install libcec-dev cec-utils libp8-platform-dev

	sudo apt-get --yes install \
		cmake \
		libp8-platform-dev \
		libudev-dev \
		libxrandr-dev \
		python-dev \
		swig &&
	true || return 1

	if ! [ -d libcec ] ; then
		git clone https://github.com/Pulse-Eight/libcec.git --depth 10 &&
		cd libcec &&
		true || return 1
	else
		cd libcec &&
		git pull --ff-only &&
		true || return 1
	fi

	mkdir -p build &&
	cd build &&
	# retry cmake 2 times, dont know why 1st time fails.
	( CMAKE_PREFIX_PATH=/usr/lib/arm-linux-gnueabihf/p8-platform \
	cmake -DHAVE_LINUX_API=1 .. ||
	CMAKE_PREFIX_PATH=/usr/lib/arm-linux-gnueabihf/p8-platform \
	cmake -DHAVE_LINUX_API=1 .. ) &&
	make -j$(nproc) &&
	sudo make install &&
	cd ../.. &&

	true || return 1

	return 0
}

function piwozi-install-vdr {
	sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install vdr vdr-dev &&

	# vdr-plugin-softhddevice-drm needs libchromaprint1

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
		-a iec958
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
	piwozi-updatesysconfig &&
	piwozi-rebuild-ffmpeg &&
	piwozi-install-libcec &&
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
