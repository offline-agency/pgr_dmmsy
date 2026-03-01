# Makefile for C unit tests

CC = gcc
CFLAGS = -Wall -Wextra -g -O0 -I../../src -DNO_PG_HEADERS
LDFLAGS = -lm

# Source files from main project
SRC_DIR = ../../src
GRAPH_SRC = $(SRC_DIR)/graph.c
MINHEAP_SRC = $(SRC_DIR)/minheap.c
ALGORITHM_SRC = $(SRC_DIR)/dmmsy_algorithm.c
BLOCKLIST_SRC = $(SRC_DIR)/ds_blocklist.c

# Test executables
TESTS = test_graph test_minheap test_algorithm test_edge_cases

.PHONY: all clean run

all: $(TESTS)

test_graph: test_graph.c $(GRAPH_SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

test_minheap: test_minheap.c $(MINHEAP_SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

test_algorithm: test_algorithm.c $(ALGORITHM_SRC) $(GRAPH_SRC) $(MINHEAP_SRC) $(BLOCKLIST_SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

test_edge_cases: test_edge_cases.c $(ALGORITHM_SRC) $(GRAPH_SRC) $(MINHEAP_SRC) $(BLOCKLIST_SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

run: all
	@echo "Running C unit tests..."
	@echo ""
	@./test_graph
	@echo ""
	@./test_minheap
	@echo ""
	@./test_algorithm
	@echo ""
	@./test_edge_cases
	@echo ""
	@echo "✅ All C unit tests completed!"

clean:
	rm -f $(TESTS) *.o *.gcno *.gcda coverage.info
	rm -rf coverage_html

# ---------------------------------------------------------------
# Coverage target — rebuilds with gcov instrumentation, runs all
# tests, then generates an lcov coverage.info for Codecov upload.
# Does NOT affect the default 'all' / 'run' targets.
# ---------------------------------------------------------------
# Build with gcov instrumentation and run all tests (generates .gcda files).
# lcov is intentionally NOT run here; run it from the project root so that
# --base-directory correctly marks src/ as internal, not external.
.PHONY: coverage-build
coverage-build:
	$(MAKE) clean
	$(MAKE) CFLAGS="$(CFLAGS) --coverage" LDFLAGS="$(LDFLAGS) --coverage"
	./test_graph && ./test_minheap && ./test_algorithm && ./test_edge_cases

# Convenience alias for local use: coverage-build + lcov with --base-directory
# pointing to the project root so src/ files are not filtered as external.
.PHONY: coverage
coverage: coverage-build
	lcov --capture \
	     --directory . \
	     --directory ../../src \
	     --base-directory ../.. \
	     --output-file coverage.info \
	     --no-external
	lcov --remove coverage.info '*/test/c/test_*' --output-file coverage.info

