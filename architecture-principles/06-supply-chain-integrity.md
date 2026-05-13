---
id: AP-006
title: Supply Chain Integrity
severity: required
category: security
applies_to: [all]
---

## Principle

Every project must treat its dependency graph as an attack surface. npm packages, GitHub Actions, and CI/CD pipelines are active targets for supply chain attacks — compromised packages can steal secrets, self-propagate, and publish poisoned releases before detection.

## Rationale

Supply chain attacks (e.g., Mini Shai-Hulud, event-stream, ua-parser-js) compromise projects not through application code but through trusted tooling. Malicious `postinstall` hooks execute at install time with full access to environment variables, filesystem secrets, and cloud credentials. A single compromised transitive dependency can exfiltrate tokens and republish itself across every package the victim can publish — making the blast radius multiplicative, not linear.

## Requirements

### Lockfile Enforcement

- Commit `package-lock.json`, `yarn.lock`, or `pnpm-lock.yaml` to source control
- Use `npm ci` (not `npm install`) in all CI/CD pipelines — `ci` respects the lockfile exactly
- Block merges that modify lockfiles without a corresponding `package.json` change review
- Pin exact versions (`1.2.3`) in production dependencies, not ranges (`^1.2.3`)

### Dependency Vetting

- Configure Dependabot or Renovate with a `minimumReleaseAge` of at least 3 days for non-security updates — community vetting time catches most supply chain attacks before they reach you
- Restrict auto-merge to security-only updates; all other dependency bumps require human review
- Run `npm audit --audit-level=high` in CI and fail the build on high/critical findings

### Lifecycle Hook Auditing

- Review `preinstall`, `postinstall`, and `prepare` scripts in all direct dependencies before adding them
- Treat any package that runs scripts during install as elevated risk
- Search for unexpected lifecycle scripts after dependency changes: `find node_modules -name package.json -exec grep -l "preinstall\|postinstall\|prepare" {} \;`

### Secret Exposure in CI/CD

- Never print environment variables in CI logs (`set -x` or `env` in workflows)
- Scope GitHub Actions OIDC tokens to the minimum required permissions
- Use short-lived credentials; avoid long-lived tokens in CI secrets where OIDC is available
- Audit GitHub Actions workflows for unexpected `npm publish` or package registry interactions

### Incident Response Triggers

If any of the following are found in a dependency, treat it as a confirmed compromise and rotate all secrets immediately:

- Unexpected files: `router_init.js`, `tanstack_runner.js`, or similar obfuscated runners in well-known packages
- Optional dependencies pointing to GitHub-hosted (not registry-hosted) packages
- `bun` execution during `npm install`
- Outbound network connections during package installation

## Validation Checklist

- [ ] Lockfile is committed and `npm ci` is used in CI
- [ ] Production dependencies use exact version pins
- [ ] Dependabot/Renovate configured with minimum release age for non-security updates
- [ ] `npm audit` runs in CI and fails on high/critical
- [ ] No unexpected `postinstall` scripts in direct dependencies
- [ ] CI/CD secrets are short-lived or OIDC-based where possible
- [ ] Incident response plan exists for secret rotation if compromise is detected

## Examples

### Good — Renovate config with release age delay

```json
{
  "extends": ["config:base"],
  "minimumReleaseAge": "3 days",
  "automerge": false,
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "matchDepTypes": ["devDependencies"],
      "automerge": true,
      "minimumReleaseAge": "3 days"
    }
  ]
}
```

### Good — GitHub Actions with scoped permissions

```yaml
permissions:
  contents: read
  id-token: write  # Only if OIDC is required

steps:
  - run: npm ci   # Not npm install
  - run: npm audit --audit-level=high
```

### Bad — Range versions and npm install in CI

```json
{
  "dependencies": {
    "@tanstack/router": "^1.0.0"
  }
}
```

```yaml
- run: npm install  # Ignores lockfile, can pull newer compromised versions
```
