#!/bin/bash

# NextPlay 本地构建脚本
# 用于本地测试构建流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数定义
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要工具
check_requirements() {
    log_info "检查构建环境..."
    
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter 未安装或不在 PATH 中"
        exit 1
    fi
    
    if ! command -v java &> /dev/null; then
        log_error "Java 未安装或不在 PATH 中"
        exit 1
    fi
    
    log_success "构建环境检查通过"
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    rm -f android/app/release-key.jks
    rm -f key.properties
    log_success "清理完成"
}

# 注册清理函数
trap cleanup EXIT

# 显示帮助信息
show_help() {
    echo "NextPlay 构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -t, --type TYPE     构建类型 (debug|release|profile) [默认: debug]"
    echo "  -f, --format FORMAT 输出格式 (apk|aab|both) [默认: apk]"
    echo "  -s, --signed        使用签名构建 (仅对 release 有效)"
    echo "  -c, --clean         构建前清理"
    echo "  -a, --analyze       运行代码分析"
    echo "  -h, --help          显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                          # 构建 debug APK"
    echo "  $0 -t release -s           # 构建签名的 release APK"
    echo "  $0 -t release -f both -s   # 构建签名的 APK 和 AAB"
    echo "  $0 -c -a                   # 清理构建并运行分析"
}

# 默认参数
BUILD_TYPE="debug"
OUTPUT_FORMAT="apk"
USE_SIGNING=false
CLEAN_BUILD=false
RUN_ANALYZE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BUILD_TYPE="$2"
            if [[ ! "$BUILD_TYPE" =~ ^(debug|release|profile)$ ]]; then
                log_error "无效的构建类型: $BUILD_TYPE"
                exit 1
            fi
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            if [[ ! "$OUTPUT_FORMAT" =~ ^(apk|aab|both)$ ]]; then
                log_error "无效的输出格式: $OUTPUT_FORMAT"
                exit 1
            fi
            shift 2
            ;;
        -s|--signed)
            USE_SIGNING=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -a|--analyze)
            RUN_ANALYZE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主构建流程
main() {
    log_info "开始构建 NextPlay..."
    log_info "构建类型: $BUILD_TYPE"
    log_info "输出格式: $OUTPUT_FORMAT"
    log_info "使用签名: $USE_SIGNING"
    
    check_requirements
    
    # 清理构建
    if [[ "$CLEAN_BUILD" == true ]]; then
        log_info "清理构建缓存..."
        flutter clean
        log_success "清理完成"
    fi
    
    # 获取依赖
    log_info "获取依赖..."
    flutter pub get
    
    # 代码生成
    log_info "运行代码生成..."
    flutter packages pub run build_runner build --delete-conflicting-outputs
    
    # 代码分析
    if [[ "$RUN_ANALYZE" == true ]]; then
        log_info "运行代码分析..."
        flutter analyze
        log_success "代码分析通过"
    fi
    
    # 设置签名（仅当 release 构建且需要签名时）
    if [[ "$BUILD_TYPE" == "release" && "$USE_SIGNING" == true ]]; then
        setup_signing
    fi
    
    # 构建应用
    build_app
    
    log_success "构建完成!"
    show_build_results
}

# 设置签名配置
setup_signing() {
    log_info "设置签名配置..."
    
    # 检查是否有签名文件
    if [[ ! -f "android/keystore/release-key.jks" ]]; then
        log_warning "未找到签名文件 android/keystore/release-key.jks"
        log_warning "将使用未签名构建"
        USE_SIGNING=false
        return
    fi
    
    # 创建 key.properties 文件
    cat > key.properties << EOF
storeFile=android/keystore/release-key.jks
storePassword=${KEYSTORE_PASSWORD:-your_store_password}
keyAlias=${KEY_ALIAS:-your_key_alias}
keyPassword=${KEY_PASSWORD:-your_key_password}
EOF
    
    log_success "签名配置完成"
}

# 构建应用
build_app() {
    log_info "构建应用..."
    
    case "$OUTPUT_FORMAT" in
        "apk")
            build_apk
            ;;
        "aab")
            build_aab
            ;;
        "both")
            build_apk
            build_aab
            ;;
    esac
}

# 构建 APK
build_apk() {
    log_info "构建 APK..."
    flutter build apk --$BUILD_TYPE
    log_success "APK 构建完成"
}

# 构建 AAB
build_aab() {
    log_info "构建 App Bundle..."
    flutter build appbundle --$BUILD_TYPE
    log_success "App Bundle 构建完成"
}

# 显示构建结果
show_build_results() {
    log_info "构建结果:"
    
    # APK 文件
    if [[ "$OUTPUT_FORMAT" == "apk" || "$OUTPUT_FORMAT" == "both" ]]; then
        APK_PATH="build/app/outputs/flutter-apk/app-$BUILD_TYPE.apk"
        if [[ -f "$APK_PATH" ]]; then
            APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
            log_success "APK: $APK_PATH ($APK_SIZE)"
        fi
    fi
    
    # AAB 文件
    if [[ "$OUTPUT_FORMAT" == "aab" || "$OUTPUT_FORMAT" == "both" ]]; then
        AAB_PATH="build/app/outputs/bundle/${BUILD_TYPE}/app-$BUILD_TYPE.aab"
        if [[ -f "$AAB_PATH" ]]; then
            AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
            log_success "AAB: $AAB_PATH ($AAB_SIZE)"
        fi
    fi
}

# 运行主程序
main "$@"