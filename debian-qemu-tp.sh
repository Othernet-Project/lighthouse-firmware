#!/bin/bash

set -o errexit

# todo:
# remove nmap dep
# break out more things into variables
# test on OSX

# starting points:
# https://github.com/Outernet-Project/lighthouse-firmware
# https://people.debian.org/~aurel32/qemu/amd64/

# fork these repos and change the links for custom builds
github_repo="https://github.com/Outernet-Project/lighthouse-firmware.git"

SSH_ROOT="ssh -t -p 2224 -i root.key root@localhost"
SSH_USER="ssh -t -p 2224 -i user.key user@localhost"
SCP_USER="scp -P 2224 -i user.key"

# todo:
# http://libguestfs.org/virt-sparsify.1.html
# http://www.rushiagr.com/blog/2014/08/02/qcow2-mount/

docs()
{
    echo "KEY FILES"
    echo "debian_wheezy_amd64_standard.qcow2: contains the base OS and only the OS, immutable"
    echo "debian.package_overlay.qcow2: overlay of base OS, contains installed packages and OS tweaks"
    echo "debian.home.qcow2: contains home partition and crosstools"
    echo "debian.build_overlay.qcow2: overlay of home partition, contains lighthouse build"
    echo "firmware.git.tar.gz: cached tarball of 'git clone lighthouse-firmware'"
    echo "x-tools.bin.tar.gz: cached tarball of compiled crosstools"
    echo "downloads/*: cached copy of sources downloaded by crosstools and buildroot"
    echo ""
    echo "If you modify a base image (wheezy.qcow2 or home.qcow2) the respective overlay must be deleted and recreated"
    echo "So changing crosstools requires a clean_rebuild afterwards"
    echo ""
    echo "COMMANDS"
    echo "check_requirements: sees if you have everything required"
    echo "all: starting from a blank slate, make an image"
    echo "install_debian: create vm base image and package overlay"
    echo "create_home: create the home partition"
    echo "create_crosstools: repopulate the home partition with crosstools"
    echo "clean_rebuild: nuke and recreate build_overlay containing source code & image"
    echo "update_rebuild: pull latest changes and rebuild source code/image"
    echo "spin_down: shut down VM (if you ^C early or it hit an error)"
    echo "mess_around_in_build: for debugging, changes will be lost after update_rebuild"
}

check_requirements()
{
    echo "Build will require 10GB of disk and 5GB of ram"
    which wget 2> /dev/null || ( echo "install wget"; exit 1 )
    which ssh 2> /dev/null || ( echo "install ssh"; exit 1 )
    which qemu-system-x86_64 2> /dev/null || ( echo "install qemu"; exit 1 )
    which nmap 2> /dev/null || ( echo "install nmap"; exit 1 )
}

make_ssh_keys()
{
    if [[ ! -f user.key ]]; then
        echo "Creating user key..."
        ssh-keygen -t rsa -N '' -f user.key
    fi
    if [[ ! -f root.key ]]; then
        echo "Creating root key..."
        ssh-keygen -t rsa -N '' -f root.key
    fi
}

install_ssh_keys()
{
    echo "Installing root key.  Enter password 'root' when prompted"
    ssh-copy-id -i root.key.pub -p 2224 root@localhost
    echo "Installing user key.  Enter password 'user' when prompted"
    ssh-copy-id -i user.key.pub -p 2224 user@localhost
    echo "Thank you, almost everything should be automatic from here."
}

vm_ssh_wait()
{
    sleep 2
    echo -n 'Booting . . .'
    while true; do
        sleep 2
        echo -n ' .'
        ready="maybe"
        nmap -p 2224 127.0.0.1 | grep -q open || ready="no"
        if [[ "$ready" != "no" ]]; then
            echo -e '\nReady!'
            break
        fi
    done

}

spin_up_root()
{
    qemu-system-x86_64 -enable-kvm -display none -hda debian.package_overlay.qcow2 -m 1G -redir tcp:2224::22 &
    vm_ssh_wait
}

spin_up_home()
{
    qemu-system-x86_64 -enable-kvm -display none -hda debian.package_overlay.qcow2 -hdb debian.home.qcow2 -m 4G -smp 4 -redir tcp:2224::22 &
    vm_ssh_wait
}

spin_up_build()
{
    qemu-system-x86_64 -enable-kvm -display none -hda debian.package_overlay.qcow2 -hdb debian.build_overlay.qcow2 -m 4G -smp 4 -redir tcp:2224::22 &
    vm_ssh_wait
}

