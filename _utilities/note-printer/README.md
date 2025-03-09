# MIDI Note Printer

A simple web application that connects to a MIDI keyboard (specifically designed for Keystation devices) and displays the notes played in real-time.

## Features

- Automatic detection of Keystation MIDI devices
- Record and display MIDI notes in real-time
- Start/stop recording with a button or Enter key
- Clear the current output with Space key
- Copy the recorded notes to clipboard with a button or Ctrl+C
- Toggle between note names (e.g., C4, D#3) and MIDI numbers (e.g., 60, 63) with T key
- Simple and clean user interface

## Requirements

- Node.js (v12 or higher recommended)
- A MIDI keyboard (Keystation or other compatible device)
- Google Chrome (recommended browser for MIDI support)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/note-printer.git
   cd note-printer
   ```

2. Install dependencies:
   ```
   npm install
   ```

## Quick Start Options

There are several easy ways to start the application:

### Option 1: Use the start script (Easiest)
Simply double-click the `MIDI Note Printer.command` file in Finder, or run:
```
./start-app.sh
```
This will automatically:
- Start the server
- Open Google Chrome
- Navigate to the application at http://localhost:3000

### Option 2: Create a macOS application with Dock icon (Recommended)
Run the following script to create a clickable application in your Applications folder:
```
./create-app.sh
```

This script will:
1. Create a custom icon for the application (if possible)
2. Create a macOS application in your Applications folder
3. Ask if you want to add the app to your Dock for one-click access

After running this script once, you can launch the app from your Applications folder or Dock. The application will automatically open in Google Chrome.

### Option 3: Manual start
```
npm start
```
Then manually open Google Chrome and navigate to `http://localhost:3000`

## Custom Icon

The application comes with scripts to create a custom icon:

1. Automatic icon creation:
   ```
   ./download-icon.sh
   ```
   This will download and convert a MIDI keyboard icon.

2. Manual icon creation:
   ```
   ./create-simple-icon.sh
   ```
   This creates an HTML template that you can use to make a simple icon.

After creating an icon, run `./create-app.sh` again to update the application with the new icon.

## Usage

1. Connect your MIDI keyboard to your computer before starting the application
2. Start the app using one of the methods above
3. The application will automatically open in Google Chrome
4. Click "New Take" or press Enter to start recording notes
5. Play notes on your MIDI keyboard - they will appear in the text area
6. Click "New Take" again or press Enter to stop recording
7. Use the "Clear" button or press Space to clear the current output
8. Use the "Copy Notes" button or press Ctrl+C to copy the notes to your clipboard
9. Use the "Toggle Note Format" button or press T to switch between note names and MIDI numbers

## Browser Compatibility

This application uses the Web MIDI API, which is currently supported in:
- Google Chrome (recommended and used by default)
- Microsoft Edge
- Opera

It is not supported in Firefox or Safari without extensions.

## Troubleshooting

- If your MIDI device is not detected, try disconnecting and reconnecting it
- Make sure you're using Google Chrome for best compatibility
- Check the browser console for any error messages
- If you get an "address already in use" error, the app might already be running. Use the start script which automatically handles this.

## License

MIT 