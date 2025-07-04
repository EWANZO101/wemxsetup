#!/bin/bash

SCRIPT_PATH=$(realpath "$0")
APP_DIR="/opt/wemx-setup"
REPO_URL="https://github.com/EWANZO101/wemxsetup"  # 🔁 Replace with your actual repo
PYTHON_BIN="/usr/bin/python3"
NGINX_CONF="/etc/nginx/sites-available/wemx.conf"
EMAIL="your-email@example.com"   # 🔁 Replace with your email for certbot notifications

echo "🚀 Starting WEMX setup..."

# 1. Update system
apt update && apt upgrade -y

# 2. Install required packages
apt install -y nginx php php-cli php-mbstring unzip git curl python3 python3-pip

# === Extract domain from Nginx config ===
if [ ! -f "$NGINX_CONF" ]; then
    echo "❌ Nginx config $NGINX_CONF not found!"
    exit 1
fi

DOMAIN=$(grep -Po 'server_name\s+\K[^;]+' "$NGINX_CONF" | head -1)

if [ -z "$DOMAIN" ]; then
    echo "❌ Could not extract domain from $NGINX_CONF"
    exit 1
fi

echo "🔍 Found domain: $DOMAIN"

# === Install Certbot ===
apt install -y certbot python3-certbot-nginx

# === Obtain SSL certificate with Certbot ===
echo "🔐 Requesting Let's Encrypt certificate for $DOMAIN..."

# Stop nginx briefly to avoid port conflicts if needed
systemctl stop nginx

certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

# Restart nginx to load certs
systemctl start nginx

echo "✅ SSL certificate installed for $DOMAIN"

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

# 7. Allow necessary ports
ufw allow 80 || true
ufw allow 443 || true
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
        DOMAIN_CHECK=$(cat "$DOMAIN_FILE")
        ping -c 1 "$DOMAIN_CHECK" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Domain responded successfully!"
            echo "🧹 Cleaning up setup files..."

            # Self-destruct
            rm -f "$SCRIPT_PATH"
            echo "💣 Setup script deleted itself. Done!"
            exit 0
        else
            echo "⏳ Waiting for domain ($DOMAIN_CHECK) to respond... ($i/$MAX_RETRIES)"
        fi
    else
        echo "⌛ Waiting for web setup to complete... ($i/$MAX_RETRIES)"
    fi
    sleep $SLEEP_INTERVAL
done

echo "❌ Timeout: Setup did not complete or domain didn't respond in time."
exit 1
