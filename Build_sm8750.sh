#!/bin/bash

# 颜色定义
info() {
  tput setaf 3  
  echo "[INFO] $1"
  tput sgr0
}

error() {
  tput setaf 1
  echo "[ERROR] $1"
  tput sgr0
  exit 1
}

# 参数设置
ENABLE_KPM=true
ENABLE_LZ4KD=true

# 机型选择
info "请选择要编译的机型："
info "1. 一加 Ace 5 Pro"
info "2. 一加 13"
info "3.一加 13T"
info "4.一加 Pad 2 Pro"
info "5.一加 Ace5 至尊版"
info "6.真我 GT 7 Pro"
info "7.真我 GT 7 Pro 竞速版"

read -p "输入选择 [1-4]: " device_choice

case $device_choice in
    1)
        DEVICE_NAME="oneplus_ace5_pro"
        REPO_MANIFEST="JiuGeFaCai_oneplus_ace5_pro_v.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    2)
        DEVICE_NAME="oneplus_13"
        REPO_MANIFEST="JiuGeFaCai_oneplus_13_v.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    3)
        DEVICE_NAME="oneplus_13t"
        REPO_MANIFEST="oneplus_13t.xml"
        KERNEL_TIME="FriApr 25 01:56:53 UTC 2025"
        KERNEL_SUFFIX="-android15-8-gba3bcfd39307-abogki413159095-4k"
        ;;
    4)
        DEVICE_NAME="oneplus_pad_2_pro"
        REPO_MANIFEST="oneplus_pad_2_pro.xml"
        KERNEL_TIME="Wed Dec 11 19:16:38 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g0261dbe3cf7e-ab12786384-4k"   
        ;;
    5)
        DEVICE_NAME="oneplus_ace5_ultra"
        REPO_MANIFEST="oneplus_ace5_ultra.xml"
        KERNEL_TIME="Fri Apr 18 19:35:07 UTC 2025"
        KERNEL_SUFFIX="-android15-8-gfc70d29746a7-abogki412262948-4k"
        ;;  
    6)
        DEVICE_NAME="realme_GT7pro"
        REPO_MANIFEST="realme_GT7pro.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    7)
        DEVICE_NAME="realme_GT7pro_Speed"
        REPO_MANIFEST="realme_GT7pro_Speed.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    *)
        error "无效的选择，请输入1-3之间的数字"
        ;;
esac

# 自定义补丁
# 函数：用于判断输入，确保无效输入返回默认值
prompt_boolean() {
    local prompt="$1"
    local default_value="$2"
    local result
    read -p "$prompt" result
    case "$result" in
        [nN]) echo false ;;
        [yY]) echo true ;;
        "") echo "$default_value" ;;
        *) echo "$default_value" ;;
    esac
}

# 自定义补丁设置

read -p "输入内核名称修改(可改中文和emoji，回车默认): " input_suffix
[ -n "$input_suffix" ] && KERNEL_SUFFIX="$input_suffix"

read -p "输入内核构建日期更改(回车默认为原厂): " input_time
[ -n "$input_time" ] && KERNEL_TIME="$input_time"

ENABLE_KPM=$(prompt_boolean "是否启用KPM？(回车默认开启) [y/N]: " true)
ENABLE_LZ4KD=$(prompt_boolean "是否启用LZ4KD？(回车默认开启) [y/N]: " true)
ENABLE_BBR=$(prompt_boolean "是否启用BBR？(回车默认关闭) [y/N]: " false)

# 选择的机型信息输出
info "选择的机型: $DEVICE_NAME"
info "内核源码文件: $REPO_MANIFEST"
info "内核名称: $KERNEL_SUFFIX"
info "内核时间: $KERNEL_TIME"
info "是否开启KPM: $ENABLE_KPM"
info "是否开启LZ4KD: $ENABLE_LZ4KD"
info "是否开启BBR: $ENABLE_BBR"

# 环境变量 - 按机型区分ccache目录
export CCACHE_COMPILERCHECK="%compiler% -dumpmachine; %compiler% -dumpversion"
export CCACHE_NOHASHDIR="true"
export CCACHE_HARDLINK="true"
export CCACHE_DIR="$HOME/.ccache_${DEVICE_NAME}"  # 改为按机型区分
export CCACHE_MAXSIZE="8G"

