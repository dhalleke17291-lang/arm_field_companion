import 'dart:convert';
import 'dart:io';

const _reviewRoot = 'assets/reference_guides/lane2a/review_queue';
const _reviewManifestPath =
    'assets/reference_guides/lane2a/review_queue/candidate_review_manifest.json';
const _sourceDataset = 'Dryad Manitoba weed seedling dataset';
const _sourceDoi = '10.5061/dryad.gtht76hhz';
const _sourceUrl = 'https://doi.org/10.5061/dryad.gtht76hhz';
const _authorCreator = 'Beck, Liu, Bidinosti, Henry, Godee, Ajmani';

const _species = <String, Map<String, String>>{
  'wild_oat': {
    'commonName': 'Wild oat',
    'scientificName': 'Avena fatua',
    'category': 'weed_seedling_reference',
  },
  'canada_thistle': {
    'commonName': 'Canada thistle',
    'scientificName': 'Cirsium arvense',
    'category': 'weed_seedling_reference',
  },
  'wild_buckwheat': {
    'commonName': 'Wild buckwheat',
    'scientificName': 'Fallopia convolvulus',
    'category': 'weed_seedling_reference',
  },
  'volunteer_canola': {
    'commonName': 'Volunteer canola',
    'scientificName': 'Brassica napus',
    'category': 'volunteer_crop_as_weed',
  },
  'dandelion': {
    'commonName': 'Dandelion',
    'scientificName': 'Taraxacum officinale',
    'category': 'weed_seedling_reference',
  },
};

void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final command = args.first;
  final flags = _parseFlags(args.skip(1).toList());

  switch (command) {
    case 'init-selection':
      final output = flags['output'] ?? 'lane2a_candidate_selection.json';
      _writeSelectionTemplate(output);
      return;
    case 'copy':
      final selectionPath = flags['selection'];
      final sourceRoot = flags['source'];
      if (selectionPath == null || sourceRoot == null) {
        stderr.writeln('copy requires --selection and --source.');
        exitCode = 64;
        return;
      }
      _copySelectedCandidates(selectionPath, sourceRoot);
      return;
    default:
      stderr.writeln('Unknown command: $command');
      _printUsage();
      exitCode = 64;
  }
}

Map<String, String> _parseFlags(List<String> args) {
  final flags = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      flags[key] = 'true';
    } else {
      flags[key] = args[++i];
    }
  }
  return flags;
}

void _writeSelectionTemplate(String outputPath) {
  final now = DateTime.now().toUtc().toIso8601String().split('T').first;
  final template = {
    'sourceDataset': _sourceDataset,
    'sourceDoi': _sourceDoi,
    'sourceUrl': _sourceUrl,
    'exactLicense': 'CC0',
    'licenseAppliesToImageFile': true,
    'dateObtained': now,
    'dateLastVerified': now,
    'notes':
        'Human-select up to 5 candidates per species. Paths are relative to --source unless absolute.',
    'species': {
      for (final entry in _species.entries)
        entry.key: {
          ...entry.value,
          'candidates': [
            {
              'sourcePath': '',
              'qualityNotes':
                  'Example: sharp top-down seedling, subject about 70% of frame.',
              'subjectLabel': entry.value['commonName'],
              'focalX': 0.5,
              'focalY': 0.5,
              'cropZoom': 1.0,
            }
          ],
        },
    },
  };
  _writeJson(File(outputPath), template);
  stdout.writeln('Wrote selection template: $outputPath');
}

