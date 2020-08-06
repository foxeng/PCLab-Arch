#!/bin/bash

AIROOTFS_DIR=/airootfs/ # NOTE: The trailing '/' is important for rsync
WORK_DIR=/build
TOP_DIR=/archlive
OUT_DIR=/out
ARCHISO_PROFILE=releng

USAGE="Usage: ${0} [flags]

flags:
-a, --airootfs dir      The airootfs override directory. Default \
${AIROOTFS_DIR}. NOTE: This will be used with rsync, so mind the trailing \
slashes.
-w, --workdir  dir       The archiso work directory. Default ${WORK_DIR}.
-t, --topdir   dir       The directory holding top-level archiso config files \
(e.g. packages.x86_64work directory. Default ${TOP_DIR}.
-o, --outdir   dir       The archiso output directory. Default ${OUT_DIR}.
-p, --profile  prof      The archiso profile. Default ${ARCHISO_PROFILE}."

usage() {
    echo "${USAGE}"
    exit 1
}

while [ ! -z ${1} ]; do
    case ${1} in
        -a|--airootfs)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            AIROOTFS_DIR="${1}/"   # Ensure trailing '/'
            shift
            ;;
        -w|--workdir)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            WORK_DIR=${1}
            shift
            ;;
        -t|--topdir)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            TOP_DIR=${1}
            shift
            ;;
        -o|--outdir)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            WORK_DIR=${1}
            shift
            ;;
        -p|--profile)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            ARCHISO_PROFILE=${1}
            shift
            ;;
        *)
            usage
            ;;
    esac
done

# Always start with a clean working directory
rm -rf ${WORK_DIR}
mkdir -p ${WORK_DIR}
cp -r /usr/share/archiso/configs/${ARCHISO_PROFILE}/* ${WORK_DIR}

# Override top-level files (e.g. packages.x86_64, pacman.conf etc.)
find ${TOP_DIR} -maxdepth 1 -type f -exec cp '{}' ${WORK_DIR}/airootfs ';'

# Override airootfs contents
rsync -a -r ${AIROOTFS_DIR} ${WORK_DIR}/airootfs/

# Build ISO
cd ${WORK_DIR}
./build.sh \
    -A 'Arch Linux Automated Installation CD' \
    -o ${OUT_DIR} \
    -v
