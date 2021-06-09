#!/bin/bash

set -o pipefail

# Return the first IPv4 address of the first ethernet interface
get_ip() {
	local iface
    local ip

    iface=$(basename $(ls -d /sys/class/net/en*)) &&
        ip=$(ip address show dev ${iface} |
            awk '$1 == "inet" { split($2, a, "/"); print a[1] }') || return 1

    echo ${ip}
}


HTTP_ADDR=$(get_ip) || echo "Failed to get own IP. Please set it with --http."

USAGE="Usage: ${0} [flags]

flags:
--dhcp addr     The address of the DHCP server to proxy. Required.
--http addr     The address of the HTTP server. Default ${HTTP_ADDR}."

usage() {
    echo "${USAGE}"
    exit 1
}


while [ ! -z ${1} ]; do
    case ${1} in
        --dhcp)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            DHCP_ADDR=${1}
            shift
            ;;
        --http)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            HTTP_ADDR=${1}
            shift
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z ${DHCP_ADDR} ] || [ -z ${HTTP_ADDR} ]; then
    usage
fi


cat > /etc/dnsmasq.conf <<EOF
# Don't function as dns server
port=0

# Function as a proxy DHCP
dhcp-range=${DHCP_ADDR},proxy
dhcp-no-override

# tftp server setup
enable-tftp
tftp-root=/srv/tftp

# Log extra information about dhcp transactions (for debug purposes)
log-dhcp

# NOTE: For some reason, dhcp-boot doesn't seem to work.
pxe-service=x86PC,"PXELINUX (BIOS)",/lpxelinux
pxe-service=X86-64_EFI,"PXELINUX (EFI)",/syslinux.efi
EOF

cat > /srv/tftp/pxelinux.cfg/default <<EOF
DEFAULT archlinux

LABEL archlinux
    MENU LABEL Arch Linux x86_64 PXE
    LINUX /vmlinuz-linux
    INITRD /intel-ucode.img,/amd-ucode.img,/initramfs-linux.img
    APPEND archiso_http_srv=http://${HTTP_ADDR}/
    SYSAPPEND 3
EOF

# NOTE: dnsmasq launches in the background by default
dnsmasq

darkhttpd /archiso
