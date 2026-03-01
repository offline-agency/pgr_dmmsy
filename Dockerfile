# syntax=docker/dockerfile:1
# =============================================================
# pgr_dmmsy — Development & Test Image
# =============================================================
# Single-stage build based on the official PostgreSQL image.
# C unit tests (38 tests, no PG headers required) are executed
# at build time so the layer cache proves they pass.
#
# Build args:
#   PG_MAJOR  PostgreSQL major version (default: 16)
#
# Usage:
#   docker compose up -d db          # start the DB
#   docker compose --profile test run --rm test   # run verify suite
#   docker build --build-arg PG_MAJOR=15 -t pgr_dmmsy:pg15 .
# =============================================================

ARG PG_MAJOR=16
FROM postgres:${PG_MAJOR}-bookworm

ARG PG_MAJOR=16

# ---- build dependencies ------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        postgresql-server-dev-${PG_MAJOR} \
        postgresql-${PG_MAJOR}-postgis-3 \
        postgresql-${PG_MAJOR}-pgrouting \
    && rm -rf /var/lib/apt/lists/*

# ---- copy source -------------------------------------------------------
WORKDIR /pgr_dmmsy
COPY . .

# ---- build & install the extension ------------------------------------
# make clean removes any stale host-compiled .o files (e.g. macOS objects)
# that were copied in by COPY . . and would cause "file format not recognized".
RUN make clean \
    && make PG_CONFIG=/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config \
    && make install PG_CONFIG=/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config

# ---- compile & run C unit tests (no PostgreSQL needed) ---------------
# Fails the build immediately if any of the 38 tests fail.
RUN cd test/c \
    && make clean \
    && make \
    && ./test_graph \
    && ./test_minheap \
    && ./test_algorithm \
    && ./test_edge_cases \
    && echo "All C unit tests passed."

# ---- database initialisation scripts ----------------------------------
# The official postgres entrypoint runs *.sql / *.sh scripts in
# /docker-entrypoint-initdb.d/ on the very first container start.
COPY docker/initdb/ /docker-entrypoint-initdb.d/

# ---- defaults ---------------------------------------------------------
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=pgr_dmmsy_test

EXPOSE 5432
