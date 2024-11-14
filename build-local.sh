#!/usr/bin/env bash

cd "$(dirname "$0")"
artifact_id="$1"

# turn on verbose debugging output for logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x

# make errors fatal
set -e

# bleat on references to undefined shell variables
set -u

# Suddenly, Cygwin inserts extra CRLFs in places such
# as the code that extracts version numbers so we need
# this command to stop it doing that...
[[ "$OSTYPE" == "cygwin" ]] && set -o igncr

top="$(pwd)/."
stage="${top}"/stage
build="${top}"/build

rm -rf "$stage"/*
#rm -rf "$build"/_package
case "$AUTOBUILD_PLATFORM" in
    windows64)
        autobuild="$(cygpath -u "$AUTOBUILD")"
        build_type="windows_x86_64"
    ;;
    windows)
        autobuild="$(cygpath -u "$AUTOBUILD")"
        build_type="windows_x86_64"
    ;;
    darwin*)
        build_type="macos_x86_64"
        autobuild="$AUTOBUILD"
    ;;
    linux*)
        build_type="linux_x86_64"
        autobuild="$AUTOBUILD"
    ;;
    *)
        echo "This project is not currently supported for $AUTOBUILD_PLATFORM" 1>&2 ; exit 1
        
    ;;
esac

pushd "$build"

# Special case for macos universal packages
case "$AUTOBUILD_PLATFORM" in
    darwin*)
        #bash ./build.macos_x86_64.sh m114_release
        #bash ./build.macos_arm64.sh m114_release

        source_environment_tempfile="$stage/source_environment.sh"
        autobuild source_environment > "$source_environment_tempfile"
        . "$source_environment_tempfile"

        pushd "$stage"

        mkdir "x86_64"
        pushd "x86_64"
            tar -xjf "$build"/_package/macos_x86_64/webrtc.tar.bz2 --strip-components=1
        popd

        mkdir "arm64"
        pushd "arm64"
            tar -xjf "$build"/_package/macos_arm64/webrtc.tar.bz2 --strip-components=1
        popd

        # Munge the WebRTC Build package contents into something compatible
        # with the layout we use for other autobuild pacakges

        # Create universal library
        mkdir -p lib/release
        lipo -create -output "$stage/lib/release/libwebrtc.a" "$stage/x86_64/lib/libwebrtc.a" "$stage/arm64/lib/libwebrtc.a"

        mkdir -p include
        mv x86_64/include/* include

        mkdir LICENSES
        mv x86_64/NOTICE LICENSES/webrtc-license.txt

        build=${AUTOBUILD_BUILD_ID:=0}
        echo "m114_release.${build}" > "$stage/VERSION.txt"
        echo "m114_release.${build}" > "$top/VERSION.txt"
        popd
    ;;
    *)
        bash ./build."$build_type".sh m114_release

        source_environment_tempfile="$stage/source_environment.sh"
        autobuild source_environment > "$source_environment_tempfile"
        . "$source_environment_tempfile"

        pushd "$stage"

        tar -xjf "$build"/_package/"$build_type"/webrtc.tar.bz2 --strip-components=1

        # Munge the WebRTC Build package contents into something compatible
        # with the layout we use for other autobuild pacakges
        mv include webrtc
        mkdir include
        mv webrtc include
        mv lib release
        mkdir lib
        mv release lib
        mkdir LICENSES
        mv NOTICE LICENSES/webrtc-license.txt

        build=${AUTOBUILD_BUILD_ID:=0}
        echo "m114_release.${build}" > "$stage/VERSION.txt"
        echo "m114_release.${build}" > "$top/VERSION.txt"
        popd
    ;;
esac

popd
