# Pull Request

## Overview

Brief description of what this PR accomplishes and why it's needed.

## Type of Change

Please check all that apply:

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🔧 Refactoring (no functional changes)
- [ ] 🧪 Test improvements
- [ ] ⚡ Performance improvements
- [ ] 🔨 Build/CI improvements
- [ ] 🌍 Cross-platform compatibility changes

## Related Issues

Closes #(issue number)
Related to #(issue number)

## Changes Made

### Core Changes
- 
- 

### Tests
- 
- 

### Documentation
- 
- 

## Testing

### Test Plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Complexity analysis on self passes

### Test Commands
```bash
# Commands used to test this change
swift test
swift run swift-complexity Sources --threshold 15
```

## Complexity Analysis

### Self-Analysis Required

- [ ] Complexity analysis run on changed files
- [ ] No functions exceed threshold (15)
- [ ] New complex code is justified and documented

Run swift-complexity on your changes:
```bash
# Analyze changed files for complexity
swift run swift-complexity [changed-files] --threshold 15 --format text

# For comprehensive analysis
swift run swift-complexity Sources --threshold 15 --recursive --format json
```

**Results**: (paste results here or indicate no high-complexity functions added)

**Justification for complex functions**: (if any functions exceed threshold)

## Cross-Platform Compatibility

### Platform Testing

- [ ] Changes tested on macOS (Apple Silicon)
- [ ] Changes tested on macOS (Intel)
- [ ] Changes tested on Linux (Ubuntu 22.04+)
- [ ] Platform-specific code properly conditionally compiled

### Platform Considerations

- [ ] No platform-specific dependencies added
- [ ] Linux compatibility maintained
- [ ] macOS-specific features properly isolated (e.g., swift-format)

## Performance Impact

- [ ] No performance impact
- [ ] Performance improved
- [ ] Performance regression (with justification)

**Details**: (if applicable)

## Breaking Changes

- [ ] No breaking changes
- [ ] Breaking changes (describe below)

**Breaking Changes Description**: (if applicable)

## Screenshots/Output

(If applicable, add screenshots or example output)

## Checklist

### Code Quality
- [ ] Code follows the project's style guidelines
- [ ] Self-review of code completed
- [ ] Code is self-documenting with clear variable/function names
- [ ] Complex logic is commented where necessary

### Testing
- [ ] Tests added for new functionality
- [ ] Existing tests updated as needed
- [ ] All tests pass locally
- [ ] Edge cases considered and tested

### Documentation
- [ ] Documentation updated (if needed)
- [ ] README updated (if needed)
- [ ] CLAUDE.md updated (if architecture changes)
- [ ] API documentation updated (if applicable)

### Dependencies

- [ ] No new dependencies added
- [ ] New dependencies justified and documented
- [ ] Package.swift updated appropriately
- [ ] Cross-platform compatibility verified for new dependencies

### CI/CD

- [ ] CI pipeline passes (macOS & Linux)
- [ ] No new linting warnings introduced
- [ ] Code formatting validation passes (swift-format on macOS)
- [ ] Documentation linting passes (markdownlint)
- [ ] Self-complexity analysis in CI passes
- [ ] Release workflow compatibility maintained (if applicable)

## Additional Notes

(Any additional information that reviewers should know)

---

## For Reviewers

### Review Checklist

- [ ] **Complexity Analysis**: Results are reasonable and justified
- [ ] **Cross-Platform**: Changes work on both macOS and Linux
- [ ] **Test Coverage**: Adequate test coverage for new functionality
- [ ] **Documentation**: Updated appropriately for changes
- [ ] **CI/CD**: All automated checks pass
- [ ] **Architecture**: Changes align with project goals and patterns
- [ ] **Performance**: No unexpected performance regressions
- [ ] **Dependencies**: New dependencies are justified and secure

### Key Areas to Focus On

1. **Code Quality**: Maintainable, readable, and follows project conventions
2. **Platform Compatibility**: Proper handling of macOS/Linux differences
3. **Complexity Management**: New code doesn't unnecessarily increase complexity
4. **Test Quality**: Tests are comprehensive and meaningful
5. **Documentation**: Changes are properly documented for users and developers