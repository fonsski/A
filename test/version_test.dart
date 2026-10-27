import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/config.dart';

void main() {
  test('версия в коде совпадает с pubspec.yaml и CHANGELOG.md', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'version: X.Y.Z+N в pubspec.yaml');
    expect(AppConfig.version, match!.group(1));

    final changelog = File('CHANGELOG.md').readAsStringSync();
    expect(changelog, contains('## [${AppConfig.version}]'));
  });
}
