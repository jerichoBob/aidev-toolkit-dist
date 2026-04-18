---
id: AP-003
title: Intentional Error Handling
severity: required
category: reliability
applies_to: [all]
---

## Principle

All errors must be handled intentionally: never swallow exceptions silently, use consistent error response formats, and never expose internal details to clients.

## Rationale

Poor error handling is a top cause of production incidents. Silent failures mask bugs until they cascade into outages. Inconsistent error formats burden API consumers. Leaked stack traces create security vulnerabilities and confuse end users.

## Requirements

### No Silent Failures

- Never use empty catch blocks
- Log all caught exceptions with context
- Re-throw or handle meaningfully, never just suppress

### Consistent Error Responses

- Use a standard error response format across all APIs
- Include: error code, user-friendly message, correlation ID
- Use appropriate HTTP status codes (4xx for client errors, 5xx for server errors)

### Internal Details Protection

- Never expose stack traces to clients in production
- Never expose internal paths, database schemas, or infrastructure details
- Log full details server-side, return sanitized messages to clients

### Error Propagation

- Let errors bubble up to centralized handlers where appropriate
- Add context as errors propagate (which operation, which resource)
- Preserve original error information for debugging

## Examples

### Good

```typescript
// Consistent error response format
class ApiError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    public userMessage: string,
    public context?: Record<string, unknown>
  ) {
    super(userMessage);
  }
}

// Centralized error handler
app.use((err, req, res, next) => {
  const correlationId = req.headers['x-correlation-id'];

  // Log full details server-side
  logger.error({
    correlationId,
    error: err.message,
    stack: err.stack,
    context: err.context
  });

  // Return sanitized response to client
  res.status(err.statusCode || 500).json({
    error: {
      code: err.code || 'INTERNAL_ERROR',
      message: err.userMessage || 'An unexpected error occurred',
      correlationId
    }
  });
});

// Meaningful error handling with context
try {
  await processPayment(order);
} catch (error) {
  logger.error({ orderId: order.id, error: error.message });
  throw new ApiError(500, 'PAYMENT_FAILED', 'Unable to process payment');
}
```

### Bad

```typescript
// Silent catch - bugs will hide here
try {
  await saveUser(user);
} catch (e) {
  // do nothing - silent failure
}

// Exposing internal details to client
app.use((err, req, res, next) => {
  res.status(500).json({
    error: err.message,
    stack: err.stack,  // Exposes internals
    query: err.sql     // Exposes database details
  });
});

// Inconsistent error responses
res.status(400).send('bad request');  // One endpoint
res.status(400).json({ msg: 'Invalid' });  // Another endpoint
res.status(400).json({ error: { message: 'Wrong' } });  // Yet another
```

## Validation Checklist

- [ ] No empty catch blocks
- [ ] All caught exceptions are logged with context
- [ ] Consistent error response format across APIs
- [ ] No stack traces or internal details exposed to clients
- [ ] Appropriate HTTP status codes used
- [ ] Centralized error handling in place
- [ ] Errors include correlation ID for tracing
