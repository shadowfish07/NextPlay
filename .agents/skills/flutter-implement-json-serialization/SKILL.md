---
name: flutter-implement-json-serialization
description: Create model classes with `fromJson` and `toJson` methods using `dart:convert`. Use when manually mapping JSON keys to class properties for simple data structures.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 21:44:50 GMT
---
# Serializing JSON Manually in Flutter

## Contents
- [Core Guidelines](#core-guidelines)
- [Workflow: Implementing a Serializable Model](#workflow-implementing-a-serializable-model)
- [Workflow: Fetching and Parsing JSON](#workflow-fetching-and-parsing-json)
- [Examples](#examples)

## Core Guidelines

- **Import `dart:convert`**: Utilize Flutter's built-in `dart:convert` library for manual JSON encoding (`jsonEncode`) and decoding (`jsonDecode`).
- **Enforce Type Safety**: Always cast the `dynamic` result of `jsonDecode()` to the expected type, typically `Map<String, dynamic>` for objects or `List<dynamic>` for arrays.
- **Encapsulate Serialization Logic**: Define plain model classes containing properties corresponding to the JSON structure. Implement a `fromJson` factory constructor and a `toJson` method within the model.
- **Handle Background Parsing**: If parsing large JSON documents (execution
  time > 16ms), use Flutter's `compute()` function. Native platforms run the
  callback in a separate isolate; Flutter Web runs it on the current event loop,
  so large Web payloads can still block the UI and may need a Web-specific
  worker or incremental parsing strategy.
- **Throw Exceptions on Failure**: When handling HTTP responses, accept the full
  `200`–`299` success range, then validate the endpoint's response-body contract
  separately. Do not decode an empty `204 No Content` response, and do not
  return `null` for failures.

## Workflow: Implementing a Serializable Model

Use this checklist to implement manual JSON serialization for a data model.

**Task Progress:**
- [ ] Define the plain model class with `final` properties.
- [ ] Implement the `factory Model.fromJson(Map<String, dynamic> json)` constructor.
- [ ] Implement the `Map<String, dynamic> toJson()` method.
- [ ] Write unit tests for both serialization methods.
- [ ] Run validator -> review type mismatch errors -> fix casting logic.
- [ ] Run `tool/verify_fast.sh`; if the change affects an externally exercised
      IGDB, Steam, or other live-service contract, also run the relevant
      `tool/live_smoke.sh` check.

1. **Define the Model**: Create a class with properties matching the JSON keys.
2. **Implement `fromJson`**: Extract values from the `Map` and cast them to the appropriate Dart types. Use pattern matching or explicit casting.
3. **Implement `toJson`**: Return a `Map<String, dynamic>` mapping the class properties back to their JSON string keys.
4. **Validate**: Execute unit tests, then run `tool/verify_fast.sh` for NextPlay.
   If the serialized shape is an externally exercised IGDB, Steam, or other
   live-service contract, also run the relevant `tool/live_smoke.sh` check.

## Workflow: Fetching and Parsing JSON

Use this conditional workflow when retrieving and parsing JSON from a network request.

**Task Progress:**
- [ ] Execute the HTTP request.
- [ ] Validate the response status code.
- [ ] Determine parsing strategy (Synchronous vs. Isolate).
- [ ] Decode and map the JSON to the model.

1. **Execute Request**: Use the `http` package to perform the network call.
2. **Validate Response**:
   - Treat every status from `200` through `299` as HTTP success.
   - For an endpoint that promises JSON, reject an unexpectedly empty body
     before parsing. For a successful body-free response such as `204`, skip
     decoding and return the endpoint's body-free domain result.
   - For every non-`2xx` status, throw an `Exception`.
3. **Determine Parsing Strategy**:
   - If parsing a **small payload** (e.g., a single object), parse synchronously on the main thread.
   - If parsing a **large payload** (e.g., an array of thousands of objects),
     use `compute(parseFunction, response.body)` with the native/Web platform
     behavior described above.
4. **Decode and Map**: Pass the decoded JSON to your model's `fromJson` constructor.

## Examples

### High-Fidelity Model Implementation

```dart
import 'dart:convert';

class User {
  final int id;
  final String name;
  final String email;

  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  // Factory constructor for deserialization
  factory User.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': int id,
        'name': String name,
        'email': String email,
      } =>
        User(
          id: id,
          name: name,
          email: email,
        ),
      _ => throw const FormatException('Failed to load User.'),
    };
  }

  // Method for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}
```

### Synchronous Parsing (Small Payload)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<User> fetchUser(http.Client client, int userId) async {
  final response = await client.get(
    Uri.parse('https://api.example.com/users/$userId'),
    headers: {'Accept': 'application/json'},
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to load user');
  }

  if (response.body.trim().isEmpty) {
    throw const FormatException('Expected a response body for user');
  }

  // Decode returns dynamic, cast to Map<String, dynamic>.
  final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
  return User.fromJson(jsonMap);
}
```

### Background Parsing (Large Payload)

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Top-level function required for compute()
List<User> parseUsers(String responseBody) {
  final parsed = (jsonDecode(responseBody) as List<dynamic>).cast<Map<String, dynamic>>();
  return parsed.map<User>((json) => User.fromJson(json)).toList();
}

Future<List<User>> fetchUsers(http.Client client) async {
  final response = await client.get(
    Uri.parse('https://api.example.com/users'),
    headers: {'Accept': 'application/json'},
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to load users');
  }

  if (response.body.trim().isEmpty) {
    throw const FormatException('Expected a response body for users');
  }

  // Native uses a background isolate; Web uses the current event loop.
  return compute(parseUsers, response.body);
}
```
