// Enforces the separation rule in docs/ARM_SEPARATION.md at import level.
//
// Code outside the ARM-only folders
//   - lib/features/arm_import/
//   - lib/features/arm_protocol/
//   - lib/data/arm/
//   - lib/domain/arm/
// must not `import` from them.
//
// This prevents ARM-specific types, services, and widgets from leaking into
// core trial flows that standalone users also run. Standalone trials must
// render, persist, and export correctly with zero ARM code involved.
//
// If this test fails:
//   1. Prefer putting the new ARM-only code under an `arm*` folder so the
//      non-ARM import is unnecessary.
//   2. If the non-ARM file genuinely needs the ARM type (e.g. because of a
//      pre-existing ARM field on a core table), consider whether the type
//      itself belongs in core, or whether the call site should move into
//      an ARM feature.
//   3. The allow-list below is for the DI composition root only. Resist
//      growing it; every addition is a future cleanup task.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _armSubtreePrefixes = <String>[
  'lib/features/arm_import/',
  'lib/features/arm_protocol/',
  'lib/data/arm/',
  'lib/domain/arm/',
];

// Files allowed to import from ARM subtrees despite living outside them.
// Keep this minimal — see doc comment above.
//
// Phase 0b cleanup candidates (export/): every entry below is a known
// grandfathered leak that Phase 0b will resolve by either (a) moving the
// ARM-specific usecase into an `arm*` subtree, or (b) routing the ARM
// import metadata through a core-level abstraction that doesn't require
// the export feature to know ARM internals. Do not add new entries.
const _allowList = <String>{
  // Composition root — wires DI graph for every feature, ARM included.
  'lib/core/providers.dart',

  // ARM-only usecases that currently live under features/export/.
  // These should move to lib/features/arm_protocol/ in Phase 0b; they are
  // not used on the standalone path.
  'lib/features/export/domain/export_arm_rating_shell_usecase.dart',
  'lib/features/export/usecases/arm_export_preflight_usecase.dart',
  // Phase 0b-ta additions — both read ARM per-column metadata via the
  // column-mapping repository instead of trial_assessments. Same
  // "ARM usecase under features/export/" category as the two above.
  'lib/features/export/domain/arm_shell_link_usecase.dart',
  'lib/features/export/domain/compute_arm_round_trip_diagnostics_usecase.dart',

  // Generic export usecases that currently reach into ARM persistence for
  // "is this trial ARM-linked?" context. Phase 0b will replace those reads
  // with a core-level accessor so the generic exports stay protocol-agnostic.
  'lib/features/export/export_trial_usecase.dart',
  'lib/features/export/export_trial_pdf_report_usecase.dart',
};

final _importRegex = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

bool _isInArmSubtree(String posixPath) {
  return _armSubtreePrefixes.any(posixPath.startsWith);
}

/// Resolves a Dart `import` target (absolute `package:` or relative) to a
/// canonical `lib/...` path, POSIX-style. Returns null for imports we do not
/// classify (e.g. `dart:`, third-party packages, non-lib relative).
String? _resolveImportToLibPath({
  required String fromLibRelative,
  required String importTarget,
}) {
  const pkg = 'package:arm_field_companion/';
  if (importTarget.startsWith(pkg)) {
    return 'lib/${importTarget.substring(pkg.length)}';
  }

  if (importTarget.startsWith('dart:') || importTarget.startsWith('package:')) {
    return null;
  }

  // Relative import — resolve against the importing file's directory.
  final fromDir = File(fromLibRelative).parent.path; // POSIX-style already
  final parts = <String>[...fromDir.split('/'), ...importTarget.split('/')];
  final resolved = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
      continue;
    }
    resolved.add(part);
  }
  final joined = resolved.join('/');
  return joined.startsWith('lib/') ? joined : null;
}

void main() {
  test('core code must not import from ARM-only subtrees', () async {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'lib/ directory must exist to enforce ARM separation');

    final offenders = <String, List<String>>{};

    final entries = libDir.listSync(recursive: true, followLinks: false);
    for (final entry in entries) {
      if (entry is! File) continue;
      if (!entry.path.endsWith('.dart')) continue;

      // Normalize to POSIX so prefix checks are stable on macOS and Linux.
      final libRelative = entry.path.replaceAll(r'\', '/');

      if (_isInArmSubtree(libRelative)) continue; // ARM → ARM is allowed
      if (_allowList.contains(libRelative)) continue;

      final source = entry.readAsStringSync();
      for (final match in _importRegex.allMatches(source)) {
        final target = match.group(1);
        if (target == null) continue;

        final resolved = _resolveImportToLibPath(
          fromLibRelative: libRelative,
          importTarget: target,
        );
        if (resolved == null) continue;
        if (!_isInArmSubtree(resolved)) continue;

        offenders.putIfAbsent(libRelative, () => []).add(target);
      }
    }

    if (offenders.isEmpty) return;

    final buffer = StringBuffer()
      ..writeln(
          'Found ${offenders.length} core file(s) importing ARM-only modules.')
      ..writeln('See docs/ARM_SEPARATION.md for the separation rule.')
      ..writeln();
    offenders.forEach((file, imports) {
      buffer.writeln('  $file');
      for (final imp in imports) {
        buffer.writeln('    -> $imp');
      }
    });

    fail(buffer.toString());
  });

  test('ARM-separation allow-list references only existing files', () {
    for (final path in _allowList) {
      expect(File(path).existsSync(), isTrue,
          reason:
              'Allow-list entry must exist; remove stale entries: $path');
    }
  });
}
