# ![Git](../images/logos/git.svg) Version Control Guide for SaaS Development

![Git Workflow](../images/git-workflow.png)
*Professional version control strategies and workflows for SaaS teams*

## Overview

Version control is essential for team collaboration and code quality in SaaS development. This guide covers Git fundamentals, branching strategies, commit practices, code review workflows, and CI/CD integration patterns used by professional development teams.

## Git Fundamentals

### Initial Setup

```bash
# Configure global Git settings
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global core.editor "vim"

# Configure line endings (important for team consistency)
git config --global core.autocrlf input  # macOS/Linux
git config --global core.autocrlf true   # Windows

# Set default branch name
git config --global init.defaultBranch main

# Verify configuration
git config --list
```

### .gitignore Setup

```bash
# .gitignore - Repository root
# Node modules
node_modules/
npm-debug.log
yarn-error.log
.yarn/cache

# Python
__pycache__/
*.py[cod]
*$py.class
.Python
env/
venv/
ENV/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Environment variables
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Build outputs
dist/
build/
*.min.js
*.min.css

# Coverage reports
coverage/
.nyc_output/

# Logs
logs/
*.log

# Temporary files
tmp/
temp/

# Sensitive files
.ssh/
*.pem
*.key
secrets.yml
```

## Branching Strategies

### Git Flow (Recommended for SaaS)

```
main (production)
  └─ release/1.2.0
    └─ hotfix/critical-bug
develop (staging)
  ├─ feature/user-auth
  ├─ feature/api-redesign
  └─ bugfix/login-issue
```

#### Git Flow Commands

```bash
# Initialize Git Flow
git flow init

# Create feature branch
git flow feature start user-authentication
# Equivalent to: git checkout -b feature/user-authentication develop

# Finish feature (auto-merge to develop)
git flow feature finish user-authentication

# Create release branch
git flow release start 1.2.0

# Finish release (merge to main and develop)
git flow release finish 1.2.0

# Create hotfix branch
git flow hotfix start critical-security-patch
git flow hotfix finish critical-security-patch
```

### GitHub Flow (Simplified)

```
main (always deployable)
  ├─ feature/auth-improvements
  ├─ fix/database-connection
  └─ docs/api-documentation
```

#### GitHub Flow Workflow

```bash
# Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/auth-improvements

# Work on feature
git add .
git commit -m "feat: implement JWT refresh tokens"
git push origin feature/auth-improvements

# Create Pull Request (via GitHub UI)
# After review and approval:
git checkout main
git pull origin main
git merge feature/auth-improvements
git push origin main

# Cleanup
git branch -d feature/auth-improvements
git push origin --delete feature/auth-improvements
```

## Commit Conventions

### Conventional Commits

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

#### Types

```
feat:     New feature
fix:      Bug fix
refactor: Code refactoring
perf:     Performance improvement
test:     Testing changes
docs:     Documentation
ci:       CI/CD configuration
chore:    Maintenance, dependencies
style:    Code style (formatting, missing semicolons, etc)
```

#### Examples

```bash
# Simple commit
git commit -m "feat: implement password reset functionality"

# With scope
git commit -m "feat(auth): add JWT token refresh endpoint"

# With body and footer
git commit -m "fix(api): prevent race condition in user creation

- Added database transaction wrapper
- Implemented request deduplication
- Added retry logic with exponential backoff

Fixes #1234
Closes #5678"

# Feature with breaking change
git commit -m "feat(api)!: redesign user response format

BREAKING CHANGE: User endpoint now returns full profile object
instead of nested user_id. Migration guide in UPGRADE.md"
```

#### Commit Template

```bash
# Create .gitmessage file
cat > ~/.gitmessage << 'EOF'
# <type>(<scope>): <subject>
# |<----  Using a maximum of 50 characters  ---->|

# Explain why this change is being made
# |<----   Try to limit to 72 characters   ---->|

# Provide links or keys to any relevant tickets, articles or other resources

# --- COMMIT END ---
# Type can be:
#   feat     (new feature)
#   fix      (bug fix)
#   refactor (refactoring code)
#   perf     (performance improvement)
#   test     (adding tests)
#   docs     (documentation)
#   ci       (CI/CD config)
#   chore    (maintenance)
#   style    (code style)
#
# Scope is optional, e.g. (auth), (api), (database)
#
# Remember to:
#  - Start with imperative mood ("add" not "added")
#  - No period at the end
#  - Separate subject from body with blank line
# --- END ---
EOF

# Configure Git to use the template
git config --global commit.template ~/.gitmessage
```

## Pull Request Workflow

### Creating a Pull Request

```markdown
# Title
feat(auth): implement multi-factor authentication

## Description
Implements TOTP-based multi-factor authentication for enhanced account security.

## Motivation
- Users requested additional security options
- Industry best practice for SaaS applications
- Reduces unauthorized access incidents

## Changes
- [ ] Added TOTP secret generation and storage
- [ ] Implemented MFA verification endpoint
- [ ] Updated user model to store MFA preferences
- [ ] Added migration for database schema
- [ ] Created frontend component for MFA setup

## Testing
- [x] Added unit tests for TOTP validation
- [x] Added integration tests for MFA flows
- [x] Manual testing on staging environment
- [x] Tested with authenticator apps (Google, Microsoft)

## Checklist
- [x] Code follows style guidelines
- [x] Self-review completed
- [x] Comments added for complex logic
- [x] Documentation updated
- [x] No new warnings generated
- [x] Tests added and passing
- [x] Breaking changes documented

## Screenshots (if applicable)
[Include MFA setup flow screenshots]

## Related Issues
Closes #1234
Related to #5678

## Deployment Notes
- Requires database migration
- Feature flag: `MFA_ENABLED` (defaults to false)
- Can be safely rolled back
```

### Code Review Best Practices

```bash
# Reviewer: Clone and test PR locally
git fetch origin pull/1234/head:pr-1234
git checkout pr-1234
npm install
npm test
npm run lint

# Reviewer: Add review comments
# Use GitHub's suggestion feature for code changes

# Reviewer: Approve or request changes
# Approval: "Looks good to me!"
# Changes: "Please address the following..."

# Author: Address comments
git add .
git commit -m "refactor: address review comments"
git push origin feature-branch

# Merge after approval
# Use "Squash and merge" for feature branches
# Use "Create a merge commit" for release branches
# Never use "Rebase and merge" in main branch
```

## Local Development Workflow

### Feature Development

```bash
# Start feature branch
git checkout develop
git pull origin develop
git checkout -b feature/new-feature

# Make changes
git add .
git commit -m "feat(scope): implement feature"

# Keep branch up to date
git fetch origin
git rebase origin/develop

# Push to remote
git push origin feature/new-feature

# Create Pull Request on GitHub
# After approval and merge:
git checkout develop
git pull origin develop
git branch -d feature/new-feature
```

### Bug Fixes

```bash
# Create bugfix branch from develop
git checkout develop
git pull origin develop
git checkout -b bugfix/login-error

# Fix the issue
git add .
git commit -m "fix(auth): resolve login redirect issue"

# If hotfix needed in production:
git checkout main
git pull origin main
git checkout -b hotfix/login-error
git cherry-pick <commit-hash>
git push origin hotfix/login-error
```

### Syncing with Main Branch

```bash
# Method 1: Rebase (preferred for feature branches)
git fetch origin
git rebase origin/develop
# If conflicts occur:
# - Resolve conflicts
# - git add .
# - git rebase --continue
# - git push origin feature-branch --force-with-lease

# Method 2: Merge (for long-running branches)
git fetch origin
git merge origin/develop
git push origin feature-branch
```

## Merge Strategies

### Squash Merge (Feature Branches)

```bash
# Squash multiple commits into one
git checkout develop
git pull origin develop
git merge --squash feature/user-auth
git commit -m "feat(auth): implement user authentication

- Added JWT token generation and validation
- Implemented login and logout endpoints
- Added protected route middleware
- Created authentication hooks for frontend"

git push origin develop
```

### Fast-Forward Merge (Release Branches)

```bash
# Maintain linear history for releases
git checkout main
git pull origin main
git merge --ff-only release/1.2.0
git push origin main

# Tag release
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

## Handling Conflicts

```bash
# View conflicted files
git status

# Open conflicted file and resolve manually
# Files show:
# <<<<<<< HEAD (current branch)
# your changes
# =======
# incoming changes
# >>>>>>> branch-name

# After resolving
git add conflicted-file.js
git rebase --continue  # if rebasing
# OR
git commit -m "Merge: resolve conflicts"  # if merging
```

## Stashing Changes

```bash
# Save work without committing
git stash

# List stashed changes
git stash list

# Apply stashed changes
git stash apply
git stash apply stash@{0}  # specific stash

# Apply and remove stash
git stash pop

# Delete stash
git stash drop
git stash clear  # delete all
```

## Undoing Changes

```bash
# Undo uncommitted changes (discard all)
git restore .
git checkout -- .

# Undo changes in specific file
git restore path/to/file.js

# Unstage changes
git restore --staged path/to/file.js
git reset HEAD path/to/file.js

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Undo published commit (create new commit)
git revert <commit-hash>

# Ammend last commit
git add .
git commit --amend
git push origin branch-name --force-with-lease
```

## Viewing History

```bash
# View commit log
git log
git log --oneline              # Compact format
git log --graph --decorate     # Visual branch graph
git log --author="name"        # Commits by author
git log --since="2 weeks ago"  # Recent commits
git log -p                      # Show changes

# View differences
git diff                        # Working directory changes
git diff --staged              # Staged changes
git diff HEAD~1                # Changes from last commit
git diff branch1 branch2       # Compare branches

# View specific commit
git show <commit-hash>
git show <commit-hash>:file.js # File at specific commit
```

## Branching Best Practices

### Branch Naming Conventions

```
feature/<description>      # feature/user-dashboard
bugfix/<description>       # bugfix/auth-token-expiry
hotfix/<description>       # hotfix/critical-security-patch
release/<version>          # release/1.2.0
docs/<description>         # docs/api-documentation
refactor/<description>     # refactor/database-queries
test/<description>         # test/add-e2e-tests
```

### Branch Lifecycle

```bash
# Protect important branches (via GitHub settings)
- Require pull request reviews
- Require status checks to pass
- Require branches to be up to date
- Require code owner reviews
- Restrict who can push to matching branches
- Require deployments to be successful

# Automatic branch deletion
- Delete head branch on merge (enabled)

# Branch protection for main
- Require 2 approvals
- Require all checks to pass
- Allow admins to bypass restrictions
```

## Collaboration Patterns

### Code Review Checklist

```markdown
## Code Quality
- [ ] Code follows project style guide
- [ ] Variable/function names are clear
- [ ] Complex logic is commented
- [ ] No commented-out code
- [ ] No debug statements left

## Functionality
- [ ] Implementation matches requirements
- [ ] Edge cases handled
- [ ] Error handling appropriate
- [ ] No breaking changes (or documented)

## Testing
- [ ] Unit tests added
- [ ] Integration tests added
- [ ] Manual testing completed
- [ ] All tests passing

## Security
- [ ] No secrets in code
- [ ] Input validation present
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] CSRF protection

## Performance
- [ ] No N+1 queries
- [ ] No memory leaks
- [ ] Appropriate caching
- [ ] Reasonable time complexity

## Documentation
- [ ] Code comments added
- [ ] README updated if needed
- [ ] API documentation updated
- [ ] Changelog updated
```

### Pair Programming with Git

```bash
# Driver sets up remote
git remote add pair-partner https://github.com/partner/repo.git

# Partner pulls changes
git fetch pair-partner
git merge pair-partner/feature-branch

# After driver pushes:
git pull origin feature-branch

# Swap roles and continue
```

## GitHub-Specific Features

### Issues and Linking

```markdown
# Link commit to issue
git commit -m "fix: resolve user login issue #1234"

# Link PR to issue
- In PR description: "Fixes #1234" or "Closes #1234"
- Automatically closes issue when PR is merged

# Reference in commits
- Fixes #1234
- Closes #1234
- Resolves #1234
- References #1234
```

### Labels and Automation

```yaml
# .github/labels.yml
- name: bug
  color: "d73a49"
  description: Something isn't working

- name: enhancement
  color: "a2eeef"
  description: New feature or request

- name: documentation
  color: "0075ca"
  description: Improvements or additions to documentation

- name: critical
  color: "ff0000"
  description: Critical priority

