FROM archlinux

RUN pacman -Sy --noconfirm reflector \
    && reflector -l 200 -n 5 --sort rate --save /etc/pacman.d/mirrorlist \
    && pacman -Sy --noconfirm archiso rsync \
    && pacman -Scc --noconfirm \
    && mkdir -p /airootfs /archlive /out

# TODO: /usr/local/bin instead?
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# TODO: Document: docker build -t pclab .
# TODO: Document: docker run --privileged -v /dev:/dev -v airootfs:/airootfs -v archlive:/archlive -v out:/out pclab
