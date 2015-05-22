#!/bin/sh

INSTALLER=$1

CONTENTS=$($INSTALLER --list)

# Platform check
if [ "$(cat /etc/platform 2> /dev/null)" != "wt200" ]; then
  echo "Incorrect platform"
  exit 1
fi

# Check for version if present
if echo $CONTENTS | grep version > /dev/null ; then
  PKG_VER=$($INSTALLER --extract version -)
  OS_VER=$(cat /etc/version 2> /dev/null)

  if [ "$PKG_VER" == "$OS_VER" ]; then
    echo "Package already installed"
    exit 1
  fi
  CHK=$(echo -e "$PKG_VER\n$OS_VER\n" | sort -r | head -1)
  if [ "$PKG_VER" != "$CHK" ]; then
    echo "Package version is older than installed version"
    exit 1
  fi
fi

# look for a pre-update script
if echo $CONTENTS | grep pre-install.sh > /dev/null ; then
  $INSTALLER --extract pre-install.sh /tmp
  [ -x /tmp/pre-install.sh ] && ( /tmp/pre-install.sh $INSTALLER || exit 1 )
  rm /tmp/pre-install.sh
fi

# Install kernel
if echo $CONTENTS | grep kernel.img > /dev/null ; then
  MTD_BOOT=$(grep boot /proc/mtd | sed 's/^mtd\([0-9]\+\).*/\1/')
  MTD_RECOVERY=$(grep recovery /proc/mtd | sed 's/^mtd\([0-9]\+\).*/\1/')
  if [ -z "$MTD_BOOT" ] || [ -z "$MTD_RECOVERY" ]; then
    logger -s -t installer.sh "Could not determine kernel mtd partitions"
    exit 1
  fi
  $INSTALLER --flash kernel.img $MTD_RECOVERY || exit 1
  $INSTALLER --flash kernel.img $MTD_BOOT || exit 1
fi

# Install rotfs
if echo $CONTENTS | grep rootfs.ubifs > /dev/null ; then
  $INSTALLER --ubi rootfs.ubifs ubi0:rootfs || exit 1
fi

# u-boot
if echo $CONTENTS | grep u-boot.bin > /dev/null ; then
  MTD_UBOOT=$(grep bootloader /proc/mtd | sed 's/^mtd\([0-9]\+\).*/\1/')
  if [ -z "$MTD_UBOOT" ]; then
    logger -s -t installer.sh "Could not determine u-boot mtd partitions"
    exit 1
  fi
  $INSTALLER --flash u-boot.bin $MTD_UBOOT || exit 1
fi

# look for a post-install script
if echo $CONTENTS | grep post-install.sh > /dev/null ; then
  $INSTALLER --extract post-install.sh /tmp
  [ -x /tmp/post-install.sh ] && ( /tmp/post-install.sh $INSTALLER || exit 1 )
  rm /tmp/post-install.sh
fi

logger -s -t installer.sh "Installation complete"
/sbin/reboot
