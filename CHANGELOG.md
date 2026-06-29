# Changelog

## Unreleased

- Keep managed-application status synchronized with the actual macOS process state.
- Distinguish applications launched through PortGlide from applications opened elsewhere.
- Add OpenVPN credential rotation backed by macOS Keychain and SSH stdin.
- Refresh SOCKS5, RDP, and remote OpenVPN status from their real state every five seconds.
- Revalidate the complete OpenVPN and RDP path immediately before opening Windows App.
- Explicitly disable Remote Desktop Gateway for localhost SSH-tunnel connections.
- Recreate the generated app bundle before signing to avoid stale Finder/iCloud metadata.
- Move OpenVPN and RDP into a separate bottom `Удалённый доступ` section.
- Add persistent interface settings for hiding individual services and sections.

## 0.1.0

- Initial open-source release.
- Multi-profile SSH, SOCKS5, OpenVPN, and RDP controls.
- Per-application SOCKS5 launcher.
- Native macOS interface and signed local build workflow.
