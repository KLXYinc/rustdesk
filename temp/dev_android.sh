#!/bin/bash
set -e

cd flutter

# Check if an Android emulator or device is already running
if ! flutter devices | grep -q "emulator-5554"; then
    echo "No running Android device detected. Launching 'Pixel_9' emulator..."
    flutter emulators --launch Pixel_9
    
    echo "Waiting for emulator to boot up..."
    # Give the emulator a few seconds to register in flutter devices
    sleep 15
else
    echo "Android device already detected."
fi

echo "Starting Flutter on Android Emulator with Hot-Reload..."
# target the first emulator explicitly
flutter run -d emulator-5554
