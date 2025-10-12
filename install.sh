#!/bin/bash
set -e

# ========== Configuration ==========
INSTALL_DIR=${1:-"$HOME/rmvision/pnx_autoaim/third_party_install"}
NUM_JOBS=$(nproc)

echo "📦 Installing 3rd-party libraries to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$(dirname "$0")"

# ========== Basic Dependencies ==========
echo "🚀 Updating apt and installing build dependencies..."
sudo apt update
sudo apt install -y \
  build-essential cmake git wget unzip pkg-config \
  libgoogle-glog-dev libgflags-dev libatlas-base-dev \
  libsuitesparse-dev libeigen3-dev python3-dev \
  libboost-all-dev

# =======================================
# ========== OpenVINO Runtime ===========
# =======================================
echo "🧩 Installing OpenVINO Runtime (ARM64 / Ubuntu 22.04)..."
cd /tmp
OPENVINO_FILE=openvino_toolkit_ubuntu22_2025.3.0.19807.44526285f24_arm64.tgz
wget -O "$OPENVINO_FILE" "https://storage.openvinotoolkit.org/repositories/openvino/packages/2025.3/linux/$OPENVINO_FILE"

# 检查文件大小 >1MB 防止下载到 404 页面
if [ $(stat -c%s "$OPENVINO_FILE") -lt 1000000 ]; then
    echo "❌ Downloaded file is too small, maybe 404 page"
    exit 1
fi

# 解压 runtime
tar -xzf "$OPENVINO_FILE"
DIR_NAME=$(tar -tf "$OPENVINO_FILE" | head -n1 | cut -d/ -f1)

# 拷贝 runtime 到安装目录
mkdir -p "$INSTALL_DIR/openvino"
cp -r "$DIR_NAME/runtime" "$INSTALL_DIR/openvino/"

# =======================================
# ========== Generate CMake Config ======
# =======================================
CMAKE_DIR="$INSTALL_DIR/lib/cmake/openvino2024.3.0"
mkdir -p "$CMAKE_DIR"

cat <<EOF > "$CMAKE_DIR/OpenVINOConfig.cmake"
# Auto-generated OpenVINOConfig.cmake for CMake

set(OpenVINO_FOUND TRUE)
set(OpenVINO_VERSION 2025.3.0)

# runtime library
add_library(openvino::runtime SHARED IMPORTED)
set_target_properties(openvino::runtime PROPERTIES
    IMPORTED_LOCATION "\${CMAKE_CURRENT_LIST_DIR}/../../openvino/runtime/lib/libopenvino_runtime.so"
    INTERFACE_INCLUDE_DIRECTORIES "\${CMAKE_CURRENT_LIST_DIR}/../../openvino/runtime/include"
)

# ONNX frontend library
add_library(openvino::frontend::onnx SHARED IMPORTED)
set_target_properties(openvino::frontend::onnx PROPERTIES
    IMPORTED_LOCATION "\${CMAKE_CURRENT_LIST_DIR}/../../openvino/runtime/lib/libopenvino_onnx_frontend.so"
    INTERFACE_INCLUDE_DIRECTORIES "\${CMAKE_CURRENT_LIST_DIR}/../../openvino/runtime/include"
)
EOF

echo "✅ OpenVINO runtime and CMake config installed into $INSTALL_DIR"

# =======================================
# ========== Environment Variables ======
# =======================================
echo "🔧 Adding environment variables to ~/.bashrc ..."
grep -qxF "export OPENVINO_DIR=$INSTALL_DIR" ~/.bashrc || cat <<EOF >> ~/.bashrc

# ====== OpenVINO ======
export OPENVINO_DIR=$INSTALL_DIR
export CMAKE_PREFIX_PATH=\$OPENVINO_DIR/lib/cmake/openvino2024.3.0:\$CMAKE_PREFIX_PATH
export LD_LIBRARY_PATH=\$OPENVINO_DIR/runtime/lib:\$LD_LIBRARY_PATH
EOF

source ~/.bashrc
echo "✅ Installation complete!"
