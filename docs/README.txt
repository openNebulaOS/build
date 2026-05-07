openNebula Linux Build System
==============================

Directory Structure:
  /packages/      - Package definition files (.def)
  /star/         - Package manager source
  /star-build/   - Package build system source
  /installer/    - CLI installer source
  /build/        - Build scripts and utilities
  /overlay/      - Root filesystem overlay
  /branding/     - Branding assets
  /scripts/      - Build and utility scripts
  /repos/        - Repository management tools

Quick Start:
  1. Build base system:
     ./build/build.sh all

  2. Create packages:
     star-build build packages/*.def

  3. Generate repository:
     ./repos/repo-update

  4. Create ISO:
     ./build/build.sh iso

Package Manager Commands:
  star get <pkg>    - Install package
  star remove <pkg> - Remove package
  star search <pkg> - Search packages
  star update       - Update databases
  star upgrade      - Upgrade packages

For more information, see the documentation.
