# Commit and Activity Log Management

## Overview

This document outlines best practices for managing development activity logs through Git commits and GitHub features for the NexaNest project.

## Commit Strategy

### Use Commits For
- **Code changes** with descriptive messages
- **Feature implementations** with clear scope
- **Bug fixes** with issue references
- **Configuration updates** and infrastructure changes
- **Documentation updates** (when explicitly requested)

### Conventional Commit Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Types
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

#### Examples
```bash
feat(auth): add JWT token refresh endpoint

fix(portfolio): resolve calculation error in risk metrics (#123)

docs: update API documentation for v2.0

chore(deps): update FastAPI to v0.104.0
```

### Commit Best Practices

1. **Atomic commits**: One logical change per commit
2. **Descriptive messages**: Explain "why" not just "what"
3. **Include issue numbers**: Reference GitHub issues when applicable
4. **Present tense**: Use imperative mood ("add" not "added")
5. **Keep first line under 50 characters**
6. **Separate subject from body with blank line**

## GitHub Features for Activity Management

### Issues
- **Bug reports**: Detailed problem descriptions
- **Feature requests**: New functionality proposals
- **Epic tracking**: Large feature sets
- **Discussion threads**: Architecture decisions

### Pull Requests
- **Code review**: Quality assurance process
- **Feature integration**: Merging complete features
- **Documentation**: Change summaries and impact
- **CI/CD validation**: Automated testing results

### GitHub Projects
- **Sprint planning**: Milestone organization
- **Progress tracking**: Visual workflow management
- **Resource allocation**: Team coordination
- **Release planning**: Version milestone tracking

### GitHub Actions
- **Automated workflows**: CI/CD pipeline logs
- **Test results**: Automated quality checks
- **Deployment logs**: Infrastructure updates
- **Security scans**: Vulnerability assessments

## Recommended Workflow

### Daily Development
1. Create feature branch from main
2. Make atomic commits with conventional format
3. Reference issues in commit messages
4. Push regularly to remote branch

### Feature Completion
1. Create pull request with detailed description
2. Request code review from team members
3. Address review feedback in additional commits
4. Merge to main branch after approval

### Release Management
1. Tag releases with semantic versioning
2. Generate changelog from conventional commits
3. Create GitHub release with notes
4. Deploy through automated pipeline

## Tools and Automation

### Commit Message Validation
- Use pre-commit hooks to validate format
- Configure commitlint for conventional commits
- Set up automated changelog generation

### GitHub Integration
- Link commits to issues automatically
- Use PR templates for consistency
- Configure branch protection rules
- Enable status checks for quality gates

## Quick Commands

Use the project Makefile for common operations:

```bash
# Interactive commit with conventional format
make commit

# View recent commits with graph
make log

# Create new feature branch
make branch name=feature-name

# Push current branch to remote
make push
```

## Metrics and Tracking

### Development Velocity
- Commits per day/week/sprint
- Lines of code changed
- Issues resolved per sprint
- Pull request review time

### Quality Metrics
- Test coverage trends
- Bug fix vs feature ratio
- Code review feedback patterns
- CI/CD pipeline success rates

### Activity Visibility
- Contributor activity heatmaps
- Feature delivery timelines
- Issue resolution patterns
- Release frequency and stability