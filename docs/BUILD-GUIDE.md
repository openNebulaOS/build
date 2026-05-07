# openNebula Linux Build Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Build System Overview](#build-system-overview)
4. [Building the ISO](#building-the-iso)
5. [Building Packages](#building-packages)
6. [Customizing the Build](#customizing-the-build)
7. [Version Management](#version-management)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **OS**: Linux (recommended: Arch, Debian, or Ubuntu)
- **Architecture**: x86_64 (64-bit)
- **RAM**: Minimum 4GB, recommended 8GB+
- **Disk Space**: Minimum 20GB for build environment
- **Internet**: Required for downloading sources

### Required Tools

```bash
# Debian/Ubuntu
sudo apt install build-essential git curl wget tar xz-utils gzip \
  grub-pc binutils gcc make libelf-dev libssl-dev python3

# Arch Linux
sudo pacman -S base-devel git curl wget tar xz gzip \
  grub binutils gcc make libelf openssl python3

# Fedora
sudo dnf install @development-tools git curl wget tar xz gzip \
  grub2 binutils gcc make elfutils-libelf-devel openssl python3
```

### Recommended Tools

```bash
# Additional build dependencies
sudo apt install meson ninja-build cmake pkg-config libzstd-dev
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/openNebula.git
cd openNebula
```

### 2. Run Full Build

```bash
chmod +x build/build.sh scripts/version.sh repos/repo-update
./build/build.sh all
```

### 3. Find Your ISO

```bash
ls -la build/iso/
```

## Build System Overview

### Directory Structure

```
openNebula/
├── build/                  # Build scripts
│   └── build.sh           # Main build script
├── packages/              # Package definitions (*.def)
├── star/                  # Package manager
│   └── star              # Package manager binary
├── star-build/            # Package build system
│   └── star-build        # Package builder
├── installer/             # CLI Installer
│   └── nebula-install    # Installer script
├── overlay/               # Root filesystem overlay
│   └── etc/              # System configuration
├── repos/                # Repository tools
│   └── repo-update       # Repository indexer
├── scripts/              # Utility scripts
│   ├── version.sh        # Version manager
│   └── version.conf      # Version configuration
└── branding/              # Branding assets
    └── neofetch/         # Custom neofetch
```

### Build Script Commands

```bash
./build/build.sh all        # Build everything (kernel, rootfs, ISO)
./build/build.sh kernel    # Build only the Linux kernel
./build/build.sh rootfs    # Create root filesystem only
./build/build.sh iso       # Create ISO image only
./build/build.sh packages  # Build packages only
./build/build.sh clean     # Clean build artifacts
```

## Building the ISO

### Step 1: Initialize Build Environment

```bash
./build/build.sh init
```

### Step 2: Build Kernel

The build system automatically fetches the latest stable kernel:

```bash
./build/build.sh kernel -k 6.8.0
```

Or let it auto-detect:

```bash
./build/build.sh kernel
```

### Step 3: Create Root Filesystem

```bash
./build/build.sh rootfs
```

This creates a base system with:
- Core utilities (bash, coreutils, etc.)
- openNebula branding
- OpenRC init system
- Basic services

### Step 4: Build Packages (Optional)

```bash
for pkg in packages/*.def; do
    star-build build "$pkg" -o build/packages
done
```

### Step 5: Generate Repository Index

```bash
./repos/repo-update
```

### Step 6: Create ISO

```bash
./build/build.sh iso -v 1.0.0
```

Output: `build/iso/openNebula-1.0.0-6.8.0-x86_64.iso`

## Building Packages

### Package Definition Format

```bash
PKG_NAME="package-name"
PKG_VERSION="1.0.0"
PKG_RELEASE="1"
PKG_SOURCE="https://example.com/source.tar.gz"
PKG_DEPS="dependency1 dependency2"
PKG_BUILD_DEPS="build-dependency1"
PKG_DESCRIPTION="Package description"
PKG_LICENSE="GPL-3.0"
PKG_ARCH="x86_64"

build() {
    ./configure --prefix=/usr
    make
    make install DESTDIR="$PKG_DESTDIR"
}

star_install() {
    install -Dm755 program "$PKG_DESTDIR/usr/bin/program"
}
```

### Using star-build

```bash
# Build single package
star-build build packages/bash.def

# Build with custom output
star-build build packages/bash.def -o ./repos/packages

# Build from git
star-build git https://github.com/example/repo.git

# Clean build cache
star-build clean

# List cached packages
star-build list
```

## Customizing the Build

### Custom Kernel Version

```bash
./build/build.sh all -k 6.7.0
```

### Custom Version String

```bash
./build/build.sh iso -v 2.0.0-beta1
```

### Custom Build Directory

```bash
BUILD_DIR=/path/to/build ./build/build.sh all
```

### Modifying the Overlay

Edit files in `overlay/` to customize:
- `/etc/os-release` - OS identification
- `/etc/bash/bashrc` - Bash configuration
- `/etc/profile` - System profile
- `/etc/init.d/*` - OpenRC services

### Adding Packages

1. Create package definition in `packages/`:

```bash
# packages/myapp.def
PKG_NAME="myapp"
PKG_VERSION="1.0.0"
PKG_SOURCE="https://example.com/myapp-1.0.0.tar.gz"
PKG_DEPS=""
PKG_DESCRIPTION="My application"

build() {
    ./configure --prefix=/usr
    make
    make install DESTDIR="$PKG_DESTDIR"
}
```

2. Add to build queue and rebuild.

## Version Management

### Using version.sh

```bash
# Show current version
./scripts/version.sh show

# Output:
# Current openNebula Version Information
# ======================================
# Version:    1.0.0
# Codename:   Stellar
# Full:       1.0.0 (Stellar)
```

### Bump Version

```bash
# Bump patch (1.0.0 -> 1.0.1)
./scripts/version.sh bump patch

# Bump minor (1.0.0 -> 1.1.0)
./scripts/version.sh bump minor

# Bump major (1.0.0 -> 2.0.0)
./scripts/version.sh bump major
```

### Set Specific Version

```bash
./scripts/version.sh set 2.0.0
```

### Change Codename

```bash
./scripts/version.sh codename "Nebula"
```

### Update All References

```bash
./scripts/version.sh all
```

This updates:
- `/overlay/etc/os-release`
- `/build/build.sh`
- `/star/star`
- `/star-build/star-build`
- `/installer/nebula-install`
- `/branding/neofetch/neofetch`
- All package definitions

## Troubleshooting

### Build Fails with "Permission Denied"

```bash
chmod +x build/build.sh scripts/*.sh repos/repo-update
chmod +x star/star star-build/star-build installer/nebula-install
chmod +x overlay/etc/init.d/*
```

### Kernel Download Fails

Manually download and place in cache:

```bash
mkdir -p /var/tmp/openNebula-build/cache
wget -O /var/tmp/openNebula-build/cache/linux-6.8.0.tar.xz \
  https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.0.tar.xz
```

### Package Build Errors

Check dependencies:

```bash
# View package dependencies
cat packages/bash.def | grep PKG_DEPS

# Install missing dependencies
sudo star get <dependency>
```

### ISO Boot Problems

- Verify ISO was created: `ls -lh build/iso/*.iso`
- Check checksum: `sha256sum build/iso/*.iso`
- Try burning to USB with: `dd if=*.iso of=/dev/sdX bs=4M status=progress`

### Clean Build

```bash
rm -rf /var/tmp/openNebula-build
./build/build.sh clean
./build/build.sh all
```

## CI/CD Integration

See [GITHUB-SETUP.md](GITHUB-SETUP.md) for GitHub Actions configuration.

## Support

- Issues: https://github.com/opennebula/linux/issues
- Forum: https://forum.opennebula.io
- Docs: https://docs.opennebula.io
