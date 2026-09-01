---
name: dart-collect-coverage
description: Collect coverage using the coverage package and create an LCOV report
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:14:32 GMT
---
# Implementing Dart and Flutter Test Coverage

## Contents
- [Testing Fundamentals](#testing-fundamentals)
- [Coverage Directives](#coverage-directives)
- [Workflow: Configuring and Generating Coverage Reports](#workflow-configuring-and-generating-coverage-reports)
- [Workflow: Advanced Manual Coverage Collection](#workflow-advanced-manual-coverage-collection)
- [Examples](#examples)

## Testing Fundamentals

Structure your test suites using the standard Dart testing paradigms. Use `package:test` for Dart projects and `flutter_test` for Flutter projects.

- **Unit Tests:** Verify individual functions, methods, or classes.
- **Component/Widget Tests:** Verify component behavior, layout, and interaction using mock objects (`package:mockito`).
- **Integration Tests:** Verify entire app flows on simulated or real devices.

## Repository-Owned Coverage Gates Take Precedence

Before adding dependencies or choosing a coverage command, inspect the repository instructions and top-level verification scripts. Use a repository-owned gate when it exists because it may own dependency resolution, the correct Dart or Flutter test runner, LCOV generation, exclusions, and the required coverage threshold.

In NextPlay, run this from the repository root:

```bash
tool/verify_fast.sh
```

Do not replace this with `dart run coverage:test_with_coverage`. NextPlay's gate runs the Flutter test suite with coverage and enforces the repository threshold. A successful coverage check requires the gate to exit successfully; the mere presence of LCOV files is not sufficient.

## Coverage Directives

Exclude specific lines, blocks, or entire files from coverage metrics using inline comments. Pass the `--check-ignore` flag during formatting to enforce these directives.

- Ignore a single line: `// coverage:ignore-line`
- Ignore a block of code: `// coverage:ignore-start` and `// coverage:ignore-end`
- Ignore an entire file: `// coverage:ignore-file`

## Workflow: Configuring and Generating Coverage Reports

Follow the branch that matches the project after checking for a repository-owned gate.

**Task Progress Checklist:**
- [ ] 1. Use the repository-owned coverage gate when one exists.
- [ ] 2. Otherwise select the Dart or Flutter coverage command.
- [ ] 3. Validate LCOV output and any configured threshold.

### 1. Add Dependencies
For a standalone Dart project without an existing coverage gate, add the `coverage` package as a `dev_dependency`. Do not add it to standard dependencies.

```bash
dart pub add dev:coverage
```

Flutter's `flutter test --coverage` already provides the normal Flutter coverage path. Do not add a direct `coverage` dependency unless the project's own tooling explicitly uses the package APIs or executables.

### 2. Collect Coverage and Generate LCOV
For a standalone Dart project, use the bundled `test_with_coverage` script. It runs Dart tests, collects VM coverage data, and formats it into LCOV:

```bash
dart run coverage:test_with_coverage
```
*Note: If working within a Dart workspace (monorepo), specify the test directories explicitly (e.g., `dart run coverage:test_with_coverage -- pkgs/foo/test pkgs/bar/test`).*

For a standalone Flutter project without a repository-owned gate, use Flutter's test runner:

```bash
flutter test --coverage
```

### 3. Feedback Loop: Validate Output
**Run validator -> review errors -> fix:**
1. Require the repository-owned gate to exit successfully when one exists.
2. Otherwise verify that `coverage/lcov.info` was created in the project root. Dart's `test_with_coverage` also creates `coverage/coverage.json`; Flutter coverage does not require that intermediate file.
3. Run the project's configured threshold checker, if any. Do not infer threshold compliance from file existence alone.
4. If coverage is missing for specific files, ensure they are imported and executed by your test files, or add `// coverage:ignore-file` only when the repository policy permits the exclusion.

## Workflow: Advanced Manual Coverage Collection

This is a Dart-only fallback for projects without a repository-owned gate. If you require granular control over the VM service, isolate pausing, or need branch/function-level coverage, use the manual collection workflow. Do not use it as a replacement for NextPlay's gate or Flutter's test runner.

**Task Progress Checklist:**
- [ ] 1. Run tests with VM service enabled.
- [ ] 2. Collect raw JSON coverage.
- [ ] 3. Format JSON to LCOV.

### 1. Run Tests with VM Service
Execute tests while pausing isolates on exit and exposing the VM service on a specific port (e.g., 8181).

```bash
dart run --pause-isolates-on-exit --disable-service-auth-codes --enable-vm-service=8181 test &
```

### 2. Collect Raw Coverage
Extract the coverage data from the running VM service and output it to a JSON file.

```bash
dart run coverage:collect_coverage --wait-paused --uri=http://127.0.0.1:8181/ -o coverage/coverage.json --resume-isolates
```
*Optional: Append `--function-coverage` and `--branch-coverage` to gather deeper metrics (requires Dart VM 2.17.0+).*

### 3. Format to LCOV
Convert the raw JSON data into the standard LCOV format.

```bash
dart run coverage:format_coverage --packages=.dart_tool/package_config.json --lcov -i coverage/coverage.json -o coverage/lcov.info --check-ignore
```

## Examples

### Example: `pubspec.yaml` Configuration
Ensure your `pubspec.yaml` reflects the `coverage` package strictly under `dev_dependencies`.

```yaml
name: my_dart_app
environment:
  sdk: ^3.0.0

dependencies:
  path: ^1.8.0

dev_dependencies:
  test: ^1.24.0
  coverage: ^1.15.0
```

### Example: Applying Ignore Directives
Use ignore directives to prevent generated code or untestable edge cases from lowering coverage scores.

```dart
// coverage:ignore-file
import 'package:meta/meta.dart';

class SystemConfig {
  final String env;

  SystemConfig(this.env);

  // coverage:ignore-start
  void legacyInit() {
    print('Deprecated initialization');
  }
  // coverage:ignore-end

  bool isProduction() {
    if (env == 'prod') return true;
    return false; // coverage:ignore-line
  }
}
```