# ccache 初始化标志文件也按机型区分
CCACHE_INIT_FLAG="$CCACHE_DIR/.ccache_initialized"

# 初始化 ccache（仅第一次）
if command -v ccache >/dev/null 2>&1; then
    if [ ! -f "$CCACHE_INIT_FLAG" ]; then
        info "第一次为${DEVICE_NAME}初始化ccache..."
        mkdir -p "$CCACHE_DIR" || error "无法创建ccache目录"
        ccache -M "$CCACHE_MAXSIZE"
        touch "$CCACHE_INIT_FLAG"
    else
        info "ccache (${DEVICE_NAME}) 已初始化，跳过..."
    fi
else
    info "未安装 ccache，跳过初始化"
fi

# 工作目录 - 按机型区分
WORKSPACE="$HOME/kernel_${DEVICE_NAME}"
mkdir -p "$WORKSPACE" || error "无法创建工作目录"
cd "$WORKSPACE" || error "无法进入工作目录"

# 检查并安装依赖
info "检查并安装依赖..."
DEPS=(make python3 git curl ccache flex bison libssl-dev libelf-dev bc zip)
MISSING_DEPS=()

for pkg in "${DEPS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_DEPS+=("$pkg")
    fi
done

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    info "所有依赖已安装，跳过安装。"
else
    info "缺少依赖：${MISSING_DEPS[*]}，正在安装..."
    sudo apt update || error "系统更新失败"
    sudo apt install -y "${MISSING_DEPS[@]}" || error "依赖安装失败"
fi

# 配置 Git（仅在未配置时）
info "检查 Git 配置..."

GIT_NAME=$(git config --global user.name || echo "")
GIT_EMAIL=$(git config --global user.email || echo "")

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    info "Git 未配置，正在设置..."
    git config --global user.name "Q1udaoyu"
    git config --global user.email "sucisama2888@gmail.com"
else
    info "Git 已配置："
fi

# 安装repo工具（仅首次）
if ! command -v repo >/dev/null 2>&1; then
    info "安装repo工具..."
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo > ~/repo || error "repo下载失败"
    chmod a+x ~/repo
    sudo mv ~/repo /usr/local/bin/repo || error "repo安装失败"
else
    info "repo工具已安装，跳过安装"
fi

# ==================== 源码管理 ====================

# 创建源码目录
KERNEL_WORKSPACE="$WORKSPACE/kernel_workspace"

mkdir -p "$KERNEL_WORKSPACE" || error "无法创建kernel_workspace目录"

cd "$KERNEL_WORKSPACE" || error "无法进入kernel_workspace目录"

# 初始化源码
info "初始化repo并同步源码..."
repo init -u https://github.com/showdo/kernel_manifest.git -b refs/heads/oneplus/sm8750 -m "$REPO_MANIFEST" --depth=1 || error "repo初始化失败"
repo --trace sync -c -j$(nproc --all) --no-tags || error "repo同步失败"

# ==================== 核心构建步骤 ====================

# 清理保护导出
info "清理保护导出文件..."
rm -f kernel_platform/common/android/abi_gki_protected_exports_*
rm -f kernel_platform/msm-kernel/android/abi_gki_protected_exports_*

# 设置SukiSU
info "设置SukiSU..."
cd kernel_platform || error "进入kernel_platform失败"
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/susfs-1.5.8/kernel/setup.sh" | bash -s susfs-1.5.8 || error "SukiSU设置失败"

cd KernelSU || error "进入KernelSU目录失败"
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count main) "+" 10700)
export KSU_VERSION=$KSU_VERSION
sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile || error "修改KernelSU版本失败"
info "$KSU_VERSION"

# 设置susfs
info "设置susfs..."
cd "$KERNEL_WORKSPACE" || error "返回工作目录失败"
git clone -q https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android15-6.6 || info "susfs4ksu已存在或克隆失败"
git clone https://github.com/Xiaomichael/kernel_patches.git
git clone -q https://github.com/SukiSU-Ultra/SukiSU_patch.git || info "SukiSU_patch已存在或克隆失败"

