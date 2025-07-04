#!/bin/bash

SCRIPT_PATH=$(realpath "$0")
APP_DIR="/opt/wemx-setup"
REPO_URL="https://github.com/EWANZO101/wemxsetup"  # 🔁 Replace with your actual repo
PYTHON_BIN="/usr/bin/python3"

echo "🚀 Starting WEMX setup..."

# 1. Update system
apt update && apt upgrade -y

# 2. Install required packages
apt install -y nginx php php-cli php-mbstring unzip git curl python3 python3-pip

# 3. Clone Flask App
if [ ! -d "$APP_DIR" ]; then
    git clone $REPO_URL $APP_DIR
else
    cd $APP_DIR && git pull
fi

# 4. Install Python deps
cd $APP_DIR
pip3 install -r requirements.txt

# 5. Make artisan executable
chmod +x /var/www/wemx/artisan

# 6. Create systemd service
cat > /etc/systemd/system/wemx-flask.service <<EOF
[Unit]
Description=WEMX Setup Flask App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$PYTHON_BIN app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable wemx-flask
systemctl start wemx-flask

# 7. Allow Flask port
ufw allow 5000 || true

echo "✅ WEMX Flask app started on port 5000."
echo "🌐 Open this in your browser: http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "⚠️ Complete the setup in the browser (enter domain + license)."

# 8. Wait for DNS setup and success flag
echo "⏳ Waiting for domain ping & setup to complete..."

MAX_RETRIES=60
SLEEP_INTERVAL=5
SUCCESS_FLAG="$APP_DIR/.setup_done"
DOMAIN_FILE="$APP_DIR/.setup_domain"

for ((i=1; i<=MAX_RETRIES; i++)); do
    if [ -f "$SUCCESS_FLAG" ] && [ -f "$DOMAIN_FILE" ]; then
        DOMAIN=$(cat "$DOMAIN_FILE")
        ping -c 1 "$DOMAIN" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Domain responded successfully!"
            echo "🧹 Cleaning up setup files..."

            # Self-destruct
            rm -f "$SCRIPT_PATH"
            echo "💣 Setup script deleted itself. Done!"
            exit 0
        else
            echo "⏳ Waiting for domain ($DOMAIN) to respond... ($i/$MAX_RETRIES)"
        fi
    else
        echo "⌛ Waiting for web setup to complete... ($i/$MAX_RETRIES)"
    fi
    sleep $SLEEP_INTERVAL
done

echo "❌ Timeout: Setup did not complete or domain didn't respond in time."
exit 1
