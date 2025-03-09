#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Kill any existing Node.js server processes on port 3000
echo "Checking for existing server processes..."
lsof -ti:3000 | xargs kill -9 2>/dev/null || true

# Start the server in the background
echo "Starting MIDI Note Printer..."
npm start &

# Store the server process ID
SERVER_PID=$!

# Wait a moment for the server to start
sleep 2

# Open Google Chrome with the application URL
echo "Opening Google Chrome..."
if [ "$(uname)" == "Darwin" ]; then
  # macOS
  open -a "Google Chrome" http://localhost:3000
else
  # Linux or other systems
  google-chrome http://localhost:3000 || chromium-browser http://localhost:3000 || chrome http://localhost:3000
fi

# Wait for the server process to complete
wait $SERVER_PID

# This line will be reached when the server is stopped
echo "Server stopped." 