# Contributing to pgr_dmmsy

Thank you for your interest in contributing to pgr_dmmsy! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain a welcoming environment

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourusername/pgr_dmmsy/issues)
2. Use the bug report template
3. Include:
   - Clear description of the issue
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (PostgreSQL version, OS, etc.)
   - Minimal test case if possible

### Suggesting Features

1. Check if the feature has already been requested
2. Use the feature request template
3. Clearly describe:
   - The use case
   - Proposed solution
   - Example usage
   - Impact on the algorithm

### Submitting Pull Requests

1. **Fork the repository**

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make your changes**
   - Follow the existing code style
   - Add comments for complex logic
   - Update documentation as needed

4. **Test your changes**
   ```bash
   make clean
   make
   sudo make install
   make installcheck
   ```

5. **Commit your changes**
   ```bash
   git commit -m "Brief description of changes"
   ```
   
   Use clear, descriptive commit messages:
   - `fix: correct path reconstruction for disconnected graphs`
   - `feat: add support for negative-weight edges`
   - `docs: update README with installation instructions`
   - `test: add test cases for large graphs`

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request**
   - Use the PR template
   - Link related issues
   - Describe your changes clearly
   - Include test results

## Development Setup

### Prerequisites

- PostgreSQL 12+ with development headers
- C compiler (gcc or clang)
- make
- Git

### Building from Source

```bash
git clone https://github.com/yourusername/pgr_dmmsy.git
cd pgr_dmmsy
make
sudo make install
```

### Running Tests

```bash
make installcheck
```

### Cleaning Build Artifacts

```bash
make clean
```

## Coding Standards

### C Code Style

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 100 characters max
- **Naming conventions**:
  - Functions: `snake_case` (e.g., `graph_add_edge`)
  - Structs: `PascalCase` (e.g., `Graph`, `MinHeap`)
  - Constants: `UPPER_SNAKE_CASE` (e.g., `INFINITY_DIST`)
  - Variables: `snake_case`

- **Comments**:
  ```c
  /* Single-line comment */
  
  /*
   * Multi-line comment explaining
   * complex algorithm logic
   */
  ```

- **Function structure**:
  ```c
  /**
   * Brief function description
   * 
   * @param graph  The graph structure
   * @param params Algorithm parameters
   * @return Pointer to result or NULL on error
   */
  DMMSYResult* dmmsy_compute(Graph *graph, DMMSYParams *params) {
      /* Declare all variables at the top (C89 compatibility) */
      int64_t i;
      DMMSYResult *result;
      
      /* Function body */
      ...
  }
  ```

### SQL Code Style

- Keywords in UPPERCASE
- Consistent indentation
- Clear function comments
- Include usage examples

### Error Handling

- Always check for NULL after malloc
- Free allocated memory in error paths
- Use PostgreSQL's `ereport` for errors
- Provide meaningful error messages

### Memory Management

- Clean up all allocated resources
- Use PostgreSQL memory contexts where appropriate
- No memory leaks (verify with valgrind)

## Testing Guidelines

### Test Coverage

Ensure your changes are well-tested:

- **Unit level**: Test individual functions
- **Integration**: Test SQL function end-to-end
- **Edge cases**: Empty graphs, disconnected graphs, cycles, etc.
- **Performance**: Test with large graphs when relevant

### Writing Tests

Add tests to `test/pgr_dmmsy.sql`:

```sql
-- Test case N: Description
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 2.0);

SELECT '-- Test N: Description' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    3
) ORDER BY path_seq;
```

Update `test/expected/pgr_dmmsy.out` with expected results.

## Documentation

### Code Comments

- Explain "why", not just "what"
- Document algorithm complexity where relevant
- Reference the DMMSY paper for algorithm-specific code

### README Updates

Update README.md when:
- Adding new features
- Changing function signatures
- Modifying installation steps
- Adding new parameters

### SQL Function Documentation

Update `sql/pgr_dmmsy--0.1.0.sql` comments when changing the function interface.

## Performance Considerations

- Profile before optimizing
- Document complexity claims
- Consider memory usage
- Test with large graphs (1000+ vertices)
- Compare with baseline (Dijkstra) when relevant

## Algorithm Implementation

When modifying the core DMMSY algorithm:

1. **Understand the paper**: Reference [arxiv.org/abs/2504.17033](https://arxiv.org/abs/2504.17033)
2. **Maintain correctness**: Verify results match expected shortest paths
3. **Document changes**: Update `IMPLEMENTATION_NOTES.md`
4. **Test edge cases**: Cycles, disconnected graphs, equal-cost paths
5. **Benchmark**: Compare time complexity empirically

## Release Process

Maintainers follow this process for releases:

1. Update version in `pgr_dmmsy.control`
2. Update `CHANGELOG.md` (if exists)
3. Tag release: `git tag -a v0.2.0 -m "Release 0.2.0"`
4. Push tag: `git push origin v0.2.0`
5. GitHub Actions creates release artifacts

## Getting Help

- **Issues**: Ask questions in GitHub Issues
- **Discussions**: Use GitHub Discussions for broader topics
- **Documentation**: Check README.md and IMPLEMENTATION_NOTES.md

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS file (if we create one)
- Credited in release notes
- Acknowledged in documentation

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

---

Thank you for contributing to pgr_dmmsy! 🚀

