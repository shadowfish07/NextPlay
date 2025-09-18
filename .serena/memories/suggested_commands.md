# NextPlay 常用命令

## 开发命令

### 分析和检查
```bash
flutter analyze              # 静态代码分析（必须执行）
flutter doctor               # 检查Flutter环境
```

### 依赖管理
```bash
flutter pub get              # 获取依赖
flutter pub upgrade          # 升级依赖
flutter pub outdated         # 查看过时依赖
```

### 代码生成
```bash
flutter pub run build_runner build                    # 执行代码生成
flutter pub run build_runner build --delete-conflicting-outputs  # 强制重新生成
flutter pub run build_runner watch                    # 监听模式生成代码
```

### 构建命令
```bash
flutter build apk            # 构建Android APK
flutter build appbundle     # 构建Android App Bundle
flutter build ios           # 构建iOS应用
```

### 测试命令
```bash
flutter test                 # 运行单元测试和组件测试
flutter test --coverage     # 运行测试并生成覆盖率报告
flutter integration_test    # 运行集成测试
```

### 清理命令
```bash
flutter clean               # 清理构建缓存
flutter pub cache repair    # 修复pub缓存
```

## Git 命令
```bash
git status                  # 查看状态
git add .                   # 添加所有更改
git commit -m "feat: 描述"   # 提交更改（遵循Conventional Commits）
git push                    # 推送到远程
```

## 系统命令 (macOS)
```bash
ls -la                      # 列出文件（包含隐藏文件）
find . -name "*.dart"       # 查找Dart文件
grep -r "pattern" lib/      # 在lib目录中搜索模式
cd path/to/directory        # 切换目录
```

## 重要提醒
- **每次代码修改后必须执行 `flutter analyze`**
- **禁止执行 `flutter run`**
- 涉及代码生成时，先运行 build_runner
- 提交信息遵循 Conventional Commits 格式