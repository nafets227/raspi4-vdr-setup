#!/bin/bash

# Setup Pi4 with vdr and latest softhddevice.drm plugin
# for discussion see https://www.vdr-portal.de/forum/index.php?thread/132858-raspberry-pi-4b-unterstützung/

function piwozi-updatesysconfig {
	sudo SKIP_WARNING=1 rpi-update &&

	# we replace existing /boot/config.txt, default can be restored by deleting and
	# reinstalling the package raspberrypi-bootloader
	sudo bash -c "cat >/boot/config.txt" <<-EOF &&
		# Version by Stefan Schallenberg install script
		#### comment dtoverlay=vc4-fkms-3d above
		dtoverlay=vc4-kms-v3d-pi4,cma-512
		dtoverlay=rpivid-v4l2
		disable_overscan=1
		disable_fw_kms_setup=1
		# End Stefan Schallenberg 2.1.2021
		EOF

	# disabble resize root fs that is failing on NFS root
	sudo update-rc.d resizfe2fs_once remove &&
	true || return 1

	[ ! -f /etc/init.d/resizfe2fs_once ] ||
	sudo rm /etc/init.d/resize2fs_once || return 1

	if ! [ -d linux ] ; then
		git clone https://github.com/raspberrypi/linux --branch rpi-5.10.y --single-branch &&
		cd linux &&
		true || return 1
	else
		cd linux &&
		git pull --ff-only &&
		true || return 1
	fi

	sudo make headers_install INSTALL_HDR_PATH=/usr &&
	cd .. &&

	true || return 1

	return 0
}

##### Build and install updated FFMpeg #######################################
# @TODO maybe create an own Debian package. See
# Debian package git: https://salsa.debian.org/multimedia-team/ffmpeg.git
# for the official debian package as base.
# call as pi in its home directory!
function piwozi-rebuild-fmpeg {

	# enable source handling with apt
	if ! fgrep "Stefan Schallenberg" /etc/apt/sources.list ; then
		sudo bash -c "cat >>/etc/apt/sources.list" <<-EOF &&
			# Stefan Schallenberg 2.1.2021
			deb-src http://raspbian.raspberrypi.org/raspbian/ buster main contrib non-free rpi
			EOF
		sudo apt-get update &&
		true || return 1
	fi

# no longer needed:
#	# install prereqs of standard Debian package
#	sudo apt-get build-dep ffmpeg &&

	# install needed tools
	sudo apt-get install autoconf libtool &&

	# additional prereq: librtmp
	sudo apt-get install librtmp-dev &&

	true || return 1
	# additional prereq: fdk-aac
	if ! [ -d fdk-aac ] ; then
		git clone https://github.com/mstorsjo/fdk-aac.git &&
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
		git clone https://github.com/ultravideo/kvazaar.git &&
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
		git clone https://github.com/sekrit-twc/zimg.git &&
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
			--branch dev/4.3.1/drm_prime_1 \
			--single-branch &&
		cd rpi-ffmpeg &&
		true || return 1
	else
		cd rpi-ffmpeg &&
		git pull --ff-only &&
		true || return 1
	fi
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
	[ -e Makefile ] || ./configure \
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

	sudo apt remove \
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

	true || return 1

	return 0
}

function piwozi-install-vdr {
	sudo apt install vdr vdr-dev &&

	# vdr-plugin-softhddevice-drm needs libchromaprint1

	# Alternative to compiling chromaprint is to patch /var/lib/dpkg/status
	# to delete dependencies to libav* of libchromaprint
	# libchromaprint1 and libchromaprint-dev can then be installed using
	# apt-get download ... ; dpkg -i ...
	# warning about no being able to configure packages can be ignored

	# But for now we compile chromaprint:
	sudo apt-get install cmake || return 1
	if ! [ -d chromaprint ] ; then
		git clone https://github.com/acoustid/chromaprint.git &&
		cd chromaprint &&
		true || return 1
	else
		cd chromaprint &&
		git pull --ff-only &&
		true || return 1
	fi
	cmake -DHAVE_AV_FRAME_ALLOC=1 -DHAVE_AV_FRAME_FREE=1 . &&
	make -j${nproc} &&
	sudo make install &&
	cd .. &&

	true || return 1


	if ! [ -d vdr-plugin-softhddevice-drm ] ; then
		git clone https://github.com/zillevdr/vdr-plugin-softhddevice-drm.git &&
		cd vdr-plugin-softhddevice-drm &&
		true || return 1
	else
		cd vdr-plugin-softhddevice-drm &&
		git pull --ff-only &&
		true || return 1
	fi

	make -j${nproc} &&
	sudo make install &&

	true || return 1

	return 0
}

