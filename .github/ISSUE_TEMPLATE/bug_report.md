---
name: Bug Report
about: Report a bug in pgr_dmmsy
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description
A clear and concise description of what the bug is.

## To Reproduce
Steps to reproduce the behavior:

1. SQL query used:
```sql
-- Your SQL query here
```

2. Error message or unexpected behavior:
```
-- Error message or description
```

## Expected Behavior
A clear and concise description of what you expected to happen.

## Environment
- **PostgreSQL version**: (e.g., 15.3)
- **pgr_dmmsy version**: (e.g., 0.1.0)
- **Operating System**: (e.g., Ubuntu 22.04, macOS 13.0)
- **Architecture**: (e.g., x86_64, arm64)

## Graph Data
If applicable, provide a minimal example of the graph data that causes the issue:

```sql
CREATE TABLE test_edges (id BIGSERIAL, source BIGINT, target BIGINT, cost FLOAT8);
INSERT INTO test_edges VALUES ...;
```

## Additional Context
Add any other context about the problem here.

## Logs
If available, include relevant PostgreSQL logs:
```
-- Log output here
```

## Possible Solution
If you have suggestions on how to fix the bug, please describe them here.

