# Troubleshooting

## Windows App reports `0x104`

This error happens before Windows authentication. It does not mean that an old Windows session is occupied.

1. Confirm that remote OpenVPN says `Включено` in PortGlide.
2. Enable the RDP tunnel and wait for `Работает`.
3. Use `Открыть RDP`; PortGlide checks the remote port again immediately before opening Windows App.
4. If Windows App offers `Edit Local Network Access`, allow **Windows App** in macOS **Privacy & Security → Local Network**, then retry.

Do not forcibly terminate the previous Windows session as a connectivity workaround. A normal RDP connection reconnects to the user's disconnected session, while forced logoff can discard unsaved work.

## Windows App reports a Remote Desktop Gateway error

PortGlide connects to `127.0.0.1` through a local SSH tunnel and does not need an RD Gateway. Generated `.rdp` files explicitly set `gatewayusagemethod:i:0` so a gateway saved in Windows App is not inherited.
