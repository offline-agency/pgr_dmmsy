# Installation Quick Reference

## Prerequisites

- PostgreSQL **14** or later
- pgRouting 3.x (required extension dependency)
- PostgreSQL development headers (`postgresql-server-dev-NN`)
- C compiler (gcc / clang) and GNU Make

## Build and Install

```bash
make
sudo make install
```

To target a specific PostgreSQL version:

```bash
make PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
sudo make install PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
```

## Enable in a Database

```sql
-- pgRouting must be installed first (declared dependency)
CREATE EXTENSION pgrouting;
CREATE EXTENSION pgr_dmmsy;
```

## Verify

```sql
SELECT extversion FROM pg_extension WHERE extname = 'pgr_dmmsy';
```

## Uninstall

```sql
DROP EXTENSION pgr_dmmsy;
```

```bash
sudo make uninstall
```

## Troubleshooting

**`pg_config: command not found`** — add PostgreSQL's `bin/` to your PATH:
```bash
export PATH="/usr/lib/postgresql/16/bin:$PATH"          # Linux
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH" # macOS Apple Silicon
```

**Architecture mismatch on macOS** — reinstall for the correct architecture:
```bash
arch -arm64 brew reinstall postgresql@16
```

**`ERROR: required extension "pgrouting" is not installed`**
```sql
CREATE EXTENSION pgrouting;
CREATE EXTENSION pgr_dmmsy;
```

See **[COMPILE.md](COMPILE.md)** for complete platform-specific instructions
and Docker workflow.
