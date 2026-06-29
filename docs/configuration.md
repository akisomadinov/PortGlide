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

## Local VPN profile

Selecting an `.ovpn` file stores its path only. Opening it delegates to the VPN client registered in macOS.
