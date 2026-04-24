#!/usr/bin/env bash

set -e # Exit immediately if a command exits with a non-zero status
set -x # Print commands and their arguments as they are executed

echo "=== Setting Environment Variables ==="
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/28.2.13676358
export VCPKG_ROOT=$PWD/vcpkg
export PATH="$PWD/build_tools/bin:$PATH"

echo "=== Compiling C++ Dependencies (vcpkg) ==="
./flutter/build_android_deps.sh arm64-v8a

echo "=== Building Rust Core Library ==="
./flutter/ndk_arm64.sh

echo "=== Copying Shared Library ==="
mkdir -p ./flutter/android/app/src/main/jniLibs/arm64-v8a
cp ./target/aarch64-linux-android/release/liblibrustdesk.so ./flutter/android/app/src/main/jniLibs/arm64-v8a/librustdesk.so

echo "=== Building Flutter APK ==="
cd flutter
flutter build apk --release --target-platform android-arm64

echo "=== Build Finished Successfully! ==="
