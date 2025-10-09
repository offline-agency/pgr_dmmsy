#!/bin/bash

# Test runner script for pgr_dmmsy
# Runs both C unit tests and SQL integration tests

set -e  # Exit on first error

echo "=========================================="
echo "pgr_dmmsy Test Suite"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track test results
C_TESTS_PASSED=0
SQL_TESTS_PASSED=0
TOTAL_FAILURES=0

# Function to run C tests
run_c_tests() {
    echo "=========================================="
    echo "Running C Unit Tests"
    echo "=========================================="
    echo ""
    
    cd test/c
    
    if ! make clean > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: make clean failed${NC}"
    fi
    
    if make > /dev/null 2>&1; then
        if make run; then
            C_TESTS_PASSED=1
            echo -e "${GREEN}✅ C unit tests passed${NC}"
        else
            echo -e "${RED}❌ C unit tests failed${NC}"
            TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        fi
    else
        echo -e "${RED}❌ C unit tests compilation failed${NC}"
        TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    fi
    
    cd ../..
    echo ""
}

# Function to run SQL tests
run_sql_tests() {
    echo "=========================================="
    echo "Running SQL Integration Tests"
    echo "=========================================="
    echo ""
    
    # Check if PostgreSQL is accessible
    if ! command -v psql &> /dev/null; then
        echo -e "${RED}❌ psql not found. Cannot run SQL tests.${NC}"
        TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        return
    fi
    
    # Check if extension is installed
    if ! psql -c "CREATE EXTENSION IF NOT EXISTS pgr_dmmsy;" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Extension not installed. Run 'sudo make install' first.${NC}"
        echo "Skipping SQL tests..."
        return
    fi
    
    # Run SQL test files
    SQL_TEST_FILES=(
        "test/sql/test_basic.sql"
        "test/sql/test_edge_cases.sql"
        "test/sql/test_parameters.sql"
        "test/sql/test_performance.sql"
    )
    
    SQL_PASSED=0
    SQL_FAILED=0
    
    for test_file in "${SQL_TEST_FILES[@]}"; do
        if [ -f "$test_file" ]; then
            echo "Running $(basename $test_file)..."
            if psql -f "$test_file" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ $(basename $test_file) passed${NC}"
                SQL_PASSED=$((SQL_PASSED + 1))
            else
                echo -e "${RED}❌ $(basename $test_file) failed${NC}"
                SQL_FAILED=$((SQL_FAILED + 1))
                TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
            fi
        fi
    done
    
    echo ""
    echo "SQL Tests: $SQL_PASSED passed, $SQL_FAILED failed"
    
    if [ $SQL_FAILED -eq 0 ]; then
        SQL_TESTS_PASSED=1
    fi
    
    echo ""
}

# Function to run regression tests
run_regression_tests() {
    echo "=========================================="
    echo "Running PostgreSQL Regression Tests"
    echo "=========================================="
    echo ""
    
    if make installcheck 2>&1 | grep -q "PASSED"; then
        echo -e "${GREEN}✅ Regression tests passed${NC}"
    else
        if [ -f regression.diffs ]; then
            echo -e "${RED}❌ Regression tests failed${NC}"
            echo ""
            echo "Differences found:"
            cat regression.diffs
            TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        else
            echo -e "${YELLOW}⚠️  Could not run regression tests${NC}"
        fi
    fi
    
    echo ""
}

# Main execution
main() {
    # Check if we're in the right directory
    if [ ! -f "pgr_dmmsy.control" ]; then
        echo -e "${RED}Error: Not in pgr_dmmsy root directory${NC}"
        exit 1
    fi
    
    # Run C tests
    if [ -d "test/c" ]; then
        run_c_tests
    else
        echo -e "${YELLOW}⚠️  C test directory not found${NC}"
    fi
    
    # Run SQL tests
    if [ -d "test/sql" ]; then
        run_sql_tests
    else
        echo -e "${YELLOW}⚠️  SQL test directory not found${NC}"
    fi
    
    # Run regression tests
    if [ -f "test/pgr_dmmsy.sql" ]; then
        run_regression_tests
    fi
    
    # Summary
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo ""
    
    if [ $C_TESTS_PASSED -eq 1 ]; then
        echo -e "${GREEN}✅ C unit tests: PASSED${NC}"
    else
        echo -e "${RED}❌ C unit tests: FAILED${NC}"
    fi
    
    if [ $SQL_TESTS_PASSED -eq 1 ]; then
        echo -e "${GREEN}✅ SQL integration tests: PASSED${NC}"
    else
        echo -e "${RED}❌ SQL integration tests: FAILED or SKIPPED${NC}"
    fi
    
    echo ""
    
    if [ $TOTAL_FAILURES -eq 0 ]; then
        echo -e "${GREEN}=========================================="
        echo "🎉 ALL TESTS PASSED!"
        echo -e "==========================================${NC}"
        exit 0
    else
        echo -e "${RED}=========================================="
        echo "❌ $TOTAL_FAILURES TEST SUITE(S) FAILED"
        echo -e "==========================================${NC}"
        exit 1
    fi
}

# Run main
main

