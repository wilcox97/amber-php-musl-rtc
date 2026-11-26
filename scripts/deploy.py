#!/usr/bin/env python3
"""
Optional: deploy and install a built .ipk onto a real OpenWrt router over
SSH. Dropbear on OpenWrt typically has no SFTP subsystem, so this streams
the file through `cat > remote_path` on an exec_command channel instead
of using SFTP.

Configure via environment variables (nothing is hardcoded):
  ROUTER_HOST   - IP or hostname (required)
  ROUTER_USER   - SSH user (default: root)
  ROUTER_PASSWORD or ROUTER_KEY_PATH - one of these is required
  IPK_PATH      - local path to the .ipk to install (required)
  REMOVE_FIRST  - package name to `opkg remove` before installing, if a
                  prior version of this package may already be installed
                  (optional)
"""
import os
import sys
import time
import paramiko

def main():
    host = os.environ["ROUTER_HOST"]
    user = os.environ.get("ROUTER_USER", "root")
    ipk_path = os.environ["IPK_PATH"]
    password = os.environ.get("ROUTER_PASSWORD")
    key_path = os.environ.get("ROUTER_KEY_PATH")
    remove_first = os.environ.get("REMOVE_FIRST")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    if key_path:
        client.connect(host, username=user, key_filename=key_path, timeout=20)
    else:
        client.connect(host, username=user, password=password, timeout=20)

    remote_path = "/tmp/" + os.path.basename(ipk_path)
    print(f"uploading {ipk_path} -> {host}:{remote_path}")
    chan = client.get_transport().open_session()
    chan.exec_command(f"cat > {remote_path}")
    with open(ipk_path, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            chan.send(chunk)
    chan.shutdown_write()
    while not chan.exit_status_ready():
        time.sleep(0.1)

    def run(cmd):
        print(f"$ {cmd}")
        _, stdout, stderr = client.exec_command(cmd)
        out = stdout.read().decode(errors="replace")
        err = stderr.read().decode(errors="replace")
        if out:
            print(out, end="")
        if err:
            print(err, end="", file=sys.stderr)
        return stdout.channel.recv_exit_status()

    if remove_first:
        run(f"opkg remove {remove_first} 2>/dev/null; true")
    rc = run(f"opkg install {remote_path}")
    if rc != 0:
        sys.exit(f"opkg install failed with exit code {rc}")

    client.close()
    print("DEPLOY_OK")

if __name__ == "__main__":
    main()
