from flask import Flask, render_template, request, redirect, flash
import subprocess
import socket
import os

app = Flask(__name__)
app.secret_key = "supersecretkey"

NGINX_CONF_PATH = "/etc/nginx/sites-available/wemx.conf"
WEMX_PATH = "/var/www/wemx"
SETUP_DIR = "/opt/wemx-setup"
SUCCESS_FLAG = os.path.join(SETUP_DIR, ".setup_done")
DOMAIN_FILE = os.path.join(SETUP_DIR, ".setup_domain")


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
    # Ensure the template file exists in the same directory as this script
    template_path = os.path.join(os.path.dirname(__file__), "config_template.conf")
    if not os.path.isfile(template_path):
        raise FileNotFoundError(f"NGINX config template not found: {template_path}")

    with open(template_path, "r") as f:
        template = f.read()

    config = template.replace("{{domain}}", domain)

    # Write new config
    with open(NGINX_CONF_PATH, "w") as f:
        f.write(config)

    # Enable site
    subprocess.run(["ln", "-sf", NGINX_CONF_PATH, "/etc/nginx/sites-enabled/wemx.conf"], check=True)

    # Test and reload nginx
    subprocess.run(["nginx", "-t"], check=True)
    subprocess.run(["systemctl", "reload", "nginx"], check=True)


def update_license(license_key):
    result = subprocess.run(
        ["php", "artisan", "license:update", license_key],
        cwd=WEMX_PATH,
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        raise Exception(f"License update failed: {result.stderr.strip()}")
    return result.stdout.strip()


def write_setup_success(domain):
    os.makedirs(SETUP_DIR, exist_ok=True)
    with open(SUCCESS_FLAG, "w") as f:
        f.write("1")
    with open(DOMAIN_FILE, "w") as f:
        f.write(domain)


@app.route("/", methods=["GET", "POST"])
def index():
    vm_ip = get_vm_ip()

    if request.method == "POST":
        domain = request.form.get("domain", "").strip()
        license_key = request.form.get("license", "").strip()

        if not domain or not license_key:
            flash("Both domain and license key are required.", "error")
            return redirect("/")

        resolved_ip = resolve_domain_ip(domain)
        if not resolved_ip:
            flash("DNS record not found. Please ensure your domain has an A record set.", "error")
            return redirect("/")

        if resolved_ip != vm_ip:
            flash(f"DNS A record mismatch: Domain resolves to {resolved_ip}, but VM IP is {vm_ip}. Please fix the DNS.", "error")
            return redirect("/")

        try:
            update_nginx_config(domain)
            output = update_license(license_key)
            write_setup_success(domain)
            flash(f"License updated successfully: {output}", "success")
            return render_template("success.html", domain=domain)
        except Exception as e:
            flash(f"Setup failed: {e}", "error")
            return redirect("/")

    return render_template("index.html", vm_ip=vm_ip)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
