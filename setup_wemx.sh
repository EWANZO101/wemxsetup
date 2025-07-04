#!/bin/bash

APP_DIR="/opt/wemx-setup"
REPO_URL="https://github.com/EWANZO101/wemxsetup"
PYTHON_BIN="/usr/bin/python3"

echo "🚀 Starting minimal WEMX setup..."

# Update system and install required packages
apt update && apt upgrade -y
apt install -y git python3 python3-pip

# Clone or update repo
if [ ! -d "$APP_DIR" ]; then
    git clone $REPO_URL $APP_DIR
else
    cd $APP_DIR && git pull
fi

# Install Flask and Python requirements
pip3 install --upgrade pip
pip3 install Flask
cd $APP_DIR
if [ -f requirements.txt ]; then
    pip3 install -r requirements.txt
fi

echo "✅ Flask and requirements installed."
echo "✅ Repo cloned/updated at $APP_DIR."
