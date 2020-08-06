# Docker container for building ISO images

This provides a simple docker container to allow building even when not on an
archlinux host.

## Build container image

First of all one needs to build the container image:

```sh
docker build -t pclab .
```

## Build ISO image

Having built the container image, we may now use it to build the Arch ISO image.
Assuming we want to add the files under `./archlive` to the archiso
[profile](https://wiki.archlinux.org/index.php/Archiso#Prepare_a_custom_profile)
and output the ISO under `./out`:

```sh
docker run -it --rm --privileged -v $(pwd)/archlive:/archlive:ro -v $(pwd)/out:/out pclab
```

See `entrypoint.sh` for usage information.
