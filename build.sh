#!/bin/bash

set -euo pipefail

# Constants
readonly BASE_URL="http://os.archlinuxarm.org/os"
readonly FILE_NAME="ArchLinuxARM-aarch64-latest.tar.gz"
readonly MD5SUM_FILE="${FILE_NAME}.md5"

# Local variables
ctr=""
mnt=""
tar_cmd=""

cleanup() {
  if [[ -n "${mnt}" ]]; then
    buildah unmount "${ctr}" || true
  fi
  if [[ -n "${ctr}" ]]; then
    buildah rm "${ctr}" || true
  fi
}

trap cleanup EXIT

# Check if bsdtar exists and use it, otherwise fallback to tar
if command -v bsdtar &> /dev/null; then
  tar_cmd="bsdtar"
else
  tar_cmd="tar"
fi

# Download rootfs and checksum
echo "Downloading ArchLinuxARM root filesystem..."
curl --fail --location --output "${FILE_NAME}" "${BASE_URL}/${FILE_NAME}"
curl --fail --location --output "${MD5SUM_FILE}" "${BASE_URL}/${MD5SUM_FILE}"

# Verify checksum
echo "Verifying checksum..."
md5sum -c "${MD5SUM_FILE}"

# Create a new container from scratch and mount it
echo "Creating and mounting container..."
ctr=$(buildah from scratch)
mnt=$(buildah mount "${ctr}")

#TBD: consider using buildah add

# Validate mount point
if [[ -z "${mnt}" || "${mnt}" == "/" ]]; then
  echo "Error: Invalid mount point."
  exit 1
fi

# Extract root filesystem
echo "Extracting ArchLinuxARM root filesystem..."
"${tar_cmd}" --exclude="boot/*" --exclude="usr/lib/firmware/*" --exclude="usr/lib/modules/*" -xz -C "${mnt}" -f "${FILE_NAME}"

#TODO: Labels, default command etc.

# Clean up downloaded files
rm -f "${FILE_NAME}" "${MD5SUM_FILE}"

# Commit the container
echo "Committing the container..."
buildah commit "${ctr}" archlinuxarm

echo "Script completed successfully."
