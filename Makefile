EXTENSION = pgr_dmmsy
MODULE_big = pgr_dmmsy
OBJS = src/dmmsy.o src/dmmsy_algorithm.o src/graph.o src/minheap.o src/ds_blocklist.o
DATA = sql/pgr_dmmsy--0.1.0.sql
PGFILEDESC = "pgr_dmmsy - DMMSY SSSP (Duan–Mao–Mao–Shu–Yin 2025)"
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
REGRESS = pgr_dmmsy
