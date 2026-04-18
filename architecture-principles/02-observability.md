---
id: AP-002
title: Observable Systems
severity: required
category: observability
applies_to: [all]
---

## Principle

All systems must be observable in production: emit structured logs with correlation IDs, expose health endpoints, and never log sensitive data.

## Rationale

You cannot fix what you cannot see. Production issues are inevitable; the difference between a 5-minute resolution and a 5-hour outage is observability. Structured, correlated logs enable fast debugging across distributed systems.

## Requirements

### Structured Logging

- Use JSON or structured log format (not plain text)
- Include consistent fields: timestamp, level, message, service name
- Use appropriate log levels (ERROR for failures, WARN for concerns, INFO for significant events, DEBUG for troubleshooting)

### Correlation & Tracing

- Generate or propagate correlation IDs for all requests
- Include correlation ID in all log entries for a request
- Pass correlation IDs across service boundaries

### Sensitive Data Protection

- Never log passwords, tokens, API keys, or secrets
- Never log full credit card numbers, SSNs, or PII
- Mask or redact sensitive fields before logging

### Health & Readiness

- Expose `/health` or `/healthz` endpoint for liveness checks
- Expose `/ready` endpoint for readiness checks (dependencies available)
- Health checks should verify critical dependencies (database, cache, external services)

## Examples

### Good

```typescript
// Structured logging with correlation
logger.info({
  correlationId: req.headers['x-correlation-id'],
  action: 'user.created',
  userId: user.id,
  duration: Date.now() - startTime
});

// Health endpoint with dependency check
app.get('/health', async (req, res) => {
  const dbHealthy = await db.ping().catch(() => false);
  const status = dbHealthy ? 200 : 503;
  res.status(status).json({
    status: dbHealthy ? 'healthy' : 'unhealthy',
    checks: { database: dbHealthy }
  });
});

// Redacting sensitive data
logger.info({
  action: 'payment.processed',
  cardLast4: card.number.slice(-4),  // Only last 4 digits
  amount: payment.amount
});
```

### Bad

```typescript
// Unstructured logging
console.log('User created: ' + user.id);

// No correlation ID - impossible to trace across services
logger.info('Processing payment');

// Logging sensitive data
logger.info({
  action: 'login',
  password: req.body.password,  // NEVER log passwords
  creditCard: payment.cardNumber  // NEVER log full card numbers
});

// Health endpoint that doesn't check dependencies
app.get('/health', (req, res) => res.json({ status: 'ok' }));
```

## Validation Checklist

- [ ] Logs are structured (JSON or equivalent)
- [ ] Correlation IDs present in log entries
- [ ] No sensitive data (passwords, tokens, PII) in logs
- [ ] Health endpoint exists and checks critical dependencies
- [ ] Appropriate log levels used (not everything is INFO or ERROR)
- [ ] Service name/version included in log context
