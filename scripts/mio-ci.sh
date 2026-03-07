#!/bin/bash
#
# Compile script for hanikrnl. – Adapted for citrus
#
SECONDS=0
KERNEL_PATH=$1  # Path to kernel source passed as argument
AK3_DIR="$HOME/tc/AnyKernel3"
DEFCONFIG="vendor/citrus-perf_defconfig"  # Your device defconfig

export KBUILD_BUILD_VERSION=69
export KBUILD_BUILD_USER=mio
export KBUILD_BUILD_HOST=keion

# Install needed tools
if [[ $2 = "-t" || $2 = "--tools" ]]; then
        cd $KERNEL_PATH
        mkdir -p toolchain
        cd toolchain

        curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman" || exit 1
        chmod +x antman

        echo 'Setting up toolchain in $(pwd)/toolchain'
        bash antman -S --noprogress || exit 1

        echo 'Patch for glibc'
        bash antman --patch=glibc
fi

# Regenerate defconfig file (optional, not used in CI)
if [[ $2 = "-r" || $2 = "--regen" ]]; then
        cd $KERNEL_PATH
        make O=out ARCH=arm64 $DEFCONFIG savedefconfig
        cp out/defconfig arch/arm64/configs/$DEFCONFIG
        echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
fi

if [[ $2 = "-b" || $2 = "--build" ]]; then
        cd $KERNEL_PATH
        export PATH=$(pwd)/toolchain/bin:$PATH
        mkdir -p out
        make O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1 $DEFCONFIG
        echo -e "\n\n*****************************"
        echo -e "** Starting compilation... **"
        echo -e "*****************************\n\n"
        make O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1 -j$(nproc) || exit 1

        kernel="out/arch/arm64/boot/Image"
        dtbo="out/arch/arm64/boot/dtbo.img"
        dtb="out/arch/arm64/boot/dtb.img"

        if [ -f "$kernel" ]; then
                rm *.zip 2>/dev/null
                lastcommit=$(git -C $KERNEL_PATH log -n 1 --pretty=format:'%h' | cut -c 1-7)
                ZIPNAME="4.19-citrus."$lastcommit"-$(date '+%d.%m.%y-%H%M').zip"
                echo -e "\n\n********************************************"
                echo -e "Kernel compiled succesfully! Zipping up...\n"
                echo -e "********************************************\n\n"

                if [ -d "$AK3_DIR" ]; then
                        cp -r $AK3_DIR AnyKernel3
                elif ! git clone -q https://github.com/Dominium-Apum/AnyKernel3 -b main; then
                        echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
                        exit 1
                fi

                cp $kernel AnyKernel3
                cp $dtbo AnyKernel3
                cp $dtb AnyKernel3

                cd AnyKernel3
                rm README.md && cp ../README.md ./README 2>/dev/null || true
                zip -r9 "../$ZIPNAME" * -x .git *placeholder
                cd ..

                echo -e "\n\n************************************************************"
                echo -e "**   File name: $ZIPNAME   **"
                echo -e "**   Build completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!    **"
                echo -e "************************************************************\n\n"
        else
                echo -e "\n\n*****************************"
                echo -e "**   Compilation failed!   **"
                echo -e "*****************************\n\n"
                exit 1
        fi
fi
