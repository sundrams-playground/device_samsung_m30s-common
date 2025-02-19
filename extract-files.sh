#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

export DEVICE=m30s
export VENDOR=samsung

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/lib64/hw/android.hardware.gnss@2.1-impl.so|vendor/lib64/hw/vendor.samsung.hardware.gnss@2.0-impl.so)
            "${PATCHELF}" --remove-needed libhidltransport.so "${2}"
            ;;
        vendor/bin/hw/rild)
            "${PATCHELF}" --replace-needed libril.so libril-samsung.so "${2}"
            ;;
        vendor/lib*/libsec-ril.so|vendor/lib64/libsec-ril-dsds.so)
            "${PATCHELF}" --replace-needed libril.so libril-samsung.so "${2}"
            xxd -p -c0 "${2}" | sed "s/600e40f9820c805224008052e10315aae30314aa/600e40f9820c805224008052e10315aa030080d2/g" | xxd -r -p > "${2}".patched
            mv "${2}".patched "${2}"
            ;;
        vendor/lib*/libexynosdisplay.so|vendor/lib*/hw/hwcomposer.exynos9611.so|vendor/lib*/sensors.*.so)
            "${PATCHELF}" --replace-needed libutils.so libutils-v32.so "${2}"
            ;;
        vendor/lib*/libsensorlistener.so)
            "${PATCHELF}" --add-needed libshim_sensorndkbridge.so "${2}"
            ;;
        vendor/lib*/libskeymaster4device.so)
            "${PATCHELF}" --replace-needed libcrypto.so libcrypto-tm.so "${2}"
            "${PATCHELF}" --add-needed libssl-tm.so "${2}"
            "${PATCHELF}" --add-needed libshim_crypto.so "${2}"
            ;;
        vendor/lib/libwvhidl.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite-3.9.1.so" "libprotobuf-cpp-full-3.9.1.so" "${2}"
            ;;
        vendor/lib*/sensors.*.so)
            "${PATCHELF}" --remove-needed libhidltransport.so "${2}"
            ;;
    esac
}

"${MY_DIR}/setup-makefiles.sh"
