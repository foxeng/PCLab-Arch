FROM archlinux

# Reference:
# - https://wiki.archlinux.org/title/Syslinux#PXELINUX
# - https://wiki.syslinux.org/wiki/index.php?title=PXELINUX
# - https://wiki.syslinux.org/wiki/index.php?title=PXELINUX-Multi-Arch
# - https://www.saminiir.com/boot-arch-linux-from-pxe/

RUN pacman -Syu --noconfirm dnsmasq darkhttpd syslinux \
    && yes | pacman -Scc \
    && mkdir -p /srv/tftp \
    && ln -s /usr/lib/syslinux/bios/lpxelinux.0 /srv/tftp/lpxelinux.0 \
    && ln -s /usr/lib/syslinux/bios/ldlinux.c32 /srv/tftp/ldlinux.c32 \
    && ln -s /usr/lib/syslinux/efi64/syslinux.efi /srv/tftp/syslinux.efi \
    && ln -s /usr/lib/syslinux/efi64/ldlinux.e64 /srv/tftp/ldlinux.e64 \
    && mkdir -p /srv/tftp/pxelinux.cfg \
    && ln -s /archiso/arch/boot/x86_64/vmlinuz-linux /srv/tftp/vmlinuz-linux \
    && ln -s /archiso/arch/boot/intel-ucode.img /srv/tftp/intel-ucode.img \
    && ln -s /archiso/arch/boot/amd-ucode.img /srv/tftp/amd-ucode.img \
    && ln -s /archiso/arch/boot/x86_64/initramfs-linux.img /srv/tftp/initramfs-linux.img

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