cd kernel_platform || error "进入kernel_platform失败"
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch ./common/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

if [ "$ENABLE_LZ4KD" = "true"]; then
  cp ../kernel_patches/001-lz4.patch ./common/
  cp ../kernel_patches/lz4armv8.S ./common/lib
  cp ../kernel_patches/002-zstd.patch ./common/
fi

cd $KERNEL_WORKSPACE/kernel_platform/common || { echo "进入common目录失败"; exit 1; }


case "$DEVICE_NAME" in
    oneplus_13t|oneplus_ace5_ultra)
        info "当前编译机型为 $DEVICE_NAME, 跳过patch补丁应用"
        ;;
    *)
        info "DEVICE_NAME is $DEVICE_NAME, 正在应用patch补丁..."
        sed -i 's/-32,12 +32,38/-32,11 +32,37/g' 50_add_susfs_in_gki-android15-6.6.patch
        sed -i '/#include <trace\/hooks\/fs.h>/d' 50_add_susfs_in_gki-android15-6.6.patch
        ;;
esac

patch -p1 < 50_add_susfs_in_gki-android15-6.6.patch || info "SUSFS补丁应用可能有警告"
cp "$KERNEL_WORKSPACE/SukiSU_patch/hooks/syscall_hooks.patch" ./ || error "复制syscall_hooks.patch失败"
patch -p1 -F 3 < syscall_hooks.patch || info "syscall_hooks补丁应用可能有警告"
if [ "$ENABLE_LZ4KD" = "true" ]; then
  git apply -p1 < 001-lz4.patch || true
  patch -p1 < 002-zstd.patch || true
fi

# 应用HMBird GKI补丁
apply_hmbird_patch() {
    info "开始应用HMBird GKI补丁..."
    
    # 进入目录（带错误检查）
    cd drivers || error "进入drivers目录失败"
    
    # 设置补丁URL（移除local关键字）
    patch_url="https://raw.githubusercontent.com/showdo/build_oneplus_sm8750/main/hmbird_patch.c"
    
    info "从GitHub下载补丁文件..."
    if ! curl -sSLo hmbird_patch.c "$patch_url"; then
        error "补丁下载失败，请检查网络或URL: $patch_url"
    fi

    # 验证文件内容
    if ! grep -q "MODULE_DESCRIPTION" hmbird_patch.c; then
        error "下载的文件不完整或格式不正确"
    fi

    # 更新Makefile
    info "更新Makefile配置..."
    if ! grep -q "hmbird_patch.o" Makefile; then
        echo "obj-y += hmbird_patch.o" >> Makefile || error "写入Makefile失败"
    fi

    info "HMBird补丁应用成功！"
}

# 主流程
apply_hmbird_patch

# 返回common目录
cd .. || error "返回common目录失败"
cd arch/arm64/configs || error "进入configs目录失败"
# 添加SUSFS配置
info "添加SUSFS配置..."
echo -e "CONFIG_KSU=y
CONFIG_KSU_SUSFS_SUS_SU=n
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=n
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_842=y
CONFIG_LOCALVERSION_AUTO=n" >> gki_defconfig

# 返回kernel_platform目录
cd $KERNEL_WORKSPACE/kernel_platform || error "返回kernel_platform目录失败"

# 移除check_defconfig
sudo sed -i 's/check_defconfig//' $KERNEL_WORKSPACE/kernel_platform/common/build.config.gki || error "修改build.config.gki失败"

# 添加KPM配置
if [ "$ENABLE_KPM" = "true" ]; then
    info "添加KPM配置..."
    echo "CONFIG_KPM=y" >> common/arch/arm64/configs/gki_defconfig
    sudo sed -i 's/check_defconfig//' common/build.config.gki || error "修改build.config.gki失败"
fi

# 添加BBR配置
if [ "$ENABLE_BBR" = "true" ]; then
    info "添加BBR配置..."
    echo -e "# BBR
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_NET_SCH_FQ=y
CONFIG_TCP_CONG_BIC=n
CONFIG_TCP_CONG_CUBIC=n
CONFIG_TCP_CONG_WESTWOOD=n
CONFIG_TCP_CONG_HTCP=n
CONFIG_DEFAULT_TCP_CONG=bbr" >> common/arch/arm64/configs/gki_defconfig
    sudo sed -i 's/check_defconfig//' common/build.config.gki || error "修改build.config.gki失败"
