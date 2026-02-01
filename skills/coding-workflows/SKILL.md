---
name: coding-workflows
description: Use when writing new features, fixing bugs, implementing auth/API/input handling, or preparing for deployment. Provides TDD workflow, code review checklist, and pre-commit security checks.
---

# Coding Workflows

Combined TDD and security-review workflows for consistent code quality.

## When to Use

- Writing new features, fixing bugs, or refactoring
- Implementing authentication, API endpoints, or user input handling
- Working with secrets, file uploads, or sensitive data
- Before commit or deployment

---

## 1. TDD Workflow

### Principles

- **Tests BEFORE Code** – Write tests first, then implement
- **80%+ Coverage** – Unit + integration + E2E
- **RED → GREEN → REFACTOR** – Fail, pass, improve

### Steps

1. **User Journeys** – `As a [role], I want to [action], so that [benefit]`
2. **Write Tests** – Cover happy path, edge cases, errors
3. **Run Tests** – They should FAIL
4. **Implement** – Minimal code to pass
5. **Run Tests** – They should PASS
6. **Refactor** – Improve while keeping tests green
7. **Verify Coverage** – `npm run test:coverage` → 80%+

### Test Types

- **Unit** – Functions, components, utilities
- **Integration** – API routes, DB, external services
- **E2E** – Critical user flows (Playwright)

### Patterns

- One assert per test; descriptive names; Arrange-Act-Assert
- Mock external deps; test behavior, not implementation
- Use semantic selectors (`[data-testid]`, `button:has-text()`)

---

## 2. Code Review Checklist

Before marking work complete:

- [ ] Code readable, well-named
- [ ] Functions <50 lines, files <800 lines
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling
- [ ] No `console.log`, no hardcoded values
- [ ] Immutable patterns (no mutation)
- [ ] Tests passing, 80%+ coverage

---

## 3. Pre-Commit Security Checks

### Secrets

- [ ] No hardcoded API keys, tokens, passwords
- [ ] Use `process.env.*`; verify before use
- [ ] `.env` in `.gitignore`; no secrets in git history

### Input Validation

- [ ] All user input validated (e.g. Zod schemas)
- [ ] File uploads: size, type, extension limits
- [ ] No direct user input in SQL/queries

### SQL & Injection

- [ ] Parameterized queries only; no string concatenation in SQL

### Auth & Session

- [ ] Tokens in httpOnly cookies (not localStorage)
- [ ] Authorization checked before sensitive operations
- [ ] Row Level Security / RBAC where applicable

### XSS & CSRF

- [ ] User HTML sanitized (DOMPurify)
- [ ] CSRF tokens on state-changing ops
- [ ] SameSite=Strict on cookies

### API & Errors

- [ ] Rate limiting on endpoints
- [ ] Error messages generic for users (no stack traces)
- [ ] No sensitive data in logs

### Dependencies

- [ ] `npm audit` clean
- [ ] Lock files committed

---

## Quick Reference

| Phase | Action |
|-------|--------|
| New feature | TDD: tests → implement → refactor |
| Bug fix | Reproduce with test → fix → verify |
| Before commit | Code review + security checklist |
| Before deploy | Full pre-commit security checklist |
