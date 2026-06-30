<p align="center">
  <img src="Assets/AppIcon.png" width="160" alt="PortGlide app icon">
</p>

<h1 align="center">PortGlide</h1>

<p align="center">
  A native macOS switchboard for SSH tunnels, SOCKS5 proxies, remote OpenVPN services, and RDP connections.
</p>

PortGlide keeps multi-server connection workflows in one place. Select a server profile, start only the services you need, and see their state without opening Terminal.

## Features

- Multiple server and country profiles
- SSH connectivity checks
- Managed SOCKS5 tunnels with safe process ownership checks
- Independent remote OpenVPN start/stop controls
- Secure OpenVPN credential rotation through macOS Keychain and SSH stdin
- Independent RDP tunnel and client launch controls
- Launch supported desktop applications through the selected SOCKS5 proxy
- Local `.ovpn` handoff to an installed VPN client
- No password, private-key, or VPN-profile storage

## Requirements

- macOS 14 or newer
- Swift 5.10 or newer
- SSH aliases configured in `~/.ssh/config`
- Optional: Windows App or another `.rdp` client
- Optional: an OpenVPN client associated with `.ovpn` files

## Build and run

Double-click `RUN-PORTGLIDE.command`, or run:

```bash
./scripts/build-app.sh
```

The signed development bundle is created at `build/PortGlide.app`.

To install PortGlide independently of the source checkout:

```bash
./scripts/install-user.sh
```

This creates `~/Applications/PortGlide.app`. Deleting the repository afterwards does not remove the installed application or its profiles.

For development:

```bash
swift run PortGlide
swift test
```

## Configuration

PortGlide stores non-secret profiles in:

```text
~/Library/Application Support/PortGlide/profiles.json
~/Library/Application Support/PortGlide/profiles.backup.json
```

SSH hostnames, users, ports, and identity files remain in `~/.ssh/config`. VPN profiles and private keys are never copied into the repository or application profile store.

OpenVPN usernames and passwords are stored separately in macOS Keychain. The remote credential helper receives them through encrypted SSH stdin, never through command-line arguments.

See [Configuration](docs/configuration.md) and [Architecture](docs/architecture.md) for details.

## Security

Never commit `.ovpn`, `.pem`, `.key`, `.p12`, or `.pfx` files. PortGlide passes commands as argument arrays without constructing local shell commands from profile values.

Please report vulnerabilities according to [SECURITY.md](SECURITY.md).

## License

PortGlide is free and open source under the [MIT License](LICENSE).
