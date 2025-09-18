# NextPlay 任务完成检查清单

## 代码修改后必须执行的步骤

### 1. 静态代码分析（强制要求）
```bash
flutter analyze
```
- **必须通过，不能有任何错误或警告**
- 这是项目的硬性约束，禁止跳过

### 2. 代码生成（如果涉及）
如果修改了使用以下注解的代码，需要运行：
- `@freezed` - 不可变类
- `@JsonSerializable` - JSON序列化
- `@injectable` - 依赖注入（如使用）

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. 运行测试（推荐）
```bash
flutter test                 # 单元测试和组件测试
flutter test --coverage     # 带覆盖率的测试
```

### 4. 构建检查（可选）
```bash
flutter build apk --debug   # 检查Android构建是否正常
```

## 不允许的操作
- **禁止执行 `flutter run`**（项目硬性约束）
- 禁止硬编码颜色、字号、边距等样式
- 禁止跳过 `flutter analyze` 检查

## 提交前检查
1. 所有修改的代码已通过 `flutter analyze`
2. 相关测试已通过
3. 提交信息遵循 Conventional Commits 格式
4. 如有PR需求，使用github issue关联语法

## 错误处理
如果 `flutter analyze` 失败：
1. 仔细阅读错误信息
2. 修复所有提示的问题
3. 重新运行 `flutter analyze` 确认通过
4. 不允许忽略或跳过任何分析错误