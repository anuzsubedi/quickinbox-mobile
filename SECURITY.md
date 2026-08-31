# Security policy

Please do not report security vulnerabilities in public issues, pull requests, or discussions.

## Reporting

Use GitHub's private security advisory flow for this repository when available. If that flow is unavailable, contact the maintainer privately through the GitHub account associated with this project and include QuickInbox Mobile security report in the subject.

Include:

- A clear description of the issue and affected platform (android, ios, or both).
- Reproduction steps or a minimal proof of concept.
- Affected versions, commit, device, OS, and server version where relevant.
- Potential impact, including credential, mail-content, pairing, transport, or HTML-rendering risks.
- Any suggested mitigation.

Do not include real credentials, private keys, live pairing codes, real user mail, or production server details in the report.

## Scope

Security-sensitive areas include pairing validation, server-origin validation, credential storage, authenticated requests, HTML mail rendering, attachment handling, local caches, and connected-device management.

Please allow reasonable time for investigation and a fix before public disclosure. The project may credit reporters who request credit, but will not publish private report contents without permission.

