# raspi4-vdr-setup
This repository contains a script to automatize the setup of
[vdr](http://www.tvdr.de) 
with the plugin
[softhddevice-drm](https://github.com/zillevdr/vdr-plugin-softhddevice-drm) 
on a Raspberry Pi 4.
## How to use
1. Download and install 
[RaspiOS](https://www.raspberrypi.org/software/operating-systems/#raspberry-pi-os-32-bit) 
on your machine, any variant (lite, with Destop, with Desktop and recommended software) should do.
1. Backup your system. You REALLY should do this, as the script is partially running with root rights and may destroy your system.
1. Next, download the update_on_pi.sh and execute it as user pi. It will sudo to root whenever needed and download, compile and install all needed software.
1. reboot (just to be safe)
1. start vdr and watch TV or your recordings!
## Reporting Issues
If you find any issue, please start the script with

    bash -c "set -x ; . ./update_on_pi.sh"

and create an issue in github attaching the log
# Advanced use
## Prepare SD Card on x86
Using qemu-static-bin and binfmt-qemu packages on a box running Linux x86 you can prepare a SD-Card (or even  NFS root) without touching your Raspi.
After installing the qemu packages do the following:
1. download root.tar.xz and boot.tar.xz from the [RaspiOS Download Page](https://www.raspberrypi.org/software/operating-systems/#raspberry-pi-os-32-bit)
1. If using a SD Card, mount it on your x86 Linux system, the following example will assume its mounted on /mnt
1. unpack root.tar.xz into /mnt
1. unpack boot.tar.xz into /mnt/boot
1. copy update_on_pi.sh to /mnt/boot/home/pi
1. chroot into /mnt and change user to pi (on Arch Linux use `arch-chroot /mnt su pi` )
1. call update_on_pi.sh
1. exit from chroot
1. umnount /mnt and move it to your raspi4
## Partial execution
This step requires some bash script knowledge.
You can start the script with a parameter, that is the subfunction to exit (look for function in the script), e.g.

    ./update_on_pi.sh piwozi_install_vdr

It is useful when recovering from previous errors without waiting for all the lengthy procedures that already executed ok.
## FFMpeg configuration
The script configures ffmpeg with the options used in RaspiOS plus, adding some modifications to support Raspi4 Hardware. You could also want to use a "minimal" ffmpeg setup, but this is not supported by the script as of now
# References and Contributions
This script just puts together the wonderful work of a lot of people, listed below in the order of installation
1. [rpi-update](https://github.com/Hexxeh/rpi-update)
to update RaspiOS Kernel to the latest development version 5.10.y
1. [RaspiOS development kernel](https://github.com/raspberrypi/linux)
is included in rpi-update above, but we need to separately install the Kernel headers
1. [ffmpeg-rpi](https://github.com/jc-kynesim/rpi-ffmpeg)
is a fork of ffmpeg that has specific features not yet merged back into upstream ffmpeg
1. [vdr] is a Video Disk Recorder, we install it from RaspiOS package
1. [vdr-plug-softhddevice-drm](https://github.com/zillevdr/vdr-plugin-softhddevice-drm) is one (of many) forks from the vdr plugin softhddevice. It support drm, that is the technology used on Raspi4. Be aware that for Raspi 1-2 there is also vdr-plugin-rpihddevice
1. Special Thanks goes to all Testers and supporters that helped develop this script, mainly in the
[VDR-Portal Forum](https://www.vdr-portal.de/forum/index.php?thread/132858-raspberry-pi-4b-unterstützung)
1. [vdr-admin](http://andreas.vdr-developer.org) is a Web Interface to VDR. We install ist from RaspiOS package.