# Contributing to Cross-Chain Liquidity Aggregator

Thank you for your interest in contributing to the Cross-Chain Liquidity Aggregator! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **Bug Reports**: Help us identify and fix issues
- **Feature Requests**: Suggest new functionality
- **Code Contributions**: Submit bug fixes or new features
- **Documentation**: Improve or add documentation
- **Testing**: Add test cases or improve test coverage
- **Security**: Report security vulnerabilities responsibly

## 🚀 Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Clarinet](https://github.com/hirosystems/clarinet) (latest version)
- [Node.js](https://nodejs.org/) (v16 or higher)
- Basic understanding of Clarity smart contracts
- Familiarity with DeFi concepts

### Development Setup

1. **Fork the Repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/cross-chain-liquidity-aggregator.git
   cd cross-chain-liquidity-aggregator
   ```

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Verify Setup**
   ```bash
   # Check contract syntax
   clarinet check
   
   # Run tests
   clarinet test
   
   # Start development environment
   clarinet integrate
   ```

4. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

## 📝 Development Guidelines

### Code Standards

#### Clarity Contracts

- **Naming Conventions**:
  - Use kebab-case for function names: `add-liquidity`, `get-pool-info`
  - Use SCREAMING_SNAKE_CASE for constants: `MAX_FEE`, `ERR_UNAUTHORIZED`
  - Use descriptive variable names: `pool-id`, `amount-in`, `min-amount-out`

- **Function Structure**:
  ```clarity
  ;; Brief description of what the function does
  (define-public (function-name (param1 type) (param2 type))
    (let
      (
        (local-var (some-calculation))
      )
      ;; Input validation
      (asserts! (> param1 u0) ERR_INVALID_AMOUNT)
      
      ;; Main logic
      ;; ...
      
      (ok result)
    )
  )
  ```

- **Error Handling**:
  - Always use descriptive error constants
  - Validate inputs early in functions
  - Use `asserts!` for validation checks
  - Return meaningful error codes

- **Documentation**:
  - Add comments explaining complex logic
  - Document all public functions
  - Include parameter descriptions
  - Explain return values

#### JavaScript/TypeScript

- Use ES6+ features
- Follow Prettier formatting
- Use meaningful variable names
- Add JSDoc comments for functions
- Handle errors gracefully

### Testing Requirements

#### Unit Tests

All new functions must include comprehensive unit tests:

```typescript
Clarinet.test({
  name: "Test function with valid inputs",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    // Setup
    const deployer = accounts.get('deployer')!;
    
    // Execute
    let block = chain.mineBlock([
      Tx.contractCall('contract-name', 'function-name', [
        types.uint(validInput)
      ], deployer.address)
    ]);
    
    // Assert
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk();
  }
});
```

#### Test Categories

1. **Happy Path Tests**: Test normal operation
2. **Edge Case Tests**: Test boundary conditions
3. **Error Tests**: Test error conditions and validation
4. **Integration Tests**: Test contract interactions
5. **Security Tests**: Test access controls and safety mechanisms

### Security Considerations

#### Smart Contract Security

- **Access Control**: Verify only authorized users can call admin functions
- **Input Validation**: Validate all inputs thoroughly
- **Overflow Protection**: Use safe math operations
- **Reentrancy**: Prevent reentrancy attacks
- **State Consistency**: Ensure state changes are atomic

#### Common Vulnerabilities to Avoid

- Integer overflow/underflow
- Unauthorized access to admin functions
- Insufficient input validation
- Race conditions
- Price manipulation attacks

### Git Workflow

#### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `style`: Code style changes
- `chore`: Maintenance tasks

**Examples:**
```
feat(contracts): add cross-chain swap functionality

Add initiate-cross-chain-swap and complete-cross-chain-swap functions
with proper validation and event emission.

Closes #123

fix(tests): correct pool creation test assertions

The test was expecting wrong return values after the recent
contract updates.

docs(api): update function parameter descriptions

Add missing parameter descriptions for add-liquidity function.
```

#### Pull Request Process

1. **Create Feature Branch**
   ```bash
   git checkout -b feat/new-feature
   ```

2. **Make Changes**
   - Write code following our standards
   - Add comprehensive tests
   - Update documentation

3. **Test Thoroughly**
   ```bash
   npm run test
   npm run check
   npm run lint
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat(contracts): add new feature"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feat/new-feature
   ```
   Then create a Pull Request on GitHub.

#### Pull Request Template

When creating a PR, please include:

- **Description**: What does this PR do?
- **Type of Change**: Bug fix, new feature, documentation, etc.
- **Testing**: How was this tested?
- **Checklist**: 
  - [ ] Tests pass
  - [ ] Code follows style guidelines
  - [ ] Documentation updated
  - [ ] No breaking changes (or documented)

## 🐛 Bug Reports

### Before Reporting

1. Check existing issues to avoid duplicates
2. Test on the latest version
3. Reproduce the issue consistently

### Bug Report Template

```markdown
**Describe the Bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Call function '...'
2. With parameters '...'
3. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- Clarinet version:
- Network: testnet/mainnet
- Browser (if applicable):

**Additional Context**
Any other context about the problem.
```

## 💡 Feature Requests

### Feature Request Template

```markdown
**Feature Description**
A clear description of the feature you'd like to see.

**Use Case**
Describe the problem this feature would solve.

**Proposed Solution**
Your ideas on how this could be implemented.

**Alternatives Considered**
Other solutions you've considered.

**Additional Context**
Any other context or screenshots.
```

## 🔒 Security

### Reporting Security Vulnerabilities

**DO NOT** create public issues for security vulnerabilities.

Instead:
1. Email security concerns to: hexchange001@gmail.com
2. Include detailed description and reproduction steps
3. Allow reasonable time for response before public disclosure

### Security Review Process

All security-related changes undergo additional review:
- Code review by multiple maintainers
- Security-focused testing
- External audit consideration for major changes

## 📚 Documentation

### Documentation Standards

- Use clear, concise language
- Include code examples
- Keep documentation up-to-date with code changes
- Use proper markdown formatting

### Types of Documentation

1. **API Documentation**: Function signatures and usage
2. **Integration Guides**: How to use the protocol
3. **Architecture Documentation**: System design and concepts
4. **Tutorials**: Step-by-step guides

## 🎯 Code Review Process

### Review Criteria

- **Functionality**: Does the code work as intended?
- **Security**: Are there any security vulnerabilities?
- **Performance**: Is the code efficient?
- **Maintainability**: Is the code readable and well-structured?
- **Testing**: Are there adequate tests?
- **Documentation**: Is the code properly documented?

### Review Timeline

- Initial review within 48 hours
- Follow-up reviews within 24 hours
- Approval requires at least one maintainer review

## 🏆 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes for significant contributions
- Special recognition for security findings

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Email**: hexchange001@gmail.com for private matters

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to the Cross-Chain Liquidity Aggregator! Your contributions help make DeFi more accessible and secure for everyone.
