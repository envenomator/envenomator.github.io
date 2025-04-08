#!/bin/bash

# Usage
if [ "$#" -eq 0 ] || [ "$#" -gt 2 ]; then
    echo "Usage: release [console8|quark] <releasetag>"
    exit 1
fi

# Check required tools
if ! command -v crc32 >/dev/null; then
    echo command 'crc32' not available
    exit 1
fi
if ! command -v unzip >/dev/null; then
    echo command 'unzip' not available
    exit 1
fi
if ! command -v wget >/dev/null; then
    echo command 'wget' not available
    exit 1
fi
if ! command -v esptool.py >/dev/null; then
    echo command 'esptool.py' not available
    exit 1
fi

# Check arguments, or set defaults
if [ "$1" = "console8" ]; then
    if [ "$#" -eq 1 ]; then
        TAG=`curl 2>/dev/null "https://api.github.com/repos/AgonConsole8/agon-vdp/tags" | jq -r '.[0].name'`
    else
        TAG=$2
    fi
#elif [ "$1" = "quark" ]; then
#    if [ "$#" -eq 1 ]; then
#        TAG=`curl 2>/dev/null "https://api.github.com/repos/AgonConsole8/agon-vdp/tags" | jq -r '.[0].name'`
#    else
#        TAG=$2
#    fi
else
    echo "Unknown release type"
    exit 1
fi

# Create directory
RELEASEDIR=./firmware/$1-$TAG
echo Creating release directory \'$RELEASEDIR\'...
rm -rf $RELEASEDIR
mkdir -p $RELEASEDIR

# Copy baseline user tools/scripts
echo Unzipping baseline tools...
unzip -d $RELEASEDIR firmware/baseline.zip >/dev/null 2>&1

# Download latest Console8 release
echo Downloading release binaries...
if ! wget 2>/dev/null https://github.com/AgonConsole8/agon-vdp/releases/download/$TAG/bootloader.bin -P $RELEASEDIR; then
    echo Download of bootloader.bin failed
    exit 1
fi
if ! wget 2>/dev/null https://github.com/AgonConsole8/agon-vdp/releases/download/$TAG/partitions.bin -P $RELEASEDIR; then
    echo Download of partitions.bin failed
    exit 1
fi
if ! wget 2>/dev/null https://github.com/AgonConsole8/agon-vdp/releases/download/$TAG/firmware.bin -P $RELEASEDIR; then
    echo Download of firmware.bin failed
    exit 1
fi

CHECKSUM=`crc32 $RELEASEDIR/firmware.bin`

# Merge binaries
echo Merging binaries...
esptool.py --chip esp32 merge_bin -o "$RELEASEDIR/merged.bin" --flash_mode dio --flash_freq keep --flash_size 4MB 0x1000 "$RELEASEDIR/bootloader.bin" 0x8000 "$RELEASEDIR/partitions.bin" 0x10000 "$RELEASEDIR/firmware.bin"

# Clean-up temporary files
echo Clean-up temporary files
rm $RELEASEDIR/bootloader.bin
rm $RELEASEDIR/firmware.bin
rm $RELEASEDIR/partitions.bin

# Create manifest
echo Create manifest for $TAG
MANIFEST=firmware/manifest_console8-$TAG.json
rm -f $MANIFEST
cp firmware/manifest_template.json $MANIFEST
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/REPLACETAG/$TAG/g" $MANIFEST
else
    sed -i 's/REPLACETAG/$TAG/g' $MANIFEST
fi
# Add to html list
echo Add to INDEX.HTML list
PRESENT=`fgrep $TAG index.html`
if [ -z "$PRESENT" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/<\!\-\-RELEASES\-\->/<\!\-\-RELEASES\-\->\\n        <li><label><input type=\"radio\" name=\"type\" value=\"console8-$TAG\" \/> Console8 VDP $TAG<\/label><\/li>/g" index.html
        sed -i '' 's/\r//' index.html
    else
        sed -i "s/<\!\-\-RELEASES\-\->/<\!\-\-RELEASES\-\->\\n        <li><label><input type=\"radio\" name=\"type\" value=\"console8-$TAG\" \/> Console8 VDP $TAG<\/label><\/li>/g" index.html
        sed -i 's/\r//' index.html
    fi    
fi
echo CRC32 checksum of original firmware is 0x${CHECKSUM}
echo ${CHECKSUM} > $RELEASEDIR/CRC32
echo Done.