function piwozi-install-vdradmin {
	if ! [ -d vdradmin-am ] ; then
		git clone https://projects.vdr-developer.org/git/vdradmin-am.git
		cd vdradmin-am &&
		true || return 1
	else
		cd vdradmin-am &&
		git pull --ff-only &&
		true || return 1
	fi

	sudo bash -c "cat >/etc/vdradmin/vdradmind.conf" <<-EOF &&
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
		ExecStartPre=mkdir -p /run/vdradmin /etc/vdradmin /var/cache/vdradmin /var/log/vdradmin /var/run/vdradmin
		ExecStart=/usr/bin/vdradmind -n

		[Install]
		WantedBy=multi-user.target
		EOF
	sudo rm -rf /usr/share/vdradmin &&
	sudo ./install.sh &&
	true || return 1


	return 0
}

function piwozi-sysconfig {
	sudo groupmod -g 666 vdr &&
	sudo usermod -u 666 vdr &&

	sudo groupmems -g audio -l | grep vdr || \
	sudo groupmems -g audio -a vdr &&

	sudo bash -c "cat >/etc/vdr/conf.d/99-nafets.conf" <<-EOF &&
		[softhddevice-drm]
		EOF

	true || return 1

	return 0
}

function piwozi-patch {
	sudo bash -c "cat >/lib/udev/rules.d/91-pulseaudio-rpi.rules" <<-EOF &&
		SUBSYSTEM!="sound*", GOTO="end"
		ACTION!="change", GOTO="end"
		KERNEL!="card*", GOTO="end"
		ENV{SOUND_FORM_FACTOR}!="internal", GOTO="end"

		ATTRS{id}=="b1", ENV{PULSE_PROFILE_SET}="rpi-hdmi.conf", GOTO="end"
		ATTRS{id}=="b2", ENV{PULSE_PROFILE_SET}="rpi-hdmi.conf", GOTO="end"
		ATTRS{id}=="Headphones", ENV{PULSE_PROFILE_SET}="rpi-analog.conf", GOTO="end"

		LABEL="end"
		EOF

	sudo bash -c "cat >/usr/share/alsa/cards/vc4-hdmi.conf" <<-"EOF" &&
		# Configuration for the VC4-HDMI sound card using software IEC958
		# subframe conversion

		<confdir:pcm/hdmi.conf>
		vc4-hdmi.pcm.hdmi.0 {
			@args [ CARD AES0 AES1 AES2 AES3 ]
			@args.CARD {
				type string
			}
			@args.AES0 {
				type integer
			}
			@args.AES1 {
				type integer
			}
			@args.AES2 {
				type integer
			}
			@args.AES3 {
				type integer
			}
			type iec958
			slave {
				format IEC958_SUBFRAME_LE
				pcm {
					type hooks
					slave.pcm {
						type hw
						card $CARD
						device 0
					}
					hooks.0 {
						type ctl_elems
						hook_args [
						{
							name "IEC958 Playback Default"
							optional true
							lock true
							preserve true
							value [ $AES0 $AES1 $AES2 $AES3 ]
						}
						]
					}
				}
			}
			status [ $AES0 $AES1 $AES2 $AES3 ]
		}

		# default with plug
		vc4-hdmi.pcm.default {
			@args [ CARD ]
			@args.CARD {
				type string
			}
			type plug
			slave.pcm {
				type softvol
				slave.pcm {
					@func concat
					strings [ "hdmi:" $CARD ]
				}
				control {
					name "PCM Playback Volume"
					card $CARD
				}
			}
		}
		EOF
	true || return 1

	return 0
}

##### main ####################################################################

pushd "$HOME"
piwozi-updatesysconfig &&
piwozi-patch &&
piwozi-rebuild-fmpeg &&
piwozi-install-vdr &&
piwozi-sysconfig &&
piwozi-install-vdradmin

rc=$?
popd

if [ "$rc" -eq 0 ] ; then
	printf "==== %s ended successfully =====\n" "$0"
	exit 0
else
	printf "===== %s ended in ERROR =====\n" "$0"
	exit 1
fi