fi

# 修改内核名称
info "修改内核名称..."
sed -i 's/${scm_version}//' common/scripts/setlocalversion || error "修改setlocalversion失败"
sudo sed -i "s/-4k/${KERNEL_SUFFIX}/g" common/arch/arm64/configs/gki_defconfig || error "修改gki_defconfig失败"

# 应用完美风驰补丁
info "应用完美风驰补丁..."
cd $KERNEL_WORKSPACE/kernel_platform/
git clone https://github.com/HanKuCha/sched_ext.git
cp -r ./sched_ext/* ./common/kernel/sched
rm -rf ./sched_ext/.git
cd $KERNEL_WORKSPACE/kernel_platform/common/kernel/sched  || error "跳转sched目录失败"

# 构建内核
info "开始构建内核..."
export KBUILD_BUILD_TIMESTAMP="$KERNEL_TIME"
export PATH="$KERNEL_WORKSPACE/kernel_platform/prebuilts/clang/host/linux-x86/clang-r510928/bin:$PATH"
export PATH="/usr/lib/ccache:$PATH"

cd $KERNEL_WORKSPACE/kernel_platform/common || error "进入common目录失败"

# 生成.config
make -j$(nproc --all) LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang \
  RUSTC=../../prebuilts/rust/linux-x86/1.73.0b/bin/rustc \
  PAHOLE=../../prebuilts/kernel-build-tools/linux-x86/bin/pahole \
  LD=ld.lld HOSTLD=ld.lld O=out KCFLAGS+=-O2 gki_defconfig all || error "失败"


# 应用Linux补丁
info "应用Linux补丁..."
cd out/arch/arm64/boot || error "进入boot目录失败"
curl -LO https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.12.0/patch_linux || error "下载patch_linux失败"
chmod +x patch_linux
./patch_linux || error "应用patch_linux失败"
rm -f Image
mv oImage Image || error "替换Image失败"

# 创建AnyKernel3包
info "创建AnyKernel3包..."
cd "$WORKSPACE" || error "返回工作目录失败"
git clone -q https://github.com/showdo/AnyKernel3.git --depth=1 || info "AnyKernel3已存在"
rm -rf ./AnyKernel3/.git
rm -f ./AnyKernel3/push.sh
cp "$KERNEL_WORKSPACE/kernel_platform/common/out/arch/arm64/boot/Image" ./AnyKernel3/ || error "复制Image失败"

# 打包
cd AnyKernel3 || error "进入AnyKernel3目录失败"
zip -r "AnyKernel3_${KSU_VERSION}_${DEVICE_NAME}_SuKiSu.zip" ./* || error "打包失败"

# 创建C盘输出目录（通过WSL访问Windows的C盘）
WIN_OUTPUT_DIR="/mnt/c/Kernel_Build/${DEVICE_NAME}/"
mkdir -p "$WIN_OUTPUT_DIR" || error "无法创建Windows目录，可能未挂载C盘，将保存到Linux目录:$WORKSPACE/AnyKernel3/AnyKernel3_${KSU_VERSION}_${DEVICE_NAME}_SuKiSu.zip"

# 复制Image和AnyKernel3包
cp "$KERNEL_WORKSPACE/kernel_platform/common/out/arch/arm64/boot/Image" "$WIN_OUTPUT_DIR/"
cp "$WORKSPACE/AnyKernel3/AnyKernel3_${KSU_VERSION}_${DEVICE_NAME}_SuKiSu.zip" "$WIN_OUTPUT_DIR/"

rm -rf $WORKSPACE
info "内核包路径: C:/Kernel_Build/${DEVICE_NAME}/AnyKernel3_${KSU_VERSION}_${DEVICE_NAME}_SuKiSu.zip"
info "Image路径: C:/Kernel_Build/${DEVICE_NAME}/Image"
info "请在C盘目录中查找内核包和Image文件。"
