# Docker container for PXE booting Arch ISO images

This provides a simple docker container to allow serving an archlinux ISO image
for booting from the network via PXE. Supports both BIOS and UEFI.

## Build container image

First of all one needs to build the container image:

```sh
docker build -t arch-pxe .
```

## Serve ISO with PXE

Having built the container image, we may now use it to serve the contents of an
Arch ISO using PXE. Assuming we want to serve the ISO located at
`./archlinux-x86_64.iso` and a DHCP server is already running at `192.168.1.1`:

1. Mount the ISO on the host:

   ```sh
   mkdir archiso
   mount -o loop,ro ./archlinux-x86_64.iso ./archiso
   ```

1. Run the PXE server:

   ```sh
   docker run -it --rm --privileged --net host -v $(pwd)/archiso:/archiso:ro arch-pxe --dhcp 192.168.1.1
   ```

   See `entrypoint.sh` for usage information.
