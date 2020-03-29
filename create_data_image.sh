#!/bin/bash

TOTAL_SIZE=0

echo "Gathering applications..."
for app in apps/*; do
	if test -f "$app";	then
		SIZE="$(stat -Lc %s "$app")"
		TOTAL_SIZE=$((${TOTAL_SIZE} + ${SIZE}))
		echo "app: ${app} - $((${SIZE} / 1024)) kB"
	else
		echo "skipping non-regular file: $app"
	fi
done
echo "Total data size: ${TOTAL_SIZE} bytes"
echo

# Pick a partition size that is large enough to contain all files but not much
# larger so the image stays small.
IMAGE_SIZE=$((8 + ${TOTAL_SIZE} / (920*1024)))

set -e
echo "Preparing data for the data partition..."
rm -rf tmp-data
mkdir tmp-data
install -m 755 -d tmp-data/apps
for app in apps/*; do
	if test -f "$app"; then
		install -m 644 -t tmp-data/apps/ "$app"
	fi
done
install -m 755 -d tmp-data/local/etc/init.d
install -m 755 resize_data_part_launcher.target-sh tmp-data/local/etc/init.d/S00resize
install -m 755 resize_data_part.target-sh tmp-data/resize_data_part.sh

echo "Creating data partition of ${IMAGE_SIZE} MB..."
mkdir -p images
dd if=/dev/zero of=images/data.bin bs=1M count=${IMAGE_SIZE}
MKE2FS_CONFIG=mke2fs.conf /sbin/mkfs.ext4 -b4096 -I128 -m3 \
		-E lazy_itable_init=0,lazy_journal_init=0,resize=268435456,root_owner=0:0 \
		-d tmp-data \
		-F images/data.bin
echo

rm -rf tmp-data
