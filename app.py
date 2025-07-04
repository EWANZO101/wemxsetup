from flask import Flask, render_template, request, redirect, flash
import subprocess
import socket
import os

app = Flask(__name__)
app.secret_key = "supersecretkey"

WEMX_PATH = "/var/www/wemx"
SETUP_DIR = "/opt/wemx-setup"
SUCCESS_FLAG = os.path.join(SETUP_DIR, ".setup_done")


def get_vm_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip


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


def write_setup_success():
    os.makedirs(SETUP_DIR, exist_ok=True)
    with open(SUCCESS_FLAG, "w") as f:
        f.write("1")


@app.route("/", methods=["GET", "POST"])
def index():
    vm_ip = get_vm_ip()

    if request.method == "POST":
        license_key = request.form.get("license", "").strip()

        if not license_key:
            flash("License key is required.", "error")
            return redirect("/")

        try:
            output = update_license(license_key)
            write_setup_success()
            flash(f"License updated successfully: {output}", "success")
            return render_template("success.html")
        except Exception as e:
            flash(f"License update failed: {e}", "error")
            return redirect("/")

    return render_template("index.html", vm_ip=vm_ip)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
