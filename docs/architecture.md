# Architecture

PortGlide is a native SwiftUI macOS application with three layers:

- `Models` defines validated server profiles, supported applications, and SSH argument builders.
- `Services` owns persistence, process execution, tunnel lifecycle, and status checks.
- `Views` renders profiles and explicit user actions.

## Connection boundaries

SOCKS5 and RDP tunnels are separate SSH processes. Before stopping a listener, PortGlide verifies the PID command contains the expected SSH alias, forwarding mode, endpoint, and port. An unrelated process is never terminated.

Remote OpenVPN controls call a validated service name through `sudo -n systemctl start|stop`. Starting OpenVPN does not start RDP. Opening an RDP client is a separate user action.

Credential rotation is isolated from normal profile storage. Credentials are encoded into one generic-password item in macOS Keychain, passed to `ssh` through stdin, and consumed by a narrow root helper that atomically replaces the OpenVPN auth file with mode `0600`.

Supported desktop applications receive proxy environment variables and a Chromium-compatible `--proxy-server` argument. Running applications are detected through LaunchServices and are never restarted automatically.

## Storage

Only non-secret profile fields are encoded as JSON in Application Support. SSH keys remain managed by OpenSSH, and VPN profile contents are never read or copied by PortGlide.
