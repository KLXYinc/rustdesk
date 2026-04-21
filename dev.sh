#!/bin/bash
# dev.sh - MacOS development script for RustDesk with Flutter hot-reload

# Make sure we fail if any steps fail
set -e

# Setup necessary environment variables for Apple Silicon & CocoaPods
export LANG=en_US.UTF-8
export PATH=/opt/homebrew/bin:$PATH

# Automatically resolve VCPKG_ROOT relative to the script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export VCPKG_ROOT="$DIR/vcpkg"

echo "=== Compiling Rust Base Library (Debug Mode for Hot Reload) ==="
# Xcode project in debug mode searches for target/debug/librustdesk.dylib
cargo build --features flutter

# Link the dylib to the expected name for Xcode linker
cp target/debug/liblibrustdesk.dylib target/debug/librustdesk.dylib

echo "=== Starting Flutter with Hot-Reload ==="
cd flutter
flutter run -d macos
