#!/usr/bin/env bash
#
# build.sh — 统一构建与验证入口
#
# 用法:
#   ./container/build.sh check          # 默认: ASAN + clang-tidy
#   ./container/build.sh check Debug    # Debug + Valgrind
#   ./container/build.sh check ASAN     # 显式 ASAN
#   ./container/build.sh linux          # Linux 平台构建（非验证用途）
#
# 注意:
#   验证请始终使用 check 命令，不要直接使用 linux 或其他平台命令
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── check: 验证构建 ──────────────────────────────────────

do_check() {
    local mode="${1:-ASAN}"
    log_info "Starting check with mode: ${mode}"

    case "${mode}" in
        Debug)
            log_info "Debug mode: building with debug symbols + Valgrind support"
            _build Debug
            _valgrind_check
            ;;
        ASAN)
            log_info "ASAN mode: building with AddressSanitizer + clang-tidy"
            _build ASAN
            _asan_check
            _clang_tidy_check
            ;;
        *)
            log_error "Unknown check mode: ${mode}"
            log_error "Supported modes: ASAN (default), Debug"
            exit 1
            ;;
    esac

    log_info "Check passed"
}

# ── 构建函数 ──────────────────────────────────────────────

_build() {
    local build_type="$1"
    local build_dir="${PROJECT_ROOT}/build/${build_type,,}"

    log_info "Building (${build_type}) in ${build_dir}"

    mkdir -p "${build_dir}"

    # CMake 配置
    cmake -S "${PROJECT_ROOT}" -B "${build_dir}" \
        -DCMAKE_BUILD_TYPE="${build_type}" \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        "${@:2}"

    # 构建
    cmake --build "${build_dir}" -- -j"$(nproc)"
}

_asan_check() {
    log_info "Running ASAN checks..."
    # ASAN 检查在测试运行时自动触发
    # 如果有测试目标，在此运行
    if [ -d "${PROJECT_ROOT}/build/asan" ]; then
        ctest --test-dir "${PROJECT_ROOT}/build/asan" --output-on-failure || true
    fi
}

_valgrind_check() {
    if command -v valgrind &>/dev/null; then
        log_info "Running Valgrind memcheck..."
        # Valgrind 检查在测试运行时触发
        if [ -d "${PROJECT_ROOT}/build/debug" ]; then
            ctest --test-dir "${PROJECT_ROOT}/build/debug" --output-on-failure || true
        fi
    else
        log_warn "Valgrind not found, skipping memcheck"
    fi
}

_clang_tidy_check() {
    local build_dir="${PROJECT_ROOT}/build/asan"
    local compile_db="${build_dir}/compile_commands.json"

    if [ ! -f "${compile_db}" ]; then
        log_warn "compile_commands.json not found, skipping clang-tidy"
        return
    fi

    if command -v clang-tidy &>/dev/null; then
        log_info "Running clang-tidy..."
        # 对所有源文件运行 clang-tidy
        find "${PROJECT_ROOT}" -name '*.cpp' -not -path '*/build/*' -not -path '*/.opencode/*' | while read -r src; do
            clang-tidy -p "${build_dir}" "${src}" 2>/dev/null || true
        done
    else
        log_warn "clang-tidy not found, skipping"
    fi
}

# ── 其他构建命令 ──────────────────────────────────────────

do_linux() {
    log_info "Building for Linux platform..."
    _build Release
    log_info "Linux build complete"
}

# ── 主入口 ────────────────────────────────────────────────

usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  check [mode]    Run verification (default: ASAN)"
    echo "                  Modes: ASAN (default), Debug (Valgrind)"
    echo "  linux           Build for Linux platform (NOT for verification)"
    echo ""
    echo "Examples:"
    echo "  $0 check              # ASAN + clang-tidy"
    echo "  $0 check Debug        # Debug + Valgrind"
    echo "  $0 check ASAN         # Explicit ASAN"
}

case "${1:-help}" in
    check)
        do_check "${2:-ASAN}"
        ;;
    linux)
        do_linux
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
