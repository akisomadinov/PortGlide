# Configuration

## SSH alias

Create a normal OpenSSH alias before adding a PortGlide profile:

```sshconfig
Host my-vps
    HostName example.com
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 15
    ServerAliveCountMax 4
```

PortGlide references `my-vps`; it does not duplicate the hostname, user, or key path.

## Remote OpenVPN

Specify the systemd unit in the profile, for example `openvpn-client@client`. If remote start/stop is required, allow only the exact commands through sudoers:

```sudoers
deploy ALL=(root) NOPASSWD: /bin/systemctl start openvpn-client@client, /bin/systemctl stop openvpn-client@client
```

Adapt the username, systemctl path, and unit to your server. Do not grant unrestricted passwordless sudo.

## Credential rotation helper

Install the repository helper once on the VPS:

```bash
sudo install -o root -g root -m 0755 \
  scripts/remote/portglide-openvpn-credentials \
  /usr/local/sbin/portglide-openvpn-credentials
```

Allow only the selected unit and helper invocation:

```sudoers
Cmnd_Alias PORTGLIDE_OPENVPN = /bin/systemctl start openvpn-client@client, /bin/systemctl stop openvpn-client@client, /usr/local/sbin/portglide-openvpn-credentials client
deploy ALL=(root) NOPASSWD: PORTGLIDE_OPENVPN
```

The `Обновить доступ` action in PortGlide stores credentials in macOS Keychain, sends them through SSH stdin, replaces `/etc/openvpn/client/client.auth` atomically with mode `0600`, and restarts only `openvpn-client@client`.

## Local VPN profile

Selecting an `.ovpn` file stores its path only. Opening it delegates to the VPN client registered in macOS.

## Interface visibility

Use the `Вид` button in a country header to hide services that are not needed on the main screen. Visibility is stored globally for PortGlide and persists between launches.

The following items can be controlled independently:

- SSH
- SOCKS5 Proxy
- applications launched through SOCKS5
- local VPN profile
- remote OpenVPN
- RDP tunnel

Hiding a running service does not stop it. Use `Показать всё` to restore the default layout.

## Recovery after deleting the source folder

The source repository, installed application, profiles, SSH configuration, and VPN secrets are intentionally stored separately:

- source: any Git clone of the PortGlide repository;
- installed app: `~/Applications/PortGlide.app` after running `scripts/install-user.sh`;
- country profiles: `~/Library/Application Support/PortGlide/profiles.json`;
- automatic profile backup: `~/Library/Application Support/PortGlide/profiles.backup.json`;
- private VPN material: `~/Library/Application Support/PortGlide/Private/`;
- SSH aliases and keys: `~/.ssh/`.

Deleting the source folder therefore does not delete the installed application or connection data. Clone the repository again only when source changes are needed. PortGlide automatically restores a missing or corrupt primary profile file from its backup.
