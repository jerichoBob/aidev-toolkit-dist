---
id: AP-004
title: Test Critical Paths
severity: required
category: quality
applies_to: [all]
---

## Principle

All critical paths must have automated tests: business logic requires unit tests, integrations require integration tests, and code must be structured for testability.

## Rationale

Untested code is a liability. Tests catch regressions before they reach production, serve as executable documentation, and enable confident refactoring. The goal is not 100% coverage, but coverage of code that matters.

## Requirements

### Critical Path Coverage

- Business logic and calculations must have unit tests
- API endpoints must have integration tests
- Authentication and authorization flows must be tested
- Payment and financial operations must be thoroughly tested

### Testable Architecture

- Use dependency injection to enable mocking
- Separate business logic from I/O operations
- Avoid global state and singletons that complicate testing
- Keep functions pure where possible

### Test Quality

- Tests must be deterministic (no flaky tests)
- Tests should be independent (no shared state between tests)
- Test names should describe the expected behavior
- Arrange-Act-Assert (AAA) pattern for clarity

### Test Types

- **Unit tests**: Pure functions, business logic, calculations
- **Integration tests**: Database operations, API endpoints, external services
- **E2E tests**: Critical user journeys (sparingly, for high-value flows)

## Examples

### Good

```typescript
// Testable: dependency injection
class OrderService {
  constructor(
    private paymentGateway: PaymentGateway,
    private inventory: InventoryService,
  ) {}

  async processOrder(order: Order): Promise<Result> {
    // Business logic that can be tested with mocked dependencies
  }
}

// Clear test with AAA pattern
describe("OrderService", () => {
  it("should reject order when inventory insufficient", async () => {
    // Arrange
    const mockInventory = { check: jest.fn().mockResolvedValue(false) };
    const service = new OrderService(mockPayment, mockInventory);

    // Act
    const result = await service.processOrder(testOrder);

    // Assert
    expect(result.success).toBe(false);
    expect(result.reason).toBe("INSUFFICIENT_INVENTORY");
  });
});

// Integration test for API endpoint
describe("POST /api/orders", () => {
  it("should create order and return 201", async () => {
    const response = await request(app)
      .post("/api/orders")
      .send(validOrderPayload)
      .set("Authorization", `Bearer ${testToken}`);

    expect(response.status).toBe(201);
    expect(response.body.orderId).toBeDefined();
  });
});
```

### Bad

```typescript
// Untestable: hardcoded dependencies
class OrderService {
  async processOrder(order: Order) {
    const inventory = new InventoryService(); // Can't mock
    const result = await fetch("https://payment.api/charge"); // Can't mock
    // ...
  }
}

// Flaky test: depends on timing
it("should process quickly", async () => {
  const start = Date.now();
  await processOrder(order);
  expect(Date.now() - start).toBeLessThan(100); // Will fail randomly
});

// Test with no assertions
it("should work", async () => {
  await createUser(userData);
  // No assertions - test always passes
});

// Unclear test name
it("test1", () => {
  /* ... */
});
```

## Validation Checklist

- [ ] Business logic has unit test coverage
- [ ] API endpoints have integration tests
- [ ] Auth flows are tested
- [ ] Dependencies are injectable (not hardcoded)
- [ ] No flaky tests in the test suite
- [ ] Test names describe expected behavior
- [ ] Critical user journeys have E2E coverage
