FROM archlinux

RUN pacman -Syu --noconfirm archiso rsync \
    && yes | pacman -Scc

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
