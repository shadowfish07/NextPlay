---
name: flutter-add-integration-test
description: Configures Flutter Driver for app interaction and converts MCP actions into permanent integration tests. Use when adding integration testing to a project, exploring UI components via MCP, or automating user flows with the integration_test package.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 18:29:20 GMT
---
# Implementing Flutter Integration Tests

## Contents
- [Project Setup and Dependencies](#project-setup-and-dependencies)
- [Interactive Exploration via MCP](#interactive-exploration-via-mcp)
- [Test Authoring Guidelines](#test-authoring-guidelines)
- [Execution and Profiling](#execution-and-profiling)
- [Workflow: End-to-End Integration Testing](#workflow-end-to-end-integration-testing)
- [Examples](#examples)

## Project Setup and Dependencies

Configure the project to support modern `integration_test` tests. Do not enable
the legacy Flutter Driver VM service extension in a production entry point.

1. Add required development dependencies to `pubspec.yaml`:
   ```bash
   flutter pub add 'dev:integration_test:{"sdk":"flutter"}'
   flutter pub add 'dev:flutter_test:{"sdk":"flutter"}'
   ```
   If the project keeps the optional performance driver example from this
   skill, also declare its direct SDK dependency:
   ```bash
   flutter pub add 'dev:flutter_driver:{"sdk":"flutter"}'
   ```
2. Reuse the app's existing entry point and inject deterministic dependencies
   through `AppDependencies.create()` when a test needs fakes. Never select
   fixtures from production `main()`.
3. Define or reuse automation-facing selectors in
   `lib/ui/core/app_keys.dart`, then pass those `AppKeys` members to widgets.
   Existing key strings are compatibility contracts; do not create parallel
   inline `ValueKey` strings in tests.

## Interactive Exploration via MCP

Use the Dart/Flutter MCP server tools to interactively explore and manipulate the application state before writing static tests.

- **Launch**: Execute `launch_app` with the existing `lib/main.dart` target. Use
  a dedicated target only after creating it and wiring test-only dependencies
  without changing production composition.
- **Inspect**: Execute `get_widget_tree` to discover available `Key`s, `Text` nodes, and widget `Type`s.
- **Interact**: Execute `tap`, `enter_text`, and `scroll` to simulate user flows.
- **Wait**: Always execute `waitFor` or verify state with `get_health` when navigating or triggering animations.
- **Troubleshoot Unmounted Widgets**: If a widget is not found in the tree, it may be lazily loaded in a `SliverList` or `ListView`. Execute `scroll` or `scrollIntoView` to force the widget to mount before interacting with it.

## Test Authoring Guidelines

Structure integration tests using the `flutter_test` API paradigm.

- Create a dedicated `integration_test/` directory at the project root.
- Name all test files using the `<name>_test.dart` convention.
- Initialize the binding by calling `IntegrationTestWidgetsFlutterBinding.ensureInitialized();` at the start of `main()`.
- Load the application UI using `await tester.pumpWidget(MyApp());`.
- Trigger frames and wait for animations to complete using `await tester.pumpAndSettle();` after interactions like `tester.tap()`.
- Assert widget visibility using stable selectors such as
  `expect(find.byKey(AppKeys.onboardingNext), findsOneWidget);` or
  `findsNothing`.
- Scroll to specific off-screen widgets using `await tester.scrollUntilVisible(itemFinder, 500.0, scrollable: listFinder);`.

**Conditional Logic for Legacy `flutter_driver`:**
- Modern `integration_test` tests do not call
  `enableFlutterDriverExtension()`.
- If maintaining a genuine legacy `flutter_driver` suite, add the
  `flutter_driver` SDK dependency and use a dedicated entry point that is never
  imported by production `main()`.
- Gate the extension in that legacy-only entry point with an explicit
  `--dart-define=ENABLE_FLUTTER_DRIVER=true`; release builds must never enable
  it.

## Execution and Profiling

Use the repository-owned runner for Android. A host driver script at
`test_driver/integration_test.dart` that calls `integrationDriver()` is only
needed for targets or reporting workflows that explicitly use `flutter drive`.

**Conditional Execution Targets:**
- **If testing on Chrome:** Launch `chromedriver --port=4444` in a separate terminal, then run:
  `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d chrome`
- **If testing headless web:** Run with `-d web-server`.
- **If testing NextPlay on Android (Local):** Run `tool/e2e_android.sh`. In a
  linked worktree, `tool/worktree.sh e2e` also performs setup first. Both paths
  use the repository's shared AVD lease and scoped cleanup.
- **If testing on Firebase Test Lab (Android):**
  1. Build debug APK: `flutter build apk --debug`
  2. Confirm `android/gradlew` and its wrapper JAR are present, then build the
     test APK with `(cd android && ./gradlew app:assembleAndroidTest)`.
  3. Upload both APKs to the Firebase Test Lab console.

## Workflow: End-to-End Integration Testing

Copy and follow this checklist to implement and verify integration tests.

- [ ] **Task Progress: Setup**
  - [ ] Add `integration_test` and `flutter_test` to `pubspec.yaml`.
  - [ ] Inject deterministic dependencies through `AppDependencies.create()`.
  - [ ] Assign or reuse `AppKeys` members for target widgets.
- [ ] **Task Progress: Exploration**
  - [ ] Run `launch_app` via MCP.
  - [ ] Map the widget tree using `get_widget_tree`.
  - [ ] Validate interaction paths using MCP tools (`tap`, `enter_text`).
- [ ] **Task Progress: Authoring**
  - [ ] Create `integration_test/app_test.dart`.
  - [ ] Write test cases using `WidgetTester` APIs.
  - [ ] Create a host driver only when the selected target requires one.
- [ ] **Task Progress: Execution & Feedback Loop**
  - [ ] Run `tool/verify_fast.sh`, then use `tool/e2e_android.sh` for Android.
  - [ ] **Feedback Loop**: Review test output -> If `PumpAndSettleTimedOutException` occurs, check for infinite animations -> If widget not found, add `scrollUntilVisible` -> Re-run test until passing.

## Examples

### Standard Integration Test (`integration_test/app_test.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/ui/core/app_keys.dart';
import 'package:my_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end test', () {
    testWidgets('advance through onboarding', (tester) async {
      // Load app widget.
      await tester.pumpWidget(const MyApp());

      // Use selectors defined by the application, not copied key strings.
      final nextButton = find.byKey(AppKeys.onboardingNext);
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);

      // Trigger a frame and wait for animations.
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.onboardingPrevious), findsOneWidget);
    });
  });
}
```

### Host Driver Script (`test_driver/integration_test.dart`)

```dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
```

### Performance Profiling Driver Script (`test_driver/perf_driver.dart`)

Use this driver script if you wrap your test actions in `binding.traceAction()` to capture performance metrics.

```dart
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data != null) {
        final timeline = driver.Timeline.fromJson(
          data['scrolling_timeline'] as Map<String, dynamic>,
        );

        final summary = driver.TimelineSummary.summarize(timeline);

        await summary.writeTimelineToFile(
          'scrolling_timeline',
          pretty: true,
          includeSummary: true,
        );
      }
    },
  );
}
```
