#!/bin/bash
# ================================================================
# Setup: build whisper.cpp + download model + install translatepy
# All dependencies will be bundled into .app by build.sh
# ================================================================

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_DIR="$DIR/deps"

echo "=========================================="
echo "  离线双语字幕生成器 - 依赖安装"
echo "=========================================="
echo ""

# ─── Step 1: Build whisper.cpp ─────────────────────────────────
echo "=== [1/3] Building whisper.cpp CLI ==="
mkdir -p "$DEPS_DIR"
if [ ! -d "$DEPS_DIR/whisper.cpp" ]; then
    echo "Cloning whisper.cpp..."
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp "$DEPS_DIR/whisper.cpp"
else
    echo "whisper.cpp already cloned, updating..."
    cd "$DEPS_DIR/whisper.cpp" && git pull --ff-only 2>/dev/null || true
fi

cd "$DEPS_DIR/whisper.cpp"
echo "Compiling (this may take a minute)..."
make -j$(sysctl -n hw.logicalcpu) 2>&1
echo "✅ whisper.cpp compiled"

# ─── Step 2: Download model ────────────────────────────────────
echo ""
echo "=== [2/3] Downloading model ==="

MODEL_DIR="$DEPS_DIR/models"
mkdir -p "$MODEL_DIR"

download_model() {
    local name=$1
    local path="$MODEL_DIR/ggml-${name}.bin"
    if [ -f "$path" ]; then
        echo "  ✅ ggml-${name}.bin already exists"
        return 0
    fi
    echo "  Downloading ggml-${name}.bin..."
    curl -# -L -o "$path" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${name}.bin"
    echo "  ✅ ggml-${name}.bin downloaded"
}

# Default: download base model
download_model "base"
# Optionally download tiny too (faster for testing)
echo ""
read -p "Also download tiny model (faster, ~75MB)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    download_model "tiny"
fi

# ─── Step 3: Install translatepy ──────────────────────────
echo ""
echo "=== [3/3] Installing translatepy ==="
if python3 -c "import argostranslate" 2>/dev/null; then
    echo "✅ translatepy already installed"
else
    echo "Installing translatepy..."
    pip3 install translatepy --user
    echo "✅ translatepy installed"
fi

echo ""
echo "=========================================="
echo "  ✅ Setup complete!"
echo "=========================================="
echo ""
echo "Next:"
echo "  ./build.sh   # Compile app + bundle everything"
echo "  The .app will contain whisper-cli + model files"
echo "  (translatepy is installed system-wide via pip)"
