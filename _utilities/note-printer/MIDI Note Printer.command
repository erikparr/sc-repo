#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Run the start script
./start-app.sh

# Keep the terminal window open until user presses a key
echo ""
echo "Press any key to close this window..."
read -n 1 