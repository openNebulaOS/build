# Hosting openNebula on GitHub

## Overview

This guide explains how to host openNebula's package repository and ISO builds on GitHub.

## Repository Structure

```
openNebula/
├── .github/
│   └── workflows/
│       ├── build-iso.yml      # ISO build workflow
│       └── build-repo.yml     # Package repository workflow
├── packages/                   # Package definitions
├── repos/                      # Repository output (gh-pages branch)
│   └── packages/
│       └── *.star.xz          # Binary packages
├── scripts/
│   └── version.sh             # Version management
└── version.conf               # Current version config
```

## Setup Instructions

### 1. Create GitHub Repository

```bash
# Create new repository on GitHub, then:
git init
git add .
git commit -m "Initial openNebula Linux distribution"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/openNebula.git
git push -u origin main
```

### 2. Enable GitHub Actions

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Actions** → **General**
3. Set "Fork pull request workflows" to "From fork third-party"
4. Add a GitHub Personal Access Token with `packages:write` permission if needed

### 3. Enable GitHub Pages (for package repository)

1. Go to **Settings** → **Pages**
2. Source: Deploy from a branch
3. Branch: `gh-pages` / `(root)`
4. Save

Your packages will be available at: `https://YOUR_USERNAME.github.io/openNebula/packages/`

### 4. Configure Repository URL

Update `/etc/star/repos.conf` on installed systems:

```ini
[openNebula]
url=https://YOUR_USERNAME.github.io/openNebula/repos
enabled=1
priority=1
```

Or for the installer, edit `overlay/etc/star/repos.conf` before building.

### 5. Set Up Releases

For ISO releases:

1. Create a tag: `git tag -a v1.0.0 -m "Release version 1.0.0"`
2. Push tag: `git push origin v1.0.0`
3. Create release on GitHub UI or via:
   ```bash
   git push origin main
   # Create release via GitHub API or web UI
   ```

## CI/CD Workflows

### build-iso.yml

Triggered on:
- Push to main/master branches
- Release creation
- Manual workflow dispatch

Outputs:
- ISO artifact (30 days)
- SHA256/MD5 checksums

### build-repo.yml

Triggered on:
- Push to main with changes in `packages/` or `repos/`

Outputs:
- Package repository on `gh-pages` branch

## Automatic Updates

### Version Management

Use the version script to update all version references:

```bash
# Show current version
./scripts/version.sh show

# Bump version
./scripts/version.sh bump minor

# Set specific version
./scripts/version.sh set 2.0.0

# Update codename
./scripts/version.sh codename "Nebula"

# Update all references
./scripts/version.sh all
```

### Repository Updates

The `build-repo.yml` workflow automatically:
1. Builds all packages in `packages/*.def`
2. Creates compressed `.star.xz` packages
3. Generates repository index
4. Publishes to `gh-pages` branch

## Manual Build & Upload

### Build packages locally:

```bash
# Install star-build
chmod +x star-build/star-build
sudo cp star-build/star-build /usr/bin/star-build

# Create output directory
mkdir -p repos/packages

# Build packages
for pkg in packages/*.def; do
    star-build build "$pkg" -o repos/packages
done

# Update repository
./repos/repo-update
```

### Upload to GitHub:

```bash
# Switch to gh-pages branch
git checkout -b gh-pages

# Push to GitHub
git push origin gh-pages

# Return to main
git checkout main
```

## Troubleshooting

### Workflow Not Running

1. Check Actions tab for errors
2. Verify GitHub Actions is enabled in repository settings
3. Check that workflow file is in `.github/workflows/`

### Package Build Failures

1. Check dependencies are defined in package .def file
2. Verify source URLs are accessible
3. Check build logs in workflow artifacts

### Repository Not Accessible

1. Verify GitHub Pages is enabled
2. Check branch settings
3. Ensure URL in repos.conf matches your GitHub Pages URL

## Security Considerations

- Repository packages can be signed with GPG (configure `REPO_SIGN_KEY`)
- Workflows run in isolated containers
- Secrets are encrypted and not exposed in logs
