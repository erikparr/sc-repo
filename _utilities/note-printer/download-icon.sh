#!/bin/bash

# Create an icons directory if it doesn't exist
mkdir -p icons

# Download a MIDI keyboard icon from a public domain source
echo "Downloading MIDI keyboard icon..."
curl -s -o icons/midi-keyboard.png "https://cdn-icons-png.flaticon.com/512/5049/5049493.png"

# Check if the download was successful
if [ ! -f icons/midi-keyboard.png ]; then
  echo "Failed to download icon. Using a backup method..."
  # Create a simple text-based icon as a fallback
  convert -size 1024x1024 -background transparent -fill "#4CAF50" -gravity center -font Arial -pointsize 400 label:"MP" icons/midi-keyboard.png
fi

# Convert the PNG to ICNS format for macOS
echo "Converting icon to macOS format..."
if command -v sips &> /dev/null && command -v iconutil &> /dev/null; then
  # macOS native tools method
  mkdir -p icons/icon.iconset
  sips -z 16 16 icons/midi-keyboard.png --out icons/icon.iconset/icon_16x16.png
  sips -z 32 32 icons/midi-keyboard.png --out icons/icon.iconset/icon_16x16@2x.png
  sips -z 32 32 icons/midi-keyboard.png --out icons/icon.iconset/icon_32x32.png
  sips -z 64 64 icons/midi-keyboard.png --out icons/icon.iconset/icon_32x32@2x.png
  sips -z 128 128 icons/midi-keyboard.png --out icons/icon.iconset/icon_128x128.png
  sips -z 256 256 icons/midi-keyboard.png --out icons/icon.iconset/icon_128x128@2x.png
  sips -z 256 256 icons/midi-keyboard.png --out icons/icon.iconset/icon_256x256.png
  sips -z 512 512 icons/midi-keyboard.png --out icons/icon.iconset/icon_256x256@2x.png
  sips -z 512 512 icons/midi-keyboard.png --out icons/icon.iconset/icon_512x512.png
  sips -z 1024 1024 icons/midi-keyboard.png --out icons/icon.iconset/icon_512x512@2x.png
  iconutil -c icns icons/icon.iconset -o icon.icns
  rm -rf icons/icon.iconset
elif command -v convert &> /dev/null; then
  # ImageMagick method
  convert icons/midi-keyboard.png -resize 1024x1024 icon.icns
else
  echo "Warning: Could not convert to ICNS format. Icon may not display correctly."
  cp icons/midi-keyboard.png icon.icns
fi

echo "Icon created as icon.icns"
echo "This icon will be used when creating the application." 