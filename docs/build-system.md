# GitHub Actions 签名构建方案

这是为 NextPlay 项目设计的完整 GitHub Actions 签名构建方案。

## 🎯 方案特点

- **完全自动化**: 推送到 main 分支时自动触发构建和发布
- **智能版本管理**: 基于提交信息自动判断版本号更新类型
- **安全签名**: 使用现有的 GitHub Secrets 进行应用签名
- **多格式支持**: 同时构建 APK 和 AAB 文件
- **完整的发布流程**: 自动创建 GitHub Release 并上传构建产物

## 📁 文件结构

```
.github/workflows/
├── build-and-release.yml    # 主要的构建和发布工作流
├── build.yml               # 基础构建和测试工作流
└── release.yml             # 已弃用的旧工作流

scripts/
└── build.sh                # 本地构建脚本
```

## 🔧 工作流说明

### 1. Build and Release 工作流 (`build-and-release.yml`)

**触发条件:**
- 推送到 `main` 分支时自动触发
- 手动触发 (workflow_dispatch) 可选择版本类型

**主要功能:**
- 代码分析和测试
- 自动版本号计算
- 签名构建 APK 和 AAB
- 创建 GitHub Release
- 上传构建产物

**版本号计算规则:**
- `feat!:` 或 `BREAKING CHANGE` → major 版本
- `feat:` → minor 版本  
- 其他 → patch 版本

### 2. Build 工作流 (`build.yml`)

**触发条件:**
- 推送到 `main` 或 `develop` 分支
- Pull Request 到 `main` 分支

**主要功能:**
- 代码分析和测试
- 构建 debug APK (仅 PR)

## 🔐 所需的 GitHub Secrets

项目已配置以下 Secrets:
- `KEYSTORE_BASE64`: Base64 编码的签名文件
- `KEYSTORE_PASSWORD`: 签名文件密码
- `KEY_ALIAS`: 密钥别名
- `KEY_PASSWORD`: 密钥密码

## 🚀 使用方法

### 自动发布

1. 将代码推送到 `main` 分支
2. 工作流自动运行
3. 根据提交信息自动确定版本类型
4. 构建并发布新版本

### 手动发布

1. 进入 GitHub Actions 页面
2. 选择 "Build and Release" 工作流
3. 点击 "Run workflow"
4. 选择版本类型 (patch/minor/major)
5. 运行工作流

### 本地构建

使用提供的构建脚本:

```bash
# 构建 debug APK
./scripts/build.sh

# 构建签名的 release APK
./scripts/build.sh -t release -s

# 构建 APK 和 AAB
./scripts/build.sh -t release -f both -s

# 显示帮助
./scripts/build.sh -h
```

## 📱 构建产物

每次发布会生成:
- `nextplay-vX.X.X.apk` - 签名的 APK 文件
- `nextplay-vX.X.X.aab` - 签名的 App Bundle 文件
- `checksums.txt` - 校验和文件

## 🔄 升级指南

### 从旧工作流迁移

1. 旧的 `release.yml` 已被标记为弃用
2. 新的构建流程在 `build-and-release.yml` 中
3. 所有现有的 Secrets 都被重用
4. 无需更改任何配置

### Android 构建配置更新

- 添加了签名配置的条件检查
- 避免在没有签名信息时构建失败
- 支持本地开发和 CI 环境

## 💡 最佳实践

1. **提交信息规范**: 使用 Conventional Commits 格式
   - `feat: 添加新功能` → minor 版本
   - `fix: 修复bug` → patch 版本
   - `feat!: 重大变更` → major 版本

2. **分支策略**:
   - `main` 分支: 稳定版本，触发自动发布
   - `develop` 分支: 开发版本，仅运行测试
   - PR: 运行测试并构建 debug 版本

3. **本地测试**: 使用本地构建脚本验证构建流程

## 🛠 故障排除

### 签名相关问题
- 确认所有 Secrets 都已正确配置
- 检查 Base64 编码是否正确
- 验证密钥别名和密码

### 构建失败
- 检查 Flutter 版本兼容性
- 确认所有依赖都已正确配置
- 查看构建日志了解具体错误

### 版本号问题
- 确认 git 标签格式正确 (vX.X.X)
- 检查提交信息格式是否符合规范