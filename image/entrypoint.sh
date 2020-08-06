#!/bin/bash

INTERNAL_DIR=/internal
WORK_DIR=${INTERNAL_DIR}/build
PROFILE_DIR=${INTERNAL_DIR}/archlive

ARCHLIVE_DIR=/archlive
OUT_DIR=/out
ARCHISO_PROFILE=releng

USAGE="Usage: ${0} [flags]

flags:
-a, --archlivedir dir   The profile override directory. Default ${ARCHLIVE_DIR}.
-o, --outdir dir        The archiso output directory. Default ${OUT_DIR}.
-p, --profile prof      The archiso base profile. Default ${ARCHISO_PROFILE}."

usage() {
    echo "${USAGE}"
    exit 1
}


while [ ! -z ${1} ]; do
    case ${1} in
        -a|--archlivedir)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            ARCHLIVE_DIR=${1}
            shift
            ;;
        -o|--outdir)
            shift
            if [ -z ${1} ]; then
                usage
            fi
            OUT_DIR=${1}
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

# Always start with a fresh profile directory
rm -rf ${PROFILE_DIR}
cp -r /usr/share/archiso/configs/${ARCHISO_PROFILE} ${PROFILE_DIR}

# Override files
ARCHLIVE_DIR=${ARCHLIVE_DIR%/}/ # Ensure trailing '/' for rsync
PROFILE_DIR=${PROFILE_DIR%/}/
rsync -a -r ${ARCHLIVE_DIR} ${PROFILE_DIR}

# Build ISO
mkarchiso \
    -w ${WORK_DIR} \
    -o ${OUT_DIR} \
    -v \
    ${PROFILE_DIR}
