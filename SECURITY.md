# Security Policy

## On-Device Privacy Guarantee

EvalKit runs **entirely on-device**.

No user data, model output, evaluation result, or any other information is ever:
- Transmitted over a network
- Written outside the test bundle
- Shared with third parties

Every public file in this package includes the comment:
`// EvalKit — all processing is on-device. No data leaves the device.`

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.x     | ✅        |

## Dependencies

EvalKit has **zero external dependencies**. There are no third-party packages included or imported, which means no transitive supply chain risk.

## Reporting a Vulnerability

If you discover a security vulnerability in EvalKit, please **do not open a public GitHub issue**.

Instead, report it privately via:
- GitHub private vulnerability reporting: [Security tab → Report a vulnerability](https://github.com/ahmask/EvalKit/security/advisories/new)

You can expect an initial response within **72 hours**.

Please include:
- A clear description of the vulnerability
- Steps to reproduce it
- Potential impact

## License

EvalKit is released under the [MIT License](LICENSE).
