#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/version.conf"

show_help() {
    cat << 'EOF'
openNebula Version Manager

Usage: version.sh <command> [options]

Commands:
    show                    Show current version information
    set <version>           Set new version (e.g., 1.0.0)
    bump [major|minor|patch] Bump version number
    codename <name>        Set codename (e.g., Stellar)
    all                     Update all version references
    help                    Show this help message

Examples:
    ./version.sh show
    ./version.sh set 1.1.0
    ./version.sh bump minor
    ./version.sh codename "Nebula"
    ./version.sh all

The version manager updates:
    - /overlay/etc/os-release
    - /build/build.sh
    - /star/star
    - /installer/nebula-install
    - /branding/neofetch/neofetch
    - All package definitions

EOF
}

load_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        source "$VERSION_FILE"
    else
        MAJOR="1"
        MINOR="0"
        PATCH="0"
        CODENAME="Stellar"
    fi
}

save_version() {
    cat > "$VERSION_FILE" << EOF
MAJOR="$MAJOR"
MINOR="$MINOR"
PATCH="$PATCH"
CODENAME="$CODENAME"
VERSION="${MAJOR}.${MINOR}.${PATCH}"
EOF
}

get_full_version() {
    echo "${MAJOR}.${MINOR}.${PATCH}"
}

get_version_string() {
    echo "$(get_full_version) (${CODENAME})"
}

show_version() {
    load_version
    echo "Current openNebula Version Information"
    echo "======================================="
    echo "Version:    $(get_full_version)"
    echo "Codename:   $CODENAME"
    echo "Full:       $(get_version_string)"
    echo ""
    echo "Version file: $VERSION_FILE"
}

update_os_release() {
    local ver=$(get_full_version)
    local code=$CODENAME

    cat > "${SCRIPT_DIR}/overlay/etc/os-release" << EOF
NAME="openNebula"
VERSION="${ver} (${code})"
ID=opennebula
ID_LIKE="opennebula linux"
PRETTY_NAME="openNebula Linux"
VERSION_ID="${ver}"
VERSION_CODE="${MAJOR}${MINOR}${PATCH}"
HOME_URL="https://opennebula.io"
DOCUMENTATION_URL="https://docs.opennebula.io"
SUPPORT_URL="https://forum.opennebula.io"
BUG_REPORT_URL="https://github.com/opennebula/linux/issues"
PRIVACY_POLICY_URL="https://opennebula.io/privacy"
BUILD_ID="rolling"
ANSI_COLOR="38;2;59;130;246"
LOGO=opennebula
CPE_NAME="cpe:/o:opennebula:linux:${MAJOR}.${MINOR}.${PATCH}"
EOF
    echo "Updated overlay/etc/os-release"
}

update_build_sh() {
    local ver=$(get_full_version)
    sed -i "s/^VERSION=\"[^\"]*\"/VERSION=\"${ver}\"/" "${SCRIPT_DIR}/build/build.sh"
    echo "Updated build/build.sh"
}

update_star() {
    local ver=$(get_full_version)
    sed -i "s/^VERSION=\"[^\"]*\"/VERSION=\"${ver}\"/" "${SCRIPT_DIR}/star/star"
    echo "Updated star/star"
}

update_star_build() {
    local ver=$(get_full_version)
    sed -i "s/^VERSION=\"[^\"]*\"/VERSION=\"${ver}\"/" "${SCRIPT_DIR}/star-build/star-build"
    echo "Updated star-build/star-build"
}

update_nebula_install() {
    local ver=$(get_full_version)
    sed -i "s/^VERSION=\"[^\"]*\"/VERSION=\"${ver}\"/" "${SCRIPT_DIR}/installer/nebula-install"
    echo "Updated installer/nebula-install"
}

