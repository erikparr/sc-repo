#!/bin/bash

# Get the absolute path of the current directory
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MIDI Note Printer"
APP_PATH="/Applications/$APP_NAME.app"

# Check if we have an icon, if not try to create one
if [ ! -f "$APP_DIR/icon.icns" ]; then
  echo "No icon found. Attempting to create one..."
  if [ -f "$APP_DIR/download-icon.sh" ]; then
    "$APP_DIR/download-icon.sh"
  else
    echo "Icon creation script not found. Creating a simple icon template..."
    if [ -f "$APP_DIR/create-simple-icon.sh" ]; then
      "$APP_DIR/create-simple-icon.sh"
      echo "Please follow the instructions above to create an icon before proceeding."
      read -p "Press Enter to continue without an icon, or Ctrl+C to cancel..." 
    fi
  fi
fi

# Create a temporary AppleScript file
cat > /tmp/midi_launcher.scpt << EOL
tell application "Terminal"
  do script "cd '$APP_DIR' && ./start-app.sh; echo ''; echo 'Press any key to close this window...'; read -n 1; exit"
end tell

# Open Chrome directly from AppleScript as well (as a backup)
delay 3
tell application "Google Chrome"
  activate
  open location "http://localhost:3000"
end tell
EOL

# Create the Automator app
echo "Creating '$APP_NAME.app' in your Applications folder..."
osacompile -o "$APP_PATH" /tmp/midi_launcher.scpt

# Set the app icon if available
if [ -f "$APP_DIR/icon.icns" ]; then
  echo "Setting custom icon..."
  cp "$APP_DIR/icon.icns" "$APP_PATH/Contents/Resources/applet.icns"
fi

# Clean up
rm /tmp/midi_launcher.scpt

echo "Done! The MIDI Note Printer app has been created in your Applications folder."

# Ask if user wants to add the app to the Dock
read -p "Would you like to add the app to your Dock? (y/n): " add_to_dock
if [[ $add_to_dock =~ ^[Yy]$ ]]; then
  echo "Adding to Dock..."
  defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$APP_PATH</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
  killall Dock
  echo "App added to Dock!"
fi

echo "You can now launch the MIDI Note Printer by clicking on '$APP_NAME' in your Applications folder or Dock." 