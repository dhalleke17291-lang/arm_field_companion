import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/providers.dart';

/// Bottom sheet for trial coordinators to manage Lane 3 (customer-uploaded)
/// reference guide images for a single trial assessment.
///
/// Entry point: assessments tab → assessment card → "Reference guide" action.
/// Not visible during rating — rating screen shows the viewing overlay only.
Future<void> showCustomerGuideManagementSheet(
  BuildContext context,
  WidgetRef ref, {
  required TrialAssessment ta,
  required String assessmentLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomerGuideSheet(
      ta: ta,
      assessmentLabel: assessmentLabel,
      ref: ref,
    ),
  );
}

class _CustomerGuideSheet extends ConsumerStatefulWidget {
  const _CustomerGuideSheet({
    required this.ta,
    required this.assessmentLabel,
    required this.ref,
  });

  final TrialAssessment ta;
  final String assessmentLabel;
  // Outer ref passed in so the sheet can call repository methods that need
  // the same Riverpod graph without re-watching providers on every rebuild.
  final WidgetRef ref;

  @override
  ConsumerState<_CustomerGuideSheet> createState() =>
      _CustomerGuideSheetState();
}

class _CustomerGuideSheetState extends ConsumerState<_CustomerGuideSheet> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final anchorsAsync = ref.watch(
      customerAnchorsForTrialAssessmentProvider(widget.ta.id),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppDesignTokens.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                child: anchorsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: const TextStyle(fontSize: 13))),
                  data: (anchors) => _buildContent(ctx, scrollCtrl, anchors),
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
            color: AppDesignTokens.borderCrisp,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reference guide images',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppDesignTokens.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.assessmentLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (_uploading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add image'),
              style: TextButton.styleFrom(
                foregroundColor: AppDesignTokens.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext ctx,
    ScrollController scrollCtrl,
    List<AssessmentGuideAnchor> anchors,
  ) {
    if (anchors.isEmpty) {
      return _buildEmptyState(ctx);
    }
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: anchors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildAnchorTile(anchors[i]),
    );
  }

  Widget _buildEmptyState(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 40,
              color: AppDesignTokens.secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No reference images yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add calibration or identification photos that raters can view while rating this assessment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppDesignTokens.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add first image'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnchorTile(AssessmentGuideAnchor anchor) {
    final filePath = anchor.filePath;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignTokens.borderCrisp),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(7)),
            child: filePath != null && File(filePath).existsSync()
                ? Image.file(
                    File(filePath),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 72,
                    height: 72,
                    color: AppDesignTokens.backgroundSurface,
                    child: const Icon(Icons.broken_image_outlined,
                        size: 28, color: AppDesignTokens.secondaryText),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anchor.attributionString,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignTokens.secondaryText,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Added ${anchor.dateObtained}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _confirmDelete(anchor),
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Remove image',
            style: IconButton.styleFrom(
              foregroundColor: AppDesignTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    if (!mounted) return;
    final attribution = await _showAttributionDialog();
    if (attribution == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref
          .read(assessmentGuideRepositoryProvider)
          .addCustomerImage(
            trialAssessmentId: widget.ta.id,
            tempPath: picked.path,
            attributionString: attribution,
          );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _showAttributionDialog() async {
    final controller = TextEditingController(text: 'Provided by your organization');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image attribution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This text is shown to raters under the image.',
              style: TextStyle(fontSize: 13, color: AppDesignTokens.secondaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Attribution',
                hintText: 'e.g. Provided by Acme Agri Research',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AssessmentGuideAnchor anchor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove image?'),
        content: const Text(
          'The image will no longer appear in the rating guide. This cannot be undone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref
          .read(assessmentGuideRepositoryProvider)
          .deleteAnchor(anchor.id);
    }
  }
}
