# Installation Guide

## Prerequisites

- PostgreSQL 12 or later
- PostgreSQL development headers
- C compiler (gcc/clang)
- make

## Architecture Note (macOS)

On macOS with Apple Silicon (M1/M2), ensure PostgreSQL is installed for the correct architecture:

```bash
# Check PostgreSQL architecture
file /usr/local/Cellar/postgresql@15/15.14/bin/postgres

# If mismatch, reinstall PostgreSQL for arm64
arch -arm64 brew reinstall postgresql@15
```

Or use Rosetta to build for x86_64:

```bash
arch -x86_64 make
```

## Build Instructions

```bash
# Clean previous builds
make clean

# Build the extension
make

# Install (requires sudo)
sudo make install

# Run tests
make installcheck
```

## Enable in PostgreSQL

```sql
CREATE EXTENSION pgr_dmmsy;
```

## Verify Installation

```sql
SELECT * FROM pg_available_extensions WHERE name = 'pgr_dmmsy';
```

## Troubleshooting

### Architecture Mismatch (macOS)

If you see errors like:
```
ld: warning: ignoring file '.../postgres': found architecture 'x86_64', required architecture 'arm64'
```

Solution:
1. Reinstall PostgreSQL for the correct architecture
2. Or compile with matching architecture using `arch` command

### Missing pg_config

```bash
# macOS with Homebrew
export PATH="/usr/local/opt/postgresql@15/bin:$PATH"

# Linux (Debian/Ubuntu)
sudo apt-get install postgresql-server-dev-15
```

### Permission Denied

```bash
# Use sudo for installation
sudo make install
```

## Uninstall

```sql
-- In PostgreSQL
DROP EXTENSION pgr_dmmsy;
```

```bash
# Remove files
sudo make uninstall
```

