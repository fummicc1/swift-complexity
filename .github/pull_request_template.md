# Pull Request

## Description

Brief description of what this PR does.

## Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🔧 Refactoring (no functional changes)
- [ ] 🧪 Test improvements
- [ ] ⚡ Performance improvements
- [ ] 🔨 Build/CI improvements

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

Run swift-complexity on your changes:
```bash
# Analyze changed files for complexity
swift run swift-complexity [changed-files] --threshold 15 --format text
```

**Results**: (paste results here or indicate no high-complexity functions added)

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

### CI/CD
- [ ] CI checks pass
- [ ] No new linting warnings introduced
- [ ] Code coverage maintained or improved

## Additional Notes

(Any additional information that reviewers should know)

---

**Reviewer Guidelines**:
- Check that complexity analysis results are reasonable
- Verify test coverage for new functionality
- Ensure documentation is updated appropriately
- Validate that the change aligns with project goals