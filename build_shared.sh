set -e
# Check if mkdtimg tool exist
# Mkdtimg tool
MKDTIMG=$ANDROID_ROOT/out/host/linux-x86/bin/mkdtimg
[ ! -f "$MKDTIMG" ] && MKDTIMG="$ANDROID_ROOT/prebuilts/misc/linux-x86/libufdt/mkdtimg"
[ ! -f "$MKDTIMG" ] && MKDTIMG="$ANDROID_ROOT/system/libufdt/utils/src/mkdtboimg.py"
[ ! -f "$MKDTIMG" ] && (echo "No mkdtbo script/executable found"; exit 1)

cd "$KERNEL_TOP"/kernel

echo "================================================="
echo "Your Environment:"
echo "ANDROID_ROOT: ${ANDROID_ROOT}"
echo "KERNEL_TOP  : ${KERNEL_TOP}"
echo "KERNEL_TMP  : ${KERNEL_TMP}"
echo "MKDTIMG     : ${MKDTIMG}"

BUILD_ARGS="${BUILD_ARGS} \
ARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
-j$(nproc)"

for platform in $PLATFORMS; do \

    case $platform in
        tama)
            DEVICE=$TAMA;
            DTBO="true";;
    esac

    for device in $DEVICE; do \
        (
            if [ ! $only_build_for ] || [ $device = $only_build_for ] ; then

                # Don't override $KERNEL_TMP when set by manually
                [ ! "$build_directory" ] && KERNEL_TMP_DEVICE=$KERNEL_TMP/${device}
                # Keep kernel tmp when building for a specific device or when using keep tmp
                [ ! "$keep_kernel_tmp" ] && [ ! "$only_build_for" ] &&rm -rf "${KERNEL_TMP_DEVICE}"
                mkdir -p "${KERNEL_TMP_DEVICE}"

                BUILD_ARGS_DEVICE="$BUILD_ARGS O=$KERNEL_TMP_DEVICE"

                echo "================================================="
                echo "Platform -> ${platform} :: Device -> $device"
                make $BUILD_ARGS_DEVICE aosp_${platform}_${device}_defconfig

                echo "The build may take up to 10 minutes. Please be patient ..."
                echo "Building new kernel image ..."
                echo "Logging to $KERNEL_TMP_DEVICE/build.log"
                make $BUILD_ARGS_DEVICE > "$KERNEL_TMP_DEVICE/build.log" 2>&1;

                # Check the size of the compiled kernel
                actual_size=$(stat -c%s "$KERNEL_TMP_DEVICE/arch/arm64/boot/Image.gz-dtb")
                max_size=$((16 * 1024 * 1024)) # 16MB

                if (( actual_size > max_size )); then
                    echo "================================================="
                    echo "Error: Kernel size ($((actual_size / 1024)) KB) exceeds 16MB limit!"
                    echo "Devices with an old bootloader have a kernel size limit of 16MB, and we must stay within that size."
                    echo "================================================="
                    exit 1
                fi

                echo "Copying new kernel image ..."
                cp "$KERNEL_TMP_DEVICE/arch/arm64/boot/Image.gz-dtb" "$KERNEL_TOP/common-kernel/kernel-dtb-$device"
                if [ "$DTBO" = "true" ]; then
                    # shellcheck disable=SC2046
                    # note: We want wordsplitting in this case.
                    $MKDTIMG create "$KERNEL_TOP"/common-kernel/dtbo-${device}.img $(find "$KERNEL_TMP_DEVICE"/arch/arm64/boot/dts -name "*.dtbo")
                fi

            fi
        )
    done
done

echo "================================================="
echo "Done!"