void _copySelectedCandidates(String selectionPath, String sourceRoot) {
  final selectionFile = File(selectionPath);
  if (!selectionFile.existsSync()) {
    throw StateError('Selection file not found: $selectionPath');
  }

  final decoded = jsonDecode(selectionFile.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw StateError('Selection file must contain a JSON object.');
  }

  final dateObtained = _stringValue(decoded['dateObtained']);
  final dateLastVerified = _stringValue(decoded['dateLastVerified']);
  final license = _stringValue(decoded['exactLicense']);
  final licenseApplies = decoded['licenseAppliesToImageFile'] == true;
  if (license.toLowerCase() != 'cc0') {
    throw StateError('Lane 2A Batch 1 requires exactLicense: CC0.');
  }
  if (!licenseApplies) {
    throw StateError('licenseAppliesToImageFile must be true.');
  }
  if (dateObtained.isEmpty || dateLastVerified.isEmpty) {
    throw StateError('dateObtained and dateLastVerified are required.');
  }

  final speciesBlock = decoded['species'];
  if (speciesBlock is! Map<String, Object?>) {
    throw StateError('Selection file must contain a species object.');
  }

  final candidates = <Map<String, Object?>>[];
  final sourceDir = Directory(sourceRoot);
  if (!sourceDir.existsSync()) {
    throw StateError('Source folder not found: $sourceRoot');
  }

  for (final speciesEntry in _species.entries) {
    final speciesCode = speciesEntry.key;
    final metadata = speciesEntry.value;
    final rawSpecies = speciesBlock[speciesCode];
    if (rawSpecies is! Map<String, Object?>) continue;
    final rawCandidates = rawSpecies['candidates'];
    if (rawCandidates is! List) continue;

    final selected = rawCandidates
        .whereType<Map<String, Object?>>()
        .where((candidate) => _stringValue(candidate['sourcePath']).isNotEmpty)
        .toList(growable: false);

    if (selected.length > 5) {
      throw StateError(
          '$speciesCode has ${selected.length} candidates; max 5.');
    }
    if (selected.length < 5) {
      stderr.writeln(
        'Warning: $speciesCode has ${selected.length} candidates; target is 5.',
      );
    }

    for (var i = 0; i < selected.length; i++) {
      final candidate = selected[i];
      final sourcePath = _stringValue(candidate['sourcePath']);
      final sourceFile = _resolveSourceFile(sourceRoot, sourcePath);
      if (!sourceFile.existsSync()) {
        throw StateError('Candidate source file not found: ${sourceFile.path}');
      }

      final extension = _extension(sourceFile.path);
      final candidateId =
          '${speciesCode}_${(i + 1).toString().padLeft(2, '0')}';
      final reviewPath = '$_reviewRoot/$speciesCode/$candidateId$extension';
      final reviewFile = File(reviewPath);
      reviewFile.parent.createSync(recursive: true);
      sourceFile.copySync(reviewFile.path);

      final originalFilename = sourceFile.uri.pathSegments.isEmpty
          ? sourceFile.path
          : sourceFile.uri.pathSegments.last;

      candidates.add({
        'candidateId': candidateId,
        'localReviewPath': reviewPath,
        'speciesCode': speciesCode,
        'commonName': metadata['commonName'],
        'scientificName': metadata['scientificName'],
        'category': metadata['category'],
        'sourceDataset': _sourceDataset,
        'sourceUrl': _sourceUrl,
        'sourceDoi': _sourceDoi,
        'authorCreator': _authorCreator,
        'originalFilename': originalFilename,
        'originalRelativePath': sourcePath,
        'exactLicense': 'CC0',
        'licenseAppliesToImageFile': true,
        'suggestedUse': 'species_reference_photo',
        'qualityNotes': _stringValue(candidate['qualityNotes']),
        'approvalStatus': 'pending',
        'dateObtained': dateObtained,
        'dateLastVerified': dateLastVerified,
        if (_stringValue(candidate['subjectLabel']).isNotEmpty)
          'subjectLabel': _stringValue(candidate['subjectLabel']),
        if (candidate['focalX'] != null) 'focalX': candidate['focalX'],
        if (candidate['focalY'] != null) 'focalY': candidate['focalY'],
        if (candidate['cropZoom'] != null) 'cropZoom': candidate['cropZoom'],
      });
    }
  }

  final manifest = {
    'workflow': 'lane2a_manual_candidate_review',
    'sourceDataset': _sourceDataset,
    'sourceDoi': _sourceDoi,
    'sourceUrl': _sourceUrl,
    'exactLicense': 'CC0',
    'licenseAppliesToImageFile': true,
    'suggestedUse': 'species_reference_photo',
    'candidateTargetPerSpecies': 5,
    'finalApprovalTargetPerSpecies': 3,
    'approvalRule':
        'Only files moved to assets/reference_guides/lane2a/approved/ and listed in lane2a_approved_photo_manifest.dart are seeded.',
    'candidates': candidates,
  };
  _writeJson(File(_reviewManifestPath), manifest);
  stdout.writeln('Copied ${candidates.length} candidates to $_reviewRoot.');
  stdout.writeln('Wrote review manifest: $_reviewManifestPath');
}

File _resolveSourceFile(String sourceRoot, String sourcePath) {
  final file = File(sourcePath);
  if (file.isAbsolute) return file;
  return File('$sourceRoot/$sourcePath');
}

String _extension(String path) {
  final lastSlash = path.lastIndexOf(Platform.pathSeparator);
  final fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return '';
  final ext = fileName.substring(dot).toLowerCase();
  const allowed = {'.jpg', '.jpeg', '.png', '.tif', '.tiff'};
  if (!allowed.contains(ext)) {
    throw StateError('Unsupported image extension: $ext');
  }
  return ext == '.jpeg' ? '.jpg' : ext;
}

String _stringValue(Object? value) => value is String ? value.trim() : '';

void _writeJson(File file, Object value) {
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(value)}\n');
}

void _printUsage() {
  stdout.writeln('''
Lane 2A review queue tool

Commands:
  init-selection --output /tmp/lane2a_selection.json
      Writes a human-editable selection template.

  copy --selection /tmp/lane2a_selection.json --source /path/to/dryad_download
      Copies human-selected candidates into assets/reference_guides/lane2a/review_queue/
      and writes candidate_review_manifest.json.

This tool never writes approved folders and never edits lane2a_approved_photo_manifest.dart.
''');
}