update_neofetch() {
    local ver=$(get_full_version)
    cat > "${SCRIPT_DIR}/branding/neofetch/neofetch" << EOF
#!/bin/bash

cat << NEOEOF

                              _______        ___.         .__          
  ____ ______   ____   ____   \      \   ____\_ |__  __ __|  | _____   
 /  _ \\____ \_/ __ \ /    \  /   |   \_/ __ \| __ \|  |  \  | \__  \  
(  <_> )  |_> >  ___/|   |  \/    |    \  ___/| \_\ \  |  /  |__/ __ \_
 \____/|   __/ \___  >___|  /\____|__  /\___  >___  /____/|____(____  /
       |__|        \/     \/         \/     \/    \/                \/ 

           openNebula Linux - ${CODENAME} Edition (${ver})

NEOEOF

echo "  Linux Kernel: \$(uname -r 2>/dev/null || echo 'Unknown')"
echo "  Uptime: \$(uptime -p 2>/dev/null || echo 'Unknown')"
echo "  Shell: \${SHELL##*/}"
echo "  Resolution: \${RESOLUTION:-Unknown}"
echo "  DE: \${DESKTOP_SESSION:-Unknown}"
echo "  WM: \${XDG_CURRENT_DESKTOP:-Unknown}"
echo "  Theme: \${THEME:-Unknown}"
echo "  Icons: \${ICONS:-Unknown}"
echo "  Terminal: \${TERM:-Unknown}"
echo "  CPU: \$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//' || echo 'Unknown')"
echo "  Memory: \$(free -h 2>/dev/null | awk '/^Mem:/ {print \$3 \"/\" \$2}' || echo 'Unknown')"
echo ""
EOF
    chmod +x "${SCRIPT_DIR}/branding/neofetch/neofetch"
    echo "Updated branding/neofetch/neofetch"
}

update_package_defs() {
    local ver=$(get_full_version)
    for def in "${SCRIPT_DIR}"/packages/*.def; do
        if [[ -f "$def" ]]; then
            if grep -q "PKG_VERSION=" "$def"; then
                sed -i "s/^PKG_VERSION=\"[^\"]*\"/PKG_VERSION=\"${ver}\"/" "$def"
            fi
        fi
    done
    echo "Updated package definitions"
}

update_all() {
    load_version
    echo "Updating all version references to $(get_version_string)..."
    echo ""

    update_os_release
    update_build_sh
    update_star
    update_star_build
    update_nebula_install
    update_neofetch
    update_package_defs

    echo ""
    echo "All version references updated successfully!"
}

set_version() {
    local new_ver="$1"

    if [[ ! "$new_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must be in format X.Y.Z"
        exit 1
    fi

    MAJOR=$(echo "$new_ver" | cut -d. -f1)
    MINOR=$(echo "$new_ver" | cut -d. -f2)
    PATCH=$(echo "$new_ver" | cut -d. -f3)

    save_version
    echo "Version set to $(get_version_string)"
    update_all
}

bump_version() {
    load_version
    local bump_type="${1:-patch}"

    case "$bump_type" in
        major)
            ((MAJOR++))
            MINOR=0
            PATCH=0
            ;;
        minor)
            ((MINOR++))
            PATCH=0
            ;;
        patch)
            ((PATCH++))
            ;;
        *)
            echo "Error: Invalid bump type. Use major, minor, or patch"
            exit 1
            ;;
    esac

    save_version
    echo "Version bumped to $(get_version_string)"
    update_all
}

set_codename() {
    local new_codename="$1"

    if [[ -z "$new_codename" ]]; then
        echo "Error: Codename cannot be empty"
        exit 1
    fi

    CODENAME="$new_codename"
    save_version
    echo "Codename set to: $CODENAME"
    update_all
}

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        show)
            show_version
            ;;
        set)
            if [[ $# -eq 0 ]]; then
                echo "Error: Version required"
                exit 1
            fi
            set_version "$1"
            ;;
        bump)
            bump_version "$1"
            ;;
        codename)
            if [[ $# -eq 0 ]]; then
                echo "Error: Codename required"
                exit 1
            fi
            set_codename "$1"
            ;;
        all)
            update_all
            ;;
        -h|--help|help)
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
