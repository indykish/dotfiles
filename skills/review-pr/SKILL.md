---
name: review-pr
description: Review PR/MR diffs for regressions, risks, and missing tests. Handles frontend, backend, and infrastructure changes with forge-aware CLI workflows.
---

# Review PR

Review a pull request or merge request by analyzing only the changed code. Covers frontend, backend, and infrastructure concerns.

## When to Use

- Before approving or merging a PR/MR
- When reviewing a teammate's changes
- After CI passes but before final sign-off
- Self-review before requesting reviewers

## Process

1. **Detect forge**
   ```bash
   git remote -v
   ```
   | Remote host contains | Use |
   |---|---|
   | `awakeninggit.e2enetworks.net` | `glab` |
   | `gitlab.com` | `glab` |
   | `github.com` | `gh` |

2. **Fetch the diff**
   ```bash
   # GitHub (current branch PR, or specify number)
   gh pr diff
   gh pr diff 42

   # GitLab
   glab mr diff
   glab mr diff 42
   ```

3. **Get PR/MR metadata**
   ```bash
   # GitHub
   gh pr view --json number,title,body,files,additions,deletions

   # GitLab
   glab mr view
   ```

4. **Review the changed code** against the checklist below

5. **Output findings** in the structured format

## Review Checklist

Review only the changed lines and their immediate context. Do not review unchanged code.

### Security
- Secrets or credentials added? (API keys, passwords, tokens in code or config)
- User input validated and sanitized? (SQL injection, XSS, command injection)
- Auth/permissions checked on new endpoints?
- Sensitive data excluded from logs?

### Correctness
- Does the change do what the PR description says?
- Edge cases handled? (nil/null, empty collections, zero values, boundary conditions)
- Error paths handled? (network failures, invalid input, missing resources)
- Race conditions possible? (concurrent access, shared mutable state)
- Database operations wrapped in transactions where needed?

### Performance
- N+1 queries introduced? (loops with DB calls, missing joins/preloads)
- Unbounded queries? (missing LIMIT, pagination for large datasets)
- Expensive operations in hot paths? (unnecessary allocations, redundant computation)
- Missing indexes on new queryable fields?

### Tests
- Are new code paths tested?
- Do tests cover error cases, not just happy path?
- Are tests deterministic? (no time-dependent, no random, no external service)
- Any test-only shortcuts that weaken coverage? (mocking too much, skipping validation)

### API Design (if endpoints changed)
- REST conventions followed? (correct HTTP methods, status codes)
- Breaking changes documented? (removed fields, changed behavior)
- Request/response schemas consistent with existing patterns?

### Code Quality
- Naming clear and consistent with the codebase?
- No dead code, commented-out blocks, or debug prints left in?
- Functions/methods focused on a single responsibility?
- No duplicated logic that should be extracted?

### Domain-Specific

**Frontend / UI:**
- Component structure follows framework conventions? (React hooks rules, Vue composition API)
- Accessibility (a11y) considerations? (ARIA labels, keyboard navigation, focus management)
- Responsive design implemented? (mobile breakpoints, touch targets)
- Error boundaries present for crash isolation?
- Loading states and skeletons for async data?
- Bundle size impact? (new dependencies, tree-shaking, lazy loading)
- CSS organization? (BEM, CSS-in-JS, utility classes)
- Form validation and error messaging?
- Image optimization? (formats, lazy loading, responsive images)

**Backend / API:**
- Database transactions used where needed? (multi-table operations, financial data)
- API rate limiting considered? (throttling, abuse prevention)
- Caching strategy appropriate? (TTL, cache invalidation, stale-while-revalidate)
- Pagination for list endpoints? (offset vs cursor-based for large datasets)
- Input validation at API boundary? (schema validation, sanitization)
- Error responses follow consistent format? (status codes, error codes, messages)
- Async processing for long operations? (queues, background jobs)
- Logging appropriate level? (structured logs, no PII in logs)
- Circuit breakers for external calls? (resilience patterns)
- Database query optimization? (indexes, N+1 prevention, query complexity)

### Language-Specific

**Python:**
- Type hints on new functions?
- Context managers for resources? (`with` for files, connections)
- f-strings instead of `.format()` or `%`?
- FastAPI: dependency injection used correctly?
- Django: ORM queries optimized? (select_related, prefetch_related)

**Go:**
- Errors checked and wrapped with context?
- Defer used for cleanup?
- No goroutine leaks? (context cancellation, WaitGroup)
- HTTP handlers have proper timeouts?

**Rust:**
- `unwrap()`/`expect()` justified or replaced with proper error handling?
- Ownership/borrowing correct? (no unnecessary clones)
- `unsafe` blocks justified and documented?
- Async runtime boundaries clear?

**TypeScript:**
- No `any` without justification?
- Proper null/undefined handling?
- Async/await errors caught?
- Strict mode enabled in tsconfig?

## Output Format

```markdown
## PR Review: [PR/MR title] (#number)

**Files changed:** N | **Additions:** +N | **Deletions:** -N

### Blocking Issues
- **[Category]**: [Description]
  - **Location**: `path/to/file:42`
  - **Risk**: [What could go wrong]
  - **Fix**: [Suggested change]

### Warnings
- **[Category]**: [Description]
  - **Location**: `path/to/file:15`
  - **Suggestion**: [How to improve]

### Observations
- [Non-blocking note or question about design intent]

### Looks Good
- [What's done well in this PR]

### Verdict: APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION
[One-line summary of the review outcome]
```

## Important

- **Review only the diff.** Do not critique unchanged code.
- **Security issues block merging.** Always flag as blocking.
- **Ask, don't assume.** If intent is unclear, add to Observations as a question.
- **No style nitpicks** unless they affect readability or correctness.
- **Check the tests.** Missing tests for new behavior is a blocking issue.
