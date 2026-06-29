# Security Policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for security issues. Do not open a public issue containing credentials, server addresses, private keys, or exploit details.

## Secrets

PortGlide does not need repository-stored credentials. Keep these files outside the repository:

- OpenVPN profiles (`.ovpn`)
- SSH and TLS private keys
- PKCS#12 bundles (`.p12`, `.pfx`)
- Local profile exports and logs

Remote service control uses non-interactive `sudo -n`. Configure the narrowest possible sudoers rule for the exact `systemctl start` and `systemctl stop` commands required by a profile.