spin_down()
{
    $SSH_ROOT "poweroff"
    sleep 4
}

install_debian()
{
    # todo, figure out how to not make wget pause the install
    if [[ ! -e debian_wheezy_amd64_standard.qcow2 ]]; then
        wget https://people.debian.org/~aurel32/qemu/amd64/debian_wheezy_amd64_standard.qcow2
        chmod -w debian_wheezy_amd64_standard.qcow2
    fi

    check=$(md5sum < debian_wheezy_amd64_standard.qcow2)
    if [[ "$check" != "ceacf158c727c1bfcea3c83ea49ddb10  -" ]]; then
        echo "corrupt vm image"
        exit 1
    fi
    mkdir -p downloads

    # permissions
    if ! groups | grep -q kvm; then
        echo "add yourself to the kvm group"
        echo "sudo usermod -a -G kvm $USER"
    	#echo "sudo chmod 666 /dev/kvm"
    fi

    # update OS, install packages
    rm -f debian.package_overlay.qcow2
    qemu-img create -b debian_wheezy_amd64_standard.qcow2 -f qcow2 debian.package_overlay.qcow2

    spin_up_root
    make_ssh_keys
    install_ssh_keys

    $SSH_ROOT "swapoff -a; sed -i 's|\(^.*swap.*$\)|#\1|' /etc/fstab"
    $SSH_ROOT "DEBIAN_FRONTEND=noninteractive apt-get -y update"
    $SSH_ROOT "DEBIAN_FRONTEND=noninteractive apt-get -y upgrade"
    $SSH_ROOT "DEBIAN_FRONTEND=noninteractive apt-get -y install htop ncdu mc git tig build-essential gperf bison flex texinfo libtool automake ncurses-dev unzip libssl-dev gawk make g++"
    # https://wiki.debian.org/Multiarch/HOWTO
    $SSH_ROOT "DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386; apt-get -y update; apt-get -y install libstdc++6:i386"

    # misc prep
    $SSH_ROOT "echo '/dev/sdb1  /home/  ext4  nofail,errors=remount-ro  0  2' >> /etc/fstab"
    $SSH_ROOT "mkdir -p /opt/toolchains/; ln -s /home/user/x-tools/arm-m6-linux-gnueabi/ /opt/toolchains/"
    spin_down
}

create_home()
{
    rm -f debian.home.qcow2
    qemu-img create -f qcow2 debian.home.qcow2 10G
    spin_up_home
    $SSH_ROOT "echo -e 'n\np\n1\n\n\nw\n' | fdisk /dev/sdb; mkfs.ext4 /dev/sdb1"
    sleep 2
    $SSH_ROOT "cp -r /home/user/. /tmp" || true
    $SSH_ROOT "mount /dev/sdb1"
    sleep 2
    $SSH_ROOT "mkdir -p /home/user; cp -r /tmp/. /home/user; chown -R user:user /home/user"
    spin_down
}

