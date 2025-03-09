#!/bin/bash

# Create a simple HTML file that will be used to generate an icon
cat > icon.html << EOL
<!DOCTYPE html>
<html>
<head>
  <style>
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      width: 1024px;
      height: 1024px;
      background: linear-gradient(135deg, #4CAF50, #2196F3);
      border-radius: 200px;
    }
    .text {
      font-family: Arial, sans-serif;
      font-size: 500px;
      font-weight: bold;
      color: white;
      text-shadow: 0 10px 20px rgba(0,0,0,0.3);
    }
  </style>
</head>
<body>
  <div class="text">MP</div>
</body>
</html>
EOL

echo "Created a simple HTML icon template."
echo "To use this icon:"
echo "1. Open icon.html in Google Chrome"
echo "2. Take a screenshot of the page (Cmd+Shift+4)"
echo "3. Save the screenshot as icon.png"
echo "4. Run the create-app.sh script to create the application with this icon" 