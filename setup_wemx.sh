#!/bin/bash

APP_DIR="/opt/wemx-setup"
REPO_URL="https://github.com/EWANZO101/wemxsetup"
PYTHON_BIN="/usr/bin/python3"
VENV_DIR="$APP_DIR/venv"

echo "🚀 Starting minimal WEMX setup..."

# Update system and install required packages
apt update && apt upgrade -y
apt install -y git python3 python3-venv python3-pip

# Clone or update repo
if [ ! -d "$APP_DIR" ]; then
    git clone "$REPO_URL" "$APP_DIR"
else
    cd "$APP_DIR" && git pull
fi

# Create Python virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# Activate venv and install Flask + requirements
source "$VENV_DIR/bin/activate"

pip install --upgrade pip
pip install Flask

cd "$APP_DIR"
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi

deactivate

echo "✅ Flask and requirements installed in virtual environment."
echo "✅ Repo cloned/updated at $APP_DIR."