create_crosstools()
{
    # setup the buildroot, all this happens inside the vm and inside an empty overlay
    spin_up_home

    # this stuff really should happen during the firmware build
    # but one file from the firmware repo is needed for crosstools
    $SSH_USER "mkdir -p pillar"
    if [[ ! -e firmware.git.tar.gz ]]; then
        $SSH_USER "cd pillar; git clone -b pillar --recursive $github_repo"
        # todo: not have to manually login a dozen times
        $SSH_USER "cd pillar; tar -caf firmware.git.tar.gz lighthouse-firmware/; chmod -w firmware.git.tar.gz"
        $SCP_USER user@localhost:~/pillar/firmware.git.tar.gz ./
    fi
    $SSH_USER "rm -f ~/pillar/firmware.git.tar.gz"
    $SCP_USER firmware.git.tar.gz user@localhost:~/pillar/
    $SSH_USER "cd pillar; tar xaf firmware.git.tar.gz"

    if [[ ! -e crosstool-ng-1.20.0.tar.bz2 ]]; then
        wget http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.20.0.tar.bz2
    fi
    $SCP_USER crosstool-ng-1.20.0.tar.bz2 user@localhost:~/pillar/
    if [[ -e x-tools.bin.tar.gz ]]; then
        echo "Using pre-compiled xtools"
        $SCP_USER x-tools.bin.tar.gz user@localhost:~/
        $SSH_USER "tar xaf x-tools.bin.tar.gz"
        spin_down
        return
    fi

    $SSH_USER "cd pillar; tar xaf crosstool-ng-1.20.0.tar.bz2"
    $SSH_USER "cd pillar/crosstool-ng-1.20.0/; ./configure --enable-local"
    $SSH_USER "cd pillar/crosstool-ng-1.20.0/; make && make install"
    $SSH_USER "cp ~/pillar/lighthouse-firmware/crosstool-ng.config ~/pillar/crosstool-ng-1.20.0/.config"
    # backup crosstools tarballs
    if [[ ! -e downloads/tarballs ]]; then
        $SSH_USER "cd pillar/crosstool-ng-1.20.0/; ./ct-ng build"
        mkdir -p downloads/tarballs
        $SCP_USER user@localhost:~/pillar/crosstool-ng-1.20.0/.build/tarballs/* downloads/tarballs/
    else
        $SSH_USER "mkdir -p ~/pillar/crosstool-ng-1.20.0/.build/tarballs/"
        $SCP_USER downloads/tarballs/* user@localhost:~/pillar/crosstool-ng-1.20.0/.build/tarballs/
        # missing glibc-libidn-2.19 tarball?
        $SSH_USER "cd pillar/crosstool-ng-1.20.0/; ./ct-ng build"
    fi
    $SSH_USER "rm -rf /home/user/pillar/crosstool-ng-1.20.0/.build"
    # back up x-tools binaries
    $SSH_USER "tar -caf x-tools.bin.tar.gz x-tools/; chmod -w x-tools.bin.tar.gz"
    $SCP_USER user@localhost:~/x-tools.bin.tar.gz ./
    
    # normally we'd backup pillar sources now but 'make source' is gone?
    spin_down
}

enlarge_image()
{
    exit 1
    qemu-img resize disk_image +1G
    # resize fs
    # parted? unmount?  fdisk?  resize2fs?  
    # parted?  reboot? resize2fs?
    # rebuild overlays?
}

clean_rebuild()
{
    rm -f debian.build_overlay.qcow2
    qemu-img create -b debian.home.qcow2 -f qcow2 debian.build_overlay.qcow2
    spin_up_build
    # ? make buildroot-menuconfig
    # ? make linux-menuconfig

    if [[ -e downloads/dl ]]; then
        $SSH_USER "mkdir -p ~/pillar/lighthouse-firmware/buildroot/dl"
        $SCP_USER downloads/dl/* user@localhost:~/pillar/lighthouse-firmware/buildroot/dl/
    fi
    $SSH_USER "cd ~/pillar/lighthouse-firmware; make clean"
    $SSH_USER "cd ~/pillar/lighthouse-firmware; git pull; git pull --recurse-submodules; git submodule update --recursive"
    $SSH_USER "cd ~/pillar/lighthouse-firmware; make"
    $SCP_USER user@localhost:~/pillar/lighthouse-firmware/outernet-rx-*.pkg ./

    if [[ ! -e downloads/dl ]]; then
        mkdir -p downloads/dl
        $SCP_USER user@localhost:~/pillar/lighthouse-firmware/buildroot/dl/* downloads/dl/
    fi

    spin_down
}

update_rebuild()
{
    spin_up_build
    # ? make buildroot-menuconfig
    # ? make linux-menuconfig

    # todo: completely working incremental rebuilds
    #$SSH_USER "cd ~/pillar/lighthouse-firmware; make clean"
    #$SSH_USER "rm -f ~/pillar/lighthouse-firmware/buildroot/.config"
    $SSH_USER "rm -f ~/pillar/lighthouse-firmware/.stamp_buildroot"

    $SSH_USER "cd ~/pillar/lighthouse-firmware; git pull; git pull --recurse-submodules; git submodule update --recursive"
    $SSH_USER "cd ~/pillar/lighthouse-firmware; make"
    $SCP_USER user@localhost:~/pillar/lighthouse-firmware/outernet-rx-*.pkg ./

    spin_down
}

case $1 in
    check_requirements)
        check_requirements
        ;;
    install_debian)
        install_debian
        ;;
    create_home)
        create_home
        ;;
    create_crosstools)
        create_crosstools
        ;;
    clean_rebuild)
        clean_rebuild
        ;;
    update_rebuild)
        update_rebuild
        ;;
    spin_down)
        spin_down
        ;;
    mess_around_in_build)
        spin_up_build
        $SSH_USER
        spin_down
        ;;
    all)
        install_debian
        create_home
        create_crosstools
        clean_rebuild
        ;;
    -h|--help|help|*)
        docs
        ;;
esac


