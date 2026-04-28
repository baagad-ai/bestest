# Security Policy

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue in
**bestest**, please report it responsibly.

### How to Report

- **GitHub Issues (preferred):** Open a new issue with the `security` label.
  Include a clear description of the vulnerability, the affected component,
  and steps to reproduce if applicable.
- **Email:** Send details to [the maintainer](mailto:prajmishra204@gmail.com)
  with the subject line `[security] bestest vulnerability report`.

**Please do not publicly disclose the vulnerability before a fix is available.**

### What to Include

- Description of the vulnerability and its impact
- Affected version(s) or commit range
- Steps to reproduce (code snippets, commands, or configuration)
- Any suggested mitigations or fixes

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | ✅ Active development |
| Latest release | ✅ Full support  |
| Older releases | ❌ No longer maintained |

## Response Timeline

| Stage | Target |
| ----- | ------ |
| Acknowledgment | Within 48 hours |
| Initial assessment | Within 5 business days |
| Status update | Every 7 days until resolved |
| Fix (if accepted) | Best effort, priority based on severity |

## Scope

This policy covers the **bestest** skill and its bundled scripts (`validate-plugin.sh`,
`validate-skill.sh`, and all spoke files under `references/`).

Out of scope:
- Vulnerabilities in third-party tools or frameworks that bestest generates
  tests for (those should be reported to the respective projects)
- Issues in the user's own project code that bestest analyzes

## Disclosure Policy

- We follow **coordinated disclosure**: vulnerabilities are disclosed publicly
  only after a fix is merged and a release is available.
- Credit will be given to reporters unless they request anonymity.
