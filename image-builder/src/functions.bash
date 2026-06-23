# shellcheck shell=bash

__DIR__="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

select_fastest_mirror() {
    local mirrors mirror
    read -r -d '' mirrors < "${__DIR__}/mirrors.txt" || :

    # Try netselect first to get fastest mirror
    # shellcheck disable=SC2086
    mirror=$(netselect -s 1 -t 10 $mirrors 2> /dev/null | awk '{print $2}')
    
    # Verify mirror is accessible via HTTP using wget
    if [ -n "$mirror" ] && wget -q --spider --timeout=5 "$mirror" 2> /dev/null; then
        echo "$mirror"
        return
    fi
    
    # Fallback: try mirrors from list until we find one that works
    while IFS= read -r mirror || [ -n "$mirror" ]; do
        if wget -q --spider --timeout=5 "$mirror" 2> /dev/null; then
            echo "$mirror"
            return
        fi
    done < "${__DIR__}/mirrors.txt"
    
    # Final fallback
    echo "https://pkg.opnsense.org/"
}

# usage: get_product_series <version>
get_product_series() {
    echo "$1" | cut -d. -f1-2
}

# usage: process_argument <spec> <args...>
# Perl's Getopt::Std-like argument processing
getopts_std() {
    local spec
    spec="${1}"
    shift
    OPTIND=1  # Reset OPTIND to start from first argument
    while getopts "${spec}" opt; do
        case "${opt}" in
            ?)
                if [ "${OPTARG}" ]; then
                    eval "opt_${opt}=\"${OPTARG}\""
                else
                    eval "opt_${opt}=true"
                fi
        esac
    done
}

# usage: raw_image_name <version> [-t type] [-a arch]
build_release_image_name() {
    local series opt_t opt_a
    series="$(get_product_series "$1")"
    shift
    getopts_std "t:a:" "$@"
    : "${opt_t:="nano"}"
    : "${opt_a:="amd64"}"
    echo "OPNsense-${series}-${opt_t}-${opt_a}.img"
}

# usage: raw_image_url <version> [-m mirror] [-t type] [-a arch]
build_release_image_url() {
    local version opt_m opt_t opt_a
    version="$1"
    shift
    getopts_std "m:t:a:" "$@"
    : "${opt_t:="nano"}"
    : "${opt_a:="amd64"}"
    
    # aarch64 images are available on GitHub releases
    if [ "${opt_a}" = "aarch64" ]; then
        echo "https://github.com/maurice-w/opnsense-vm-images/releases/download/${version}/OPNsense-${version}-ufs-serial-vm-aarch64.qcow2.bz2"
        return
    fi
    
    : "${opt_m:="$(select_fastest_mirror)"}"
    echo "${opt_m}/releases/$(get_product_series "$version")/$(build_release_image_name "${version}" -t "${opt_t}" -a "${opt_a}").bz2"
}

build_release_checksum_url() {
    local series opt_m opt_a
    series="$(get_product_series "$1")"
    shift
    getopts_std "m:a:" "$@"
    : "${opt_a:="amd64"}"
    
    # aarch64 images don't have standard checksums on mirrors
    if [ "${opt_a}" = "aarch64" ]; then
        echo ""
        return
    fi
    
    : "${opt_m:="$(select_fastest_mirror)"}"
    echo "${opt_m}/releases/${series}/OPNsense-${series}-checksums-${opt_a}.sha256"
}
