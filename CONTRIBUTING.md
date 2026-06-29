# Contributing to PortGlide

Contributions are welcome.

1. Fork the repository and create a focused branch.
2. Keep secrets, server addresses, and personal profiles out of commits.
3. Add or update tests when behavior changes.
4. Run `swift test` and `swift build -c release`.
5. Open a pull request describing the behavior and validation performed.

## Code guidelines

- Keep system operations in `Sources/PortGlide/Services`.
- Pass executable arguments directly to `Process`; do not interpolate profile data into a local shell command.
- Keep profile validation in `Sources/PortGlide/Models`.
- Never terminate a process unless its command matches the expected tunnel and profile.
- Do not add telemetry or collect credentials.
