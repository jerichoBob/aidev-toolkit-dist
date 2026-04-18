---
id: AP-001
title: Security by Default
severity: required
category: security
applies_to: [all]
---

## Principle

All code must follow secure-by-default practices: validate all inputs, never hardcode secrets, enforce authentication boundaries, and prevent injection attacks.

## Rationale

Security vulnerabilities are expensive to fix post-deployment and can cause catastrophic business impact. Shifting security left into development practices catches issues early when they're cheapest to address.

## Requirements

### Input Validation

- Validate all external inputs (API requests, form data, file uploads, URL parameters)
- Use allowlists over denylists where possible
- Validate on the server side, even if client-side validation exists

### Secrets Management

- Never commit secrets, API keys, or credentials to source control
- Use environment variables or secret management services (AWS Secrets Manager, HashiCorp Vault)
- Rotate secrets regularly and support rotation without downtime

### Authentication & Authorization

- Enforce authentication on all non-public endpoints
- Check authorization at the resource level, not just the route level
- Use established libraries/frameworks, never roll your own auth

### Injection Prevention

- Use parameterized queries or ORM methods for database access
- Sanitize outputs to prevent XSS (use framework defaults)
- Avoid dynamic code execution (eval, exec, Function constructor)

## Examples

### Good

```typescript
// Parameterized query - safe from SQL injection
const user = await db.query("SELECT * FROM users WHERE id = $1", [userId]);

// Environment-based secrets
const apiKey = process.env.STRIPE_API_KEY;

// Input validation with schema
const schema = z.object({
  email: z.string().email(),
  age: z.number().min(0).max(150),
});
const validated = schema.parse(request.body);
```

### Bad

```typescript
// String concatenation - SQL injection vulnerability
const user = await db.query(`SELECT * FROM users WHERE id = '${userId}'`);

// Hardcoded secret
const apiKey = "sk_live_abc123...";

// No input validation
const { email, age } = request.body;
```

## Validation Checklist

- [ ] No secrets or API keys in source code
- [ ] All database queries use parameterization or ORM
- [ ] External inputs are validated before use
- [ ] Authentication required on protected endpoints
- [ ] Authorization checks exist at resource level
- [ ] Dependencies scanned for known vulnerabilities
