#!/bin/bash

# NextPlay 本地构建脚本 - 支持动态版本号
# 遵循策略3：结合semantic-release的动态版本号管理

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 工具函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."

    if ! command -v flutter &> /dev/null; then
        log_error "Flutter 未安装或不在 PATH 中"
        exit 1
    fi

    if ! command -v npx &> /dev/null; then
        log_warning "npx 未安装，将跳过 semantic-release 版本检测"
        return 1
    fi

    return 0
}

# 获取版本信息
get_version_info() {
    log_info "检测版本信息..."

    # 获取当前 pubspec.yaml 中的版本
    CURRENT_VERSION=$(grep -oP 'version: \K[^+]+' pubspec.yaml)
    if [ -z "$CURRENT_VERSION" ]; then
        log_error "无法从 pubspec.yaml 读取当前版本"
        exit 1
    fi

    log_info "当前版本: $CURRENT_VERSION"

    # 尝试获取 semantic-release 的下一个版本
    SEMANTIC_VERSION=""
    if check_dependencies; then
        log_info "尝试获取 semantic-release 版本..."
        SEMANTIC_VERSION=$(npx semantic-release --dry-run --no-ci 2>/dev/null | grep -oP 'The next release version is \K\d+\.\d+\.\d+' || echo "")

        if [ -n "$SEMANTIC_VERSION" ]; then
            log_success "检测到 semantic-release 版本: $SEMANTIC_VERSION"
        else
            log_info "未检测到新的 semantic-release 版本，使用当前版本"
        fi
    fi

    # 选择版本：有 semantic 版本就用 semantic，否则用当前版本
    VERSION=${SEMANTIC_VERSION:-$CURRENT_VERSION}

    # 生成构建号
    if [ -n "$GITHUB_RUN_NUMBER" ]; then
        # CI 环境使用 GitHub run number
        BUILD_NUMBER=$GITHUB_RUN_NUMBER
        log_info "CI 环境，使用 GitHub run number: $BUILD_NUMBER"
    else
        # 本地环境使用时间戳
        BUILD_NUMBER=$(date +%Y%m%d%H%M)
        log_info "本地环境，使用时间戳构建号: $BUILD_NUMBER"
    fi

    FULL_VERSION="$VERSION+$BUILD_NUMBER"
    log_success "最终版本: $FULL_VERSION"
}

# 运行 flutter pub get
flutter_pub_get() {
    log_info "获取 Flutter 依赖..."
    flutter pub get
    log_success "依赖获取完成"
}

# 构建应用
build_app() {
    local build_type=${1:-"apk"}

    log_info "构建 Flutter 应用 ($build_type)..."
    log_info "使用版本: $VERSION"
    log_info "使用构建号: $BUILD_NUMBER"

    case $build_type in
        "apk")
            flutter build apk --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            log_success "APK 构建完成"
            ;;
        "appbundle")
            flutter build appbundle --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            log_success "App Bundle 构建完成"
            ;;
        "web")
            flutter build web --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            log_success "Web 构建完成"
            ;;
        *)
            log_error "不支持的构建类型: $build_type"
            log_info "支持的类型: apk, appbundle, web"
            exit 1
            ;;
    esac
}

# 显示构建信息
show_build_info() {
    log_success "构建完成!"
    echo ""
    log_info "构建信息:"
    echo "  应用名称: NextPlay"
    echo "  版本号: $VERSION"
    echo "  构建号: $BUILD_NUMBER"
    echo "  完整版本: $FULL_VERSION"
    echo "  构建时间: $(date)"
    echo ""

    if [ "$1" = "apk" ]; then
        if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
            APK_SIZE=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
            log_info "APK 位置: build/app/outputs/flutter-apk/app-release.apk"
            log_info "APK 大小: $APK_SIZE"
        fi
    fi
}

# 主函数
main() {
    echo ""
    log_info "🚀 NextPlay 构建脚本启动"
    echo ""

    # 检查是否在项目根目录
    if [ ! -f "pubspec.yaml" ]; then
        log_error "请在项目根目录执行此脚本"
        exit 1
    fi

    # 解析命令行参数
    BUILD_TYPE="apk"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            --help|-h)
                echo "NextPlay 构建脚本"
                echo ""
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --type TYPE     构建类型 (apk, appbundle, web), 默认: apk"
                echo "  --help, -h      显示帮助信息"
                echo ""
                echo "示例:"
                echo "  $0                    # 构建 APK"
                echo "  $0 --type appbundle   # 构建 App Bundle"
                echo "  $0 --type web         # 构建 Web"
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                echo "使用 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done

    # 执行构建流程
    get_version_info
    flutter_pub_get
    build_app "$BUILD_TYPE"
    show_build_info "$BUILD_TYPE"

    echo ""
    log_success "🎉 构建流程完成!"
}

# 捕获错误并清理
trap 'log_error "构建过程中发生错误"; exit 1' ERR

# 执行主函数
main "$@"