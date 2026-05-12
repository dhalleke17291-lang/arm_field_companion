import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/database/app_database.dart'
    show AssessmentGuideAnchor, Photo;
import '../../../core/design/app_design_tokens.dart';
import '../../../data/repositories/assessment_guide_repository.dart';
import '../../photos/photo_repository.dart';

typedef ReferencePhotoCaptureCallback = Future<bool> Function(
  BuildContext context,
);

typedef ReferencePhotoRemoveCallback = Future<bool> Function(
  BuildContext context,
  int photoId,
);

/// Opens the rating reference guide overlay for [trialAssessmentId].
/// Writes one GLP view-event record on open (not on close).
/// Returns immediately — no rating value is written.
Future<void> showAssessmentReferenceGuide(
  BuildContext context, {
  required int trialId,
  required int plotPk,
  required int assessmentId,
  required int trialAssessmentId,
  required int? assessmentDefinitionId,
  required int sessionId,
  required int? raterUserId,
  required AssessmentGuideRepository repo,
  required PhotoRepository photoRepository,
  ReferencePhotoCaptureCallback? onCapturePhoto,
  ReferencePhotoRemoveCallback? onRemovePhoto,
}) async {
  final selection = await showModalBottomSheet<ReferenceExampleViewModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppDesignTokens.transparent,
    builder: (_) => _ReferenceGuideSheet(
      key: UniqueKey(),
      trialId: trialId,
      plotPk: plotPk,
      assessmentId: assessmentId,
      trialAssessmentId: trialAssessmentId,
      assessmentDefinitionId: assessmentDefinitionId,
      sessionId: sessionId,
      raterUserId: raterUserId,
      repo: repo,
      photoRepository: photoRepository,
      onCapturePhoto: onCapturePhoto,
      onRemovePhoto: onRemovePhoto,
    ),
  );

  if (selection != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reference selected. Rating is unchanged.'),
      ),
    );
  }
}

/// Suppress the unawaited warning for the fire-and-forget audit write.
void unawaited(Future<void> future) {}

class _ReferenceGuideSheet extends StatefulWidget {
  const _ReferenceGuideSheet({
    super.key,
    required this.trialId,
    required this.plotPk,
    required this.assessmentId,
    required this.trialAssessmentId,
    required this.assessmentDefinitionId,
    required this.sessionId,
    required this.raterUserId,
    required this.repo,
    required this.photoRepository,
    this.onCapturePhoto,
    this.onRemovePhoto,
  });

  final int trialId;
  final int plotPk;
  final int assessmentId;
  final int trialAssessmentId;
  final int? assessmentDefinitionId;
  final int sessionId;
  final int? raterUserId;
  final AssessmentGuideRepository repo;
  final PhotoRepository photoRepository;
  final ReferencePhotoCaptureCallback? onCapturePhoto;
  final ReferencePhotoRemoveCallback? onRemovePhoto;

  @override
  State<_ReferenceGuideSheet> createState() => _ReferenceGuideSheetState();
}

class _ReferenceGuideSheetState extends State<_ReferenceGuideSheet> {
  late Future<ReferenceComparatorData> _dataFuture;
  bool _showEmptyPhotoPanel = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData(recordViewEvent: true);
  }

  Future<ReferenceComparatorData> _loadData({
    required bool recordViewEvent,
  }) async {
    return loadReferenceComparatorData(
      trialId: widget.trialId,
      plotPk: widget.plotPk,
      assessmentId: widget.assessmentId,
      trialAssessmentId: widget.trialAssessmentId,
      assessmentDefinitionId: widget.assessmentDefinitionId,
      sessionId: widget.sessionId,
      raterUserId: widget.raterUserId,
      repo: widget.repo,
      photoRepository: widget.photoRepository,
      recordViewEvent: recordViewEvent,
      showEmptyPhotoPanel: _showEmptyPhotoPanel,
    );
  }

  Future<void> _handleCapturePhoto(BuildContext context) async {
    final capture = widget.onCapturePhoto;
    if (capture == null) return;

    final saved = await capture(context);
    if (!mounted || !saved) return;

    setState(() {
      _showEmptyPhotoPanel = false;
      _dataFuture = _loadData(recordViewEvent: false);
    });
  }

  Future<void> _handleRemovePhoto(BuildContext context, int photoId) async {
    final remove = widget.onRemovePhoto;
    if (remove == null) return;

    final removed = await remove(context, photoId);
    if (!mounted || !removed) return;

    setState(() {
      _showEmptyPhotoPanel = true;
      _dataFuture = _loadData(recordViewEvent: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDesignTokens.radiusLarge),
            ),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(context),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                child: FutureBuilder<ReferenceComparatorData>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }
                    if (snapshot.hasError) {
                      debugPrint(
                          'Reference guide load error: ${snapshot.error}');
                      return _messageBody(
                        'Reference guide error: ${snapshot.error}',
                      );
                    }
                    final data = snapshot.data ??
                        const ReferenceComparatorData(
                          currentPhotoId: null,
                          currentPhotoPath: null,
                          showCalibrationFallbackNotice: false,
                          references: [],
                        );
                    return ReferenceGuideComparator(
                      data: data,
                      sheetScrollController: scrollCtrl,
                      onCapturePhoto: widget.onCapturePhoto == null
                          ? null
                          : () => _handleCapturePhoto(context),
                      onRemovePhoto: widget.onRemovePhoto == null ||
                              data.currentPhotoId == null
                          ? null
                          : () => _handleRemovePhoto(
                                context,
                                data.currentPhotoId!,
                              ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppDesignTokens.dragHandle,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          const Icon(
            Icons.compare_outlined,
            size: 18,
            color: AppDesignTokens.primary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Reference comparator',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              foregroundColor: AppDesignTokens.secondaryText,
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBody(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppDesignTokens.secondaryText,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class ReferenceComparatorData {
  const ReferenceComparatorData({
    this.currentPhotoId,
    required this.currentPhotoPath,
    required this.showCalibrationFallbackNotice,
    required this.references,
  });

  final int? currentPhotoId;
  final String? currentPhotoPath;
  final bool showCalibrationFallbackNotice;
  final List<ReferenceExampleViewModel> references;
}

@visibleForTesting
Future<ReferenceComparatorData> loadReferenceComparatorData({
  required int trialId,
  required int plotPk,
  required int assessmentId,
  required int trialAssessmentId,
  required int? assessmentDefinitionId,
  required int sessionId,
  required int? raterUserId,
  required AssessmentGuideRepository repo,
  required PhotoRepository photoRepository,
  required bool recordViewEvent,
  bool showEmptyPhotoPanel = false,
}) async {
  final resolved = await repo.resolveGuideForDisplay(
    trialAssessmentId: trialAssessmentId,
    assessmentDefinitionId: assessmentDefinitionId,
  );

  if (resolved != null && recordViewEvent) {
    // GLP audit — one record after content resolves for this sheet instance.
    unawaited(repo.recordViewEvent(
      guideId: resolved.guide.id,
      trialAssessmentId: trialAssessmentId,
      sessionId: sessionId,
      raterUserId: raterUserId,
    ));
  }

  final currentPhoto = showEmptyPhotoPanel
      ? null
      : await _currentComparisonPhoto(
          photoRepository: photoRepository,
          trialId: trialId,
          plotPk: plotPk,
          sessionId: sessionId,
          assessmentId: assessmentId,
        );
  final currentPhotoPath = currentPhoto == null
      ? null
      : await PhotoRepository.resolvePhotoPath(currentPhoto.filePath);

  return ReferenceComparatorData(
    currentPhotoId: currentPhoto?.id,
    currentPhotoPath: currentPhotoPath,
    showCalibrationFallbackNotice: resolved != null &&
        resolved.anchors.isNotEmpty &&
        resolved.anchors.every((a) => a.lane == 'calibration_diagram'),
    references: resolved == null
        ? const []
        : resolved.anchors
            .map(ReferenceExampleViewModel.fromAnchor)
            .toList(growable: false),
  );
}

Future<Photo?> _currentComparisonPhoto({
  required PhotoRepository photoRepository,
  required int trialId,
  required int plotPk,
  required int sessionId,
  required int assessmentId,
}) async {
  final photos = await photoRepository.getPhotosForPlotInSession(
    trialId: trialId,
    plotPk: plotPk,
    sessionId: sessionId,
  );
  if (photos.isEmpty) return null;

  final assessmentPhotos =
      photos.where((p) => p.assessmentId == assessmentId).toList();
  final candidates = assessmentPhotos.isNotEmpty ? assessmentPhotos : photos;
  candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return candidates.first;
}

class ReferenceExampleViewModel {
  const ReferenceExampleViewModel({
    required this.displayPath,
    required this.label,
    required this.selectedBadgeLabel,
    required this.description,
    required this.sourceText,
    required this.isPendingValidation,
    this.laneSourceLabel,
    this.focalX,
    this.focalY,
    this.cropZoom,
    this.subjectLabel,
  });

  final String? displayPath;
  final String label;
  final String selectedBadgeLabel;
  final String description;
  final String sourceText;
  final bool isPendingValidation;

  /// Shown on Lane 2 and Lane 3 cards always (not amber — neutral grey).
  /// null for Lane 1 (which uses isPendingValidation / no badge instead).
  final String? laneSourceLabel;

  final double? focalX;
  final double? focalY;
  final double? cropZoom;
  final String? subjectLabel;

  factory ReferenceExampleViewModel.fromAnchor(AssessmentGuideAnchor anchor) {
    final spec = _decodeSpec(anchor.generationSpecification);
    final scaleLabel = _scaleLabel(spec);
    final subjectLabel = _stringValue(spec['subjectLabel']);
    final lane2ALabel = _lane2AReferenceLabel(spec);
    final description = _descriptionFor(anchor, spec);
    final sourceParts = <String>[
      if (anchor.attributionString.trim().isNotEmpty)
        anchor.attributionString.trim(),
      if (anchor.licenseIdentifier != null &&
          anchor.licenseIdentifier!.trim().isNotEmpty)
        'License: ${anchor.licenseIdentifier!.trim()}',
      if (anchor.citationFull != null && anchor.citationFull!.trim().isNotEmpty)
        'Citation: ${anchor.citationFull!.trim()}',
    ];

    return ReferenceExampleViewModel(
      displayPath: anchor.filePath ?? anchor.sourceUrl,
      label:
          lane2ALabel ?? subjectLabel ?? scaleLabel ?? _fallbackLabel(anchor),
      selectedBadgeLabel: _selectedBadgeLabel(anchor.lane),
      description: description,
      sourceText: sourceParts.join('\n'),
      isPendingValidation:
          anchor.lane == 'calibration_diagram' && anchor.validatedBy == null,
      laneSourceLabel: _laneSourceLabel(anchor.lane),
      focalX: _doubleValue(spec['focalX']),
      focalY: _doubleValue(spec['focalY']),
      cropZoom: _doubleValue(spec['cropZoom']),
      subjectLabel: subjectLabel,
    );
  }

  static Map<String, dynamic> _decodeSpec(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  static String? _scaleLabel(Map<String, dynamic> spec) {
    final values = spec['scale_values'];
    if (values is! List || values.isEmpty) return null;
    final unit = _unitFor(spec);
    return values.map((v) => '$v$unit').join(' / ');
  }

  static String _unitFor(Map<String, dynamic> spec) {
    final type = _stringValue(spec['assessment_type']) ?? '';
    if (type.contains('score') || type.contains('injury')) return '';
    if (type.contains('cover') || type.contains('severity')) return '%';
    return '';
  }

  static String _descriptionFor(
    AssessmentGuideAnchor anchor,
    Map<String, dynamic> spec,
  ) {
    final type = _stringValue(spec['assessment_type']);
    final visual = _stringValue(spec['visual']);
    final description = _stringValue(spec['description']);
    if (anchor.lane == 'customer_upload') {
      return 'Customer-uploaded reference image for visual comparison.';
    }
    if (description != null) return description;
    if (_stringValue(spec['lane']) == 'lane_2a') {
      final category = _stringValue(spec['categoryLabel']);
      final commonName = _stringValue(spec['commonName']);
      final scientificName = _stringValue(spec['speciesScientificName']);
      final note = _stringValue(spec['shortReferenceNote']);
      final subject = [
        commonName,
        if (scientificName != null) '($scientificName)',
      ].whereType<String>().join(' ');
      if (note != null) {
        return 'Focused reference view: $note';
      }
      final parts = [
        'Focused reference view',
        if (category != null) category.toLowerCase(),
        if (subject.trim().isNotEmpty) subject,
      ];
      return '${parts.join(': ')}.';
    }
    if (type == 'weed_cover') {
      return 'Focused reference view: weed cover overhead quadrat reference. Absolute canopy/ground occupancy.';
    }
    if (type != null || visual != null) {
      final text = [type, visual]
          .whereType<String>()
          .map((v) => v.replaceAll('_', ' '))
          .join(' - ');
      return 'Focused reference view: $text.';
    }
    return 'Focused reference view for visual comparison.';
  }

  static String _fallbackLabel(AssessmentGuideAnchor anchor) {
    final path = anchor.filePath ?? anchor.sourceUrl ?? 'Reference example';
    final name = path.split('/').last.replaceAll('_', ' ');
    return name
        .replaceAll('.svg', '')
        .replaceAll('.jpg', '')
        .replaceAll('.png', '');
  }

  static String _selectedBadgeLabel(String lane) {
    switch (lane) {
      case 'calibration_diagram':
        return 'Calibration reference';
      case 'identification_photo':
        return 'Closest visual match';
      case 'customer_upload':
        return 'Customer reference';
      default:
        return 'Reference selected';
    }
  }

  static String? _stringValue(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _lane2AReferenceLabel(Map<String, dynamic> spec) {
    if (_stringValue(spec['lane']) != 'lane_2a') return null;
    final commonName = _stringValue(spec['commonName']);
    final category = _stringValue(spec['categoryLabel']);
    if (commonName != null && category != null) {
      return '$commonName - $category';
    }
    return commonName ?? category;
  }

  static double? _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _laneSourceLabel(String lane) {
    switch (lane) {
      case 'identification_photo':
        return 'Reference photo';
      case 'customer_upload':
        return 'Customer upload';
      default:
        return null;
    }
  }
}

class ReferenceGuideComparator extends StatefulWidget {
  const ReferenceGuideComparator({
    super.key,
    required this.data,
    this.sheetScrollController,
    this.onCapturePhoto,
    this.onRemovePhoto,
  });

  final ReferenceComparatorData data;
  final ScrollController? sheetScrollController;
  final Future<void> Function()? onCapturePhoto;
  final Future<void> Function()? onRemovePhoto;

  @override
  State<ReferenceGuideComparator> createState() =>
      _ReferenceGuideComparatorState();
}

class _ReferenceGuideComparatorState extends State<ReferenceGuideComparator> {
  ReferenceExampleViewModel? _selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            key: const Key('referenceComparatorWideLayout'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.44,
                child: _CurrentPhotoPane(
                  photoPath: widget.data.currentPhotoPath,
                  isWide: true,
                  onCapturePhoto: widget.onCapturePhoto,
                  onRemovePhoto: widget.onRemovePhoto,
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: _referenceList()),
            ],
          );
        }

        return Column(
          key: const Key('referenceComparatorNarrowLayout'),
          children: [
            SizedBox(
              height: constraints.maxHeight * 0.42,
              child: _CurrentPhotoPane(
                photoPath: widget.data.currentPhotoPath,
                isWide: false,
                onCapturePhoto: widget.onCapturePhoto,
                onRemovePhoto: widget.onRemovePhoto,
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(child: _referenceList()),
          ],
        );
      },
    );
  }

  Widget _referenceList() {
    if (widget.data.references.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No calibrated reference examples are available for this assessment context.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppDesignTokens.secondaryText,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.data.showCalibrationFallbackNotice)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Approved photo references are not available yet. Showing calibration fallback.',
              style: TextStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
                height: 1.3,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: widget.sheetScrollController,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            itemCount: widget.data.references.length,
            itemBuilder: (context, index) {
              final reference = widget.data.references[index];
              return _ReferenceCard(
                key: Key('referenceCard_$index'),
                reference: reference,
                selected: identical(_selected, reference),
                onTap: () => setState(() => _selected = reference),
              );
            },
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _selected == null
              ? const SizedBox.shrink()
              : _SelectionActionBar(
                  onUse: () => Navigator.pop(context, _selected),
                ),
        ),
      ],
    );
  }
}

class _CurrentPhotoPane extends StatelessWidget {
  const _CurrentPhotoPane({
    required this.photoPath,
    required this.isWide,
    this.onCapturePhoto,
    this.onRemovePhoto,
  });

  final String? photoPath;
  final bool isWide;
  final Future<void> Function()? onCapturePhoto;
  final Future<void> Function()? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppDesignTokens.backgroundSurface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Current field photo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppDesignTokens.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: photoPath == null
                ? _CurrentPhotoFallback(onCapturePhoto: onCapturePhoto)
                : _CurrentPhotoWithActions(
                    displayPath: photoPath,
                    onRetakePhoto: onCapturePhoto,
                    onRemovePhoto: onRemovePhoto,
                  ),
          ),
          if (!isWide) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _CurrentPhotoWithActions extends StatelessWidget {
  const _CurrentPhotoWithActions({
    required this.displayPath,
    this.onRetakePhoto,
    this.onRemovePhoto,
  });

  final String? displayPath;
  final Future<void> Function()? onRetakePhoto;
  final Future<void> Function()? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FocusedReferenceImage(
            displayPath: displayPath,
            fit: BoxFit.cover,
            onTapLabel: 'Open current field photo',
            fullScreenTitle: 'Current field photo',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (onRetakePhoto != null)
              OutlinedButton(
                key: const Key('retakeCurrentPhotoButton'),
                onPressed: onRetakePhoto,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignTokens.primary,
                  side: const BorderSide(color: AppDesignTokens.primary),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Retake photo'),
              ),
            if (onRemovePhoto != null)
              OutlinedButton(
                key: const Key('removeCurrentPhotoButton'),
                onPressed: () => _confirmRemove(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignTokens.missedColor,
                  side: const BorderSide(color: AppDesignTokens.missedColor),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Remove photo'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this comparison photo?'),
        content: const Text(
          'This removes only the current field photo from the comparison. '
          'Reference guide images are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmRemoveCurrentPhotoButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.missedColor,
              foregroundColor: AppDesignTokens.onPrimary,
            ),
            child: const Text('Remove photo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onRemovePhoto?.call();
    }
  }
}

class _CurrentPhotoFallback extends StatelessWidget {
  const _CurrentPhotoFallback({this.onCapturePhoto});

  final Future<void> Function()? onCapturePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('currentPhotoFallback'),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 44,
                color: AppDesignTokens.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Capture field photo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a photo of this plot to compare it with reference examples.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                  height: 1.35,
                ),
              ),
              if (onCapturePhoto != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('captureFieldPhotoButton'),
                  onPressed: onCapturePhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: AppDesignTokens.onPrimary,
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Capture photo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    super.key,
    required this.reference,
    required this.selected,
    required this.onTap,
  });

  final ReferenceExampleViewModel reference;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
              border: Border.all(
                color: selected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.borderCrisp,
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.primaryText,
                      ),
                    ),
                    if (selected ||
                        reference.isPendingValidation ||
                        reference.laneSourceLabel != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (selected)
                            _SelectedReferenceBadge(
                              label: reference.selectedBadgeLabel,
                            ),
                          if (reference.isPendingValidation)
                            const _PendingValidationBadge(),
                          if (reference.laneSourceLabel != null)
                            _LaneSourceLabel(
                              label: reference.laneSourceLabel!,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 210,
                  child: FocusedReferenceImage(
                    displayPath: reference.displayPath,
                    focalX: reference.focalX,
                    focalY: reference.focalY,
                    cropZoom: reference.cropZoom,
                    onTapLabel: 'Open full reference image',
                    fullScreenTitle: reference.subjectLabel ?? reference.label,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reference.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.primaryText,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reference.sourceText,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppDesignTokens.secondaryText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedReferenceBadge extends StatelessWidget {
  const _SelectedReferenceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('closestVisualMatchBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesignTokens.primaryTint,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
        border: Border.all(color: AppDesignTokens.primary),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppDesignTokens.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PendingValidationBadge extends StatelessWidget {
  const _PendingValidationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesignTokens.flagColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
      ),
      child: const Text(
        'Pending validation',
        style: TextStyle(
          fontSize: 10,
          color: AppDesignTokens.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LaneSourceLabel extends StatelessWidget {
  const _LaneSourceLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesignTokens.emptyBadgeBg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusXSmall),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppDesignTokens.secondaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({required this.onUse});

  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('selectionActionBar'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppDesignTokens.cardSurface,
        border: Border(top: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Selection only. The rating is unchanged.',
              style: TextStyle(
                fontSize: 11,
                color: AppDesignTokens.secondaryText,
              ),
            ),
          ),
          FilledButton(
            key: const Key('useThisValueButton'),
            onPressed: onUse,
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.primary,
              foregroundColor: AppDesignTokens.onPrimary,
            ),
            child: const Text('Use this value'),
          ),
        ],
      ),
    );
  }
}

class FocusedReferenceImage extends StatelessWidget {
  const FocusedReferenceImage({
    super.key,
    required this.displayPath,
    this.focalX,
    this.focalY,
    this.cropZoom,
    this.fit = BoxFit.cover,
    required this.onTapLabel,
    required this.fullScreenTitle,
  });

  final String? displayPath;
  final double? focalX;
  final double? focalY;
  final double? cropZoom;
  final BoxFit fit;
  final String onTapLabel;
  final String fullScreenTitle;

  @override
  Widget build(BuildContext context) {
    final child = _imageFor(displayPath, fit);
    return Semantics(
      button: displayPath != null,
      label: onTapLabel,
      child: Material(
        color: AppDesignTokens.emptyBadgeBg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: displayPath == null
              ? null
              : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullImageView(
                        displayPath: displayPath!,
                        title: fullScreenTitle,
                      ),
                    ),
                  ),
          child: ClipRect(
            child: Transform.scale(
              scale: (cropZoom ?? 1.0).clamp(1.0, 3.0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageFor(String? path, BoxFit fit) {
    if (path == null) return const _BrokenImagePlaceholder();
    final alignment = _alignmentFromFocal(focalX, focalY);
    if (path.startsWith('assets/') && path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        fit: fit,
        alignment: alignment,
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => const _BrokenImagePlaceholder(),
      );
    }
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => const _BrokenImagePlaceholder(),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, __, ___) => const _BrokenImagePlaceholder(),
    );
  }

  static Alignment _alignmentFromFocal(double? focalX, double? focalY) {
    final x = focalX == null ? 0.0 : (focalX.clamp(0.0, 1.0) * 2) - 1;
    final y = focalY == null ? 0.0 : (focalY.clamp(0.0, 1.0) * 2) - 1;
    return Alignment(x, y);
  }
}

class FullImageView extends StatelessWidget {
  const FullImageView({
    super.key,
    required this.displayPath,
    required this.title,
  });

  final String displayPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.primaryText,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppDesignTokens.primaryText,
        foregroundColor: AppDesignTokens.onPrimary,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: _fullImage(displayPath),
        ),
      ),
    );
  }

  Widget _fullImage(String path) {
    if (path.startsWith('assets/') && path.endsWith('.svg')) {
      return SvgPicture.asset(path, fit: BoxFit.contain);
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.contain);
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.contain);
    }
    return Image.file(File(path), fit: BoxFit.contain);
  }
}

class _BrokenImagePlaceholder extends StatelessWidget {
  const _BrokenImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppDesignTokens.emptyBadgeBg,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppDesignTokens.secondaryText,
          size: 28,
        ),
      ),
    );
  }
}