- name: ready-for-review
  color: "fbca04"
  description: Ready for code review

- name: needs-revision
  color: "ffc274"
  description: Changes requested
```

### Workflows for PR Management

```yaml
# .github/workflows/pr-automation.yml
name: PR Automation

on:
  pull_request:
    types: [opened, labeled]

jobs:
  auto-assign:
    runs-on: ubuntu-latest
    if: github.event.action == 'opened'
    steps:
      - uses: actions/checkout@v3
      
      - name: Assign PR to author
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.addAssignees({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              assignees: [context.payload.pull_request.user.login]
            })
      
      - name: Add label
        run: |
          gh pr edit ${{ github.event.pull_request.number }} \
            --add-label "ready-for-review"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  request-review:
    runs-on: ubuntu-latest
    if: |
      github.event.action == 'labeled' && 
      github.event.label.name == 'ready-for-review'
    steps:
      - name: Request reviews from CODEOWNERS
        uses: actions/github-script@v6
        with:
          script: |
            // Logic to request reviews from code owners
```

## Semantic Versioning

### Version Format: MAJOR.MINOR.PATCH

```
1.2.3

MAJOR: Breaking changes
MINOR: New features (backwards compatible)
PATCH: Bug fixes

Examples:
- 0.1.0 - Initial release
- 1.0.0 - First stable release
- 1.2.0 - New features added
- 1.2.1 - Bug fix
- 2.0.0 - Major breaking changes
```

### Tagging Releases

```bash
# Create annotated tag
git tag -a v1.2.0 -m "Release version 1.2.0"

# Push tags
git push origin v1.2.0
git push origin --tags  # Push all tags

# View tags
git tag
git tag -l "v1.*"
git show v1.2.0

# Delete tag
git tag -d v1.2.0
git push origin --delete v1.2.0
```

## Advanced Git Techniques

### Cherry-picking Commits

```bash
# Copy specific commit to current branch
git cherry-pick <commit-hash>

# Cherry-pick multiple commits
git cherry-pick <hash1> <hash2> <hash3>

# Cherry-pick range
git cherry-pick <hash1>..<hash2>

# If conflicts occur
git cherry-pick --continue
git cherry-pick --abort
```

### Interactive Rebase

```bash
# Rewrite last 3 commits
git rebase -i HEAD~3

# Commands in interactive mode:
# pick - use commit
# reword - use commit but edit message
# squash - use commit but meld into previous
# fixup - like squash but discard log message
# drop - remove commit

# Reorder commits in editor, then save
```

### Bisect for Bug Finding

```bash
# Find commit that introduced bug
git bisect start
git bisect bad HEAD        # Current version has bug
git bisect good v1.0.0     # Old version works

# Git checks out middle commit
# Test if bug exists
git bisect good  # or git bisect bad

# Repeat until Git finds exact commit
git bisect reset  # Return to original branch
```

## Sources and References

### Official Documentation
- [Git Official Documentation](https://git-scm.com/doc) - Complete Git reference
- [GitHub Docs](https://docs.github.com) - GitHub-specific features
- [GitLab Docs](https://docs.gitlab.com) - GitLab-specific features

### Best Practices
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message standard
- [Git Flow Cheatsheet](https://danielkummer.github.io/git-flow-cheatsheet/) - Git Flow guide
- [GitHub Flow](https://guides.github.com/introduction/flow/) - GitHub Flow guide
- [Semantic Versioning](https://semver.org/) - Versioning standard

### Tools
- [GitHub Desktop](https://desktop.github.com/) - GUI for Git
- [GitKraken](https://www.gitkraken.com/) - Advanced Git client
- [Sourcetree](https://www.sourcetreeapp.com/) - Atlassian Git client
- [Commitizen](http://commitizen.github.io/cz-cli/) - Commit message helper

### Books & Articles
- [Pro Git](https://git-scm.com/book/en/v2) - Free Git book
- [Atlassian Git Tutorials](https://www.atlassian.com/git/tutorials) - Comprehensive guides
- [Oh Shit, Git!?!](https://ohshitgit.com/) - Git troubleshooting

---

**Related:** [CI/CD Integration](../03-devops-infrastructure/github-actions-guide.md)