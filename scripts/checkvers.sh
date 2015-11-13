#!/bin/bash

SCRIPTDIR=$(dirname $0)
PKGDIR=$SCRIPTDIR/../my_packages
SRCDIR=$1


pkgver() {
    pkgname=$1
    echo $(grep VERSION "$PKGDIR/${pkgname}/${pkgname}.mk" | head -n1 \
        | cut -f2 -d=)
}

spkgver() {
    path=$1
    echo $(cd "$path" && git log 2> /dev/null | head -n1 | cut -f2 -d' ')
}

findspkg() {
    pkgname=$1
    echo $(ls -d "${SRCDIR%%/}/${pkgname##python-}" 2> /dev/null)
}

patchver() {
    pkgname=$1
    version=$2
    makefile=$PKGDIR/$pkgname/${pkgname}.mk
    sed "s/VERSION = \(.\+\)/VERSION = $version/" -i "$makefile"
}

if [ -z "$SRCDIR" ]
then
    echo "Usage: $0 PATH"
    echo
    echo "    PATH - local source repositories"
    echo
    echo "Make sure source repositories are up to date"
    exit 0
fi


for pkg in $PKGDIR/*
do
    pkgname=$(basename $pkg)
    version=$(pkgver $pkgname)
    echo -n "Checking $pkgname..."
    srcpkg=$(findspkg $pkgname)
    if [ -z "$srcpkg" ]
    then
        echo "NOT FOUND"
        continue
    fi
    srcpkgv=$(spkgver $srcpkg)
    if [ -z "$srcpkgv" ]
    then
        echo "UNKNOWN"
        continue
    fi
    if [ "$srcpkgv" == "$version" ]
    then
        echo "MATCH"
        continue
    fi
    patchver "$pkgname" "$srcpkgv"
    echo "UPDATED"
    echo "$pkgname : $version -> $srcpkgv"
done

