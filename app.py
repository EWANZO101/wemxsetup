from flask import Flask, render_template, request, redirect, flash
import subprocess
import socket

app = Flask(__name__)
app.secret_key = "supersecretkey"

NGINX_CONF_PATH = "/etc/nginx/sites-available/wemx.conf"
WEMX_PATH = "/var/www/wemx"

def get_vm_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

def resolve_domain_ip(domain):
    try:
        return socket.gethostbyname(domain)
    except socket.gaierror:
        return None

def update_nginx_config(domain):
    with open("config_template.conf", "r") as f:
        template = f.read()
    config = template.replace("{{domain}}", domain)
    with open(NGINX_CONF_PATH, "w") as f:
        f.write(config)
    subprocess.run(["ln", "-sf", NGINX_CONF_PATH, "/etc/nginx/sites-enabled/wemx.conf"])
    subprocess.run(["nginx", "-t"])
    subprocess.run(["systemctl", "reload", "nginx"])

def update_license(license_key):
    subprocess.run(["php", "artisan", "license:update", license_key], cwd=WEMX_PATH)

@app.route("/", methods=["GET", "POST"])
def index():
    vm_ip = get_vm_ip()

    if request.method == "POST":
        domain = request.form.get("domain").strip()
        license_key = request.form.get("license").strip()

        if not domain or not license_key:
            flash("Both domain and license key are required.", "error")
            return redirect("/")

        resolved_ip = resolve_domain_ip(domain)
        if not resolved_ip:
            flash("DNS record not found. Please make sure the A record is set in Cloudflare or your domain provider.", "error")
            return redirect("/")
        
        if resolved_ip != vm_ip:
            flash(f"DNS A record mismatch. Domain '{domain}' resolves to {resolved_ip}, but your VM IP is {vm_ip}. Fix the A record before continuing.", "error")
            return redirect("/")

        try:
            update_nginx_config(domain)
            update_license(license_key)
            return render_template("success.html", domain=domain)
        except Exception as e:
            flash(f"Setup failed: {e}", "error")
            return redirect("/")

    return render_template("index.html", vm_ip=vm_ip)
