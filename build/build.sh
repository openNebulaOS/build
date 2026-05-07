#!/bin/bash
set -e

VERSION="1.0.0"
BUILD_DIR="${BUILD_DIR:-/var/tmp/openNebula-build}"
KERNEL_VERSION="${KERNEL_VERSION:-}"
SOURCE_CACHE="${BUILD_DIR}/cache"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
ISO_DIR="${BUILD_DIR}/iso"
PACKAGES_DIR="${BUILD_DIR}/packages"
LOG_FILE="${BUILD_DIR}/build.log"

command -v basename >/dev/null 2>&1 || { echo "basename not found" >&2; exit 1; }
command -v dirname >/dev/null 2>&1 || { echo "dirname not found" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "tar not found" >&2; exit 1; }

mkdir -p "${BUILD_DIR}"
touch "$LOG_FILE" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

info() {
    echo -e "\033[1;34m[INFO]\033[0m $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "\033[1;34m[INFO]\033[0m $*"
}
warn() {
    echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "\033[1;33m[WARN]\033[0m $*"
}
error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "\033[0;31m[ERROR]\033[0m $*"
}

init_build() {
    log "Initializing openNebula build environment"

    mkdir -p "$SOURCE_CACHE" "$ROOTFS_DIR" "$ISO_DIR" "$PACKAGES_DIR"
    mkdir -p "${BUILD_DIR}/work"
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    if [[ -z "$KERNEL_VERSION" ]]; then
        KERNEL_VERSION="6.8.0"
        info "No kernel version specified, using default: $KERNEL_VERSION"
    fi

    local kernel_major="${KERNEL_VERSION%%.*}"
    KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${kernel_major}.x/linux-${KERNEL_VERSION}.tar.xz"

    if [[ ! -f "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz" ]]; then
        info "Downloading Linux kernel ${KERNEL_VERSION} from $KERNEL_URL"
        if command -v curl >/dev/null 2>&1; then
            curl -L --fail -o "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz" "$KERNEL_URL" || {
                error "Failed to download kernel"
                rm -f "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz"
                return 1
            }
        elif command -v wget >/dev/null 2>&1; then
            wget -O "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz" "$KERNEL_URL" || {
                error "Failed to download kernel"
                rm -f "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz"
                return 1
            }
        else
            error "curl or wget required to download kernel"
            return 1
        fi
        local size=$(stat -c%s "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz" 2>/dev/null || stat -f%z "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz" 2>/dev/null)
        if [[ "$size" -lt 1000000 ]]; then
            error "Downloaded file too small ($size bytes), likely invalid"
            rm -f "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz"
            return 1
        fi
        info "Kernel downloaded successfully ($size bytes)"
    else
        info "Using cached kernel source"
    fi

    log "Build environment initialized"
}

extract_kernel() {
    info "Extracting Linux kernel source..."
    tar -xJf "${SOURCE_CACHE}/linux-${KERNEL_VERSION}.tar.xz" -C "${BUILD_DIR}/work"
    log "Kernel source extracted"
}

build_kernel() {
    info "Building Linux kernel ${KERNEL_VERSION}..."

    local kernel_src="${BUILD_DIR}/work/linux-${KERNEL_VERSION}"
    cd "$kernel_src"

    if command -v make >/dev/null 2>&1; then
        make defconfig || make allnoconfig
        make -j$(nproc 2>/dev/null || echo 4)
        make modules_install
        make install
    else
        warn "make not found, skipping kernel compilation"
    fi

    log "Kernel build complete"
}

create_rootfs() {
    info "Creating root filesystem..."

    local rootfs="$ROOTFS_DIR"
    mkdir -p "${rootfs}"/{bin,etc,home,lib,media,mnt,opt,proc,root,sbin,srv,sys,tmp,usr,var}
    mkdir -p "${rootfs}"/{boot,dev,run,run/lock,run/shm}
    mkdir -p "${rootfs}"/usr/{bin,lib,sbin,share,src,tmp}
    mkdir -p "${rootfs}"/var/{cache,lib,log,spool,tmp}
    mkdir -p "${rootfs}"/var/backups
    mkdir -p "${rootfs}"/etc/skel
    mkdir -p "${rootfs}"/root
    chmod 1777 "${rootfs}/tmp"
    chmod 1777 "${rootfs}/var/tmp"

    info "Base directories created"
}

install_base_packages() {
    info "Installing base packages to rootfs..."

    if [[ -d "/run/openNebula/overlay" ]]; then
        cp -r /run/openNebula/overlay/* "$ROOTFS_DIR/"
    fi

    if [[ -d "./overlay" ]]; then
        cp -r ./overlay/* "$ROOTFS_DIR/"
    fi

    log "Base packages installed"
}

configure_system() {
    info "Configuring system in rootfs..."

    cat > "${ROOTFS_DIR}/etc/os-release" << 'EOF'
NAME="openNebula"
VERSION="1.0.0 (Stellar)"
ID=opennebula
PRETTY_NAME="openNebula Linux"
VERSION_ID="1.0.0"
ANSI_COLOR="38;2;59;130;246"
EOF

    cat > "${ROOTFS_DIR}/etc/hostname" << 'EOF'
opennebula
EOF

    cat > "${ROOTFS_DIR}/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   opennebula
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

    cat > "${ROOTFS_DIR}/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
nobody:x:65534:65534:Nobody:/var/empty:/sbin/nologin
EOF

    cat > "${ROOTFS_DIR}/etc/group" << 'EOF'
root:x:0:
bin:x:1:daemon
daemon:x:2:
sys:x:3:
adm:x:4:
wheel:x:10:
users:x:100:
nobody:x:65534:
EOF

    cat > "${ROOTFS_DIR}/etc/shadow" << 'EOF'
root:*:0:0:99999:7:::
bin:*:0:0:99999:7:::
daemon:*:0:0:99999:7:::
nobody:*:0:0:99999:7:::
EOF

    cat > "${ROOTFS_DIR}/etc/fstab" << 'EOF'
LABEL=ROOT  /        ext4   defaults,noatime  0  1
LABEL=SWAP  none     swap   sw                0  0
tmpfs       /tmp     tmpfs  defaults,noatime  0  0
proc        /proc    proc   defaults          0  0
sysfs       /sys     sysfs  defaults          0  0
devpts      /dev/pts devpts defaults          0  0
EOF

    log "System configured"
}

install_bootloader() {
    info "Installing bootloader..."

    local rootfs="$ROOTFS_DIR"
    local boot_dir="${rootfs}/boot"

    if command -v grub-install >/dev/null 2>&1; then
        if [[ -d "/sys/firmware/efi" ]]; then
            mkdir -p "${boot_dir}/efi"
            grub-install --target=x86_64-efi --efi-directory="${boot_dir}/efi" --bootloader-id=openNebula || true
        else
            grub-install --target=i386-pc "${boot_dir}" || true
        fi
    fi

    cat > "${rootfs}/boot/grub/grub.cfg" << 'EOF'
set default=0
set timeout=5

menuentry 'openNebula Linux' {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    linux /boot/vmlinuz-linux root=LABEL=ROOT quiet splash
    initrd /boot/initramfs-linux.img
}
EOF

    log "Bootloader installed"
}

create_iso() {
    info "Creating ISO image..."

    local iso_name="openNebula-${VERSION}-${KERNEL_VERSION}-x86_64.iso"
    local iso_path="${ISO_DIR}/${iso_name}"

    mkdir -p "${BUILD_DIR}/iso_image/boot"
    mkdir -p "${BUILD_DIR}/iso_image/EFI"
    mkdir -p "${BUILD_DIR}/iso_image/grub"

    cp -r "${ROOTFS_DIR}"/* "${BUILD_DIR}/iso_image/" 2>/dev/null || true

    cat > "${BUILD_DIR}/iso_image/boot/grub/grub.cfg" << 'EOF'
set default=0
set timeout=5

menuentry 'openNebula Linux (Install)' {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    linux /boot/vmlinuz-linux root=/dev/sr0 quiet splash
    initrd /boot/initramfs-linux.img
}

menuentry 'openNebula Linux (Live)' {
    load_video
    set gfxpayload=keep
    insmod gzio
    insmod part_gpt
    insmod ext2
    linux /boot/vmlinuz-linux root=/dev/sr0 quiet splash toram
    initrd /boot/initramfs-linux.img
}
EOF

    if command -v grub-mkrescue >/dev/null 2>&1; then
        grub-mkrescue -o "$iso_path" "${BUILD_DIR}/iso_image" 2>/dev/null || \
        xorriso -as mkisofs -R -D -A "openNebula Linux" -V "openNebula" \
            -boot-load-size 4 -boot-info-table -eltorito-boot boot/grub/bios.img \
            -no-emul-boot -boot-load-size 0 -boot-info-table \
            -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
            -eltorito-catalog boot/grub/eltorito_catalog \
            -eltorito-boot boot/*/*.img -o "$iso_path" "${BUILD_DIR}/iso_image" 2>/dev/null || \
        genisoimage -R -D -A "openNebula Linux" -V "openNebula" \
            -boot-info-table -no-emul-boot -boot-load-size 4 \
            -boot-table-long -iso-level 3 \
            -o "$iso_path" "${BUILD_DIR}/iso_image" 2>/dev/null || \
        warn "No ISO creation tool available"
    fi

    if [[ -f "$iso_path" ]]; then
        info "ISO created: $iso_path"
        log "ISO image created successfully: $iso_path"
    else
        warn "ISO creation failed or skipped"
        cp -r "${BUILD_DIR}/iso_image" "${ISO_DIR}/openNebula-rootfs"
    fi
}

build_packages() {
    info "Building packages..."

    if [[ -d "./packages" ]]; then
        for pkg_def in ./packages/*.def; do
            if [[ -f "$pkg_def" ]]; then
                local pkg_name=$(basename "$pkg_def" .def)
                info "Building package: $pkg_name"
                if command -v star-build >/dev/null 2>&1; then
                    star-build build "$pkg_def" -o "$PACKAGES_DIR" 2>/dev/null || \
                    warn "Failed to build $pkg_name"
                fi
            fi
        done
    fi

    log "Package build complete"
}

generate_checksums() {
    info "Generating checksums..."

    if command -v sha256sum >/dev/null 2>&1; then
        find "$ISO_DIR" -type f -name "*.iso" -exec sha256sum {} \; > "${ISO_DIR}/SHA256SUMS"
    fi

    if command -v md5sum >/dev/null 2>&1; then
        find "$ISO_DIR" -type f -name "*.iso" -exec md5sum {} \; > "${ISO_DIR}/MD5SUMS"
    fi

    log "Checksums generated"
}

show_help() {
    cat << 'EOF'
openNebula Build System

Usage: build.sh <command> [options]

Commands:
    all         Build everything (kernel, rootfs, ISO)
    kernel      Build only the Linux kernel
    rootfs      Create root filesystem only
    iso         Create ISO image only
    packages    Build packages only
    clean       Clean build artifacts
    help        Show this help message

Options:
    -k, --kernel <version>  Specify kernel version
    -v, --version <version> Specify build version
    -d, --dir <directory>   Specify build directory

Examples:
    ./build.sh all
    ./build.sh kernel -k 6.8.0
    ./build.sh iso -v 1.0.0
EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -k|--kernel)
                KERNEL_VERSION="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -d|--dir)
                BUILD_DIR="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    case "$command" in
        all)
            init_build
            extract_kernel
            build_kernel
            create_rootfs
            install_base_packages
            configure_system
            install_bootloader
            build_packages
            create_iso
            generate_checksums
            info "Build complete!"
            ;;
        kernel)
            init_build
            extract_kernel
            build_kernel
            ;;
        rootfs)
            create_rootfs
            install_base_packages
            configure_system
            ;;
        iso)
            create_iso
            generate_checksums
            ;;
        packages)
            build_packages
            ;;
        clean)
            info "Cleaning build artifacts..."
            rm -rf "$BUILD_DIR"
            info "Clean complete"
            ;;
        help)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
