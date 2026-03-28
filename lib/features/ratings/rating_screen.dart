import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/plot_display.dart';
import '../../core/providers.dart';
import '../../core/session_lock.dart';
import '../../core/quick_note_templates.dart';
import '../../core/plot_sort.dart';
import '../../core/session_resume_store.dart';
import '../../core/session_walk_order_store.dart';
import '../photos/photo_filename_helper.dart';
import '../photos/photo_view_screen.dart';
import '../photos/usecases/save_photo_usecase.dart';
import 'last_value_memory.dart';
import 'usecases/save_rating_usecase.dart';
import '../sessions/arrange_plots_screen.dart';
import '../sessions/rating_order_sheet.dart';
import '../sessions/session_detail_screen.dart';

/// Status options for the rating result; maps to persisted resultStatus values.
enum RatingStatus {
  recorded,
  notObserved,
  na,
  missing,
  techIssue,
}

String _statusDisplayLabel(String value) {
  switch (value) {
    case 'NOT_OBSERVED':
      return 'Not observed';
    case 'NOT_APPLICABLE':
      return 'N/A';
    case 'MISSING_CONDITION':
      return 'Missing';
    case 'TECHNICAL_ISSUE':
      return 'Tech issue';
    default:
      return value
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
          .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
          .join(' ');
  }
}

class RatingScreen extends ConsumerStatefulWidget {
  final Trial trial;
  final Session session;
  final Plot plot;
  final List<Assessment> assessments;
  final List<Plot> allPlots;
  final int currentPlotIndex;

  /// Restored from session resume (field speed). When set, open on this assessment chip.
  final int? initialAssessmentIndex;

  /// Plot Queue filter-aware next/prev only; resume still uses full [allPlots] indices.
  final List<int>? filteredPlotIds;
  final bool isFilteredMode;
  /// Short label from Plot Queue when a single filter is active (e.g. "Unrated"); null → generic chip.
  final String? navigationModeLabel;

  const RatingScreen({
    super.key,
    required this.trial,
    required this.session,
    required this.plot,
    required this.assessments,
    required this.allPlots,
    required this.currentPlotIndex,
    this.initialAssessmentIndex,
    this.filteredPlotIds,
    this.isFilteredMode = false,
    this.navigationModeLabel,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  late Assessment _currentAssessment;
  late int _assessmentIndex;

  final TextEditingController _valueController = TextEditingController();
  String _selectedStatus = 'RECORDED';
  bool _userHasInteracted = false;
  bool _isSaving = false;

  /// Set when [_prefillFromLastValue] fills the field from last-plot memory (this visit only).
  double? _carryForwardBaselineNumeric;
  /// True after the user changes the numeric value via field, quick buttons, or fine ±.
  bool _numericValueUserEditedThisVisit = false;
  /// After "Keep & Continue" on carry-forward confirm: skip repeat prompts for same assessment+baseline until context changes.
  int? _carryForwardConfirmSuppressedAssessmentId;
  double? _carryForwardConfirmSuppressedBaseline;

  static const String _kLastRaterNameKey = 'last_rater_name';
  String? _raterName;
  bool _hasDefaultedRaterFromUser = false;
  String _confidence = 'certain';

  // Missing condition reasons per spec
  final List<String> _missingReasons = [
    'Hail',
    'Flood',
    'Animal Damage',
    'Spray Miss',
    'Lodging',
    'Harvested',
    'Other'
  ];

  WalkOrderMode _walkOrderMode = WalkOrderMode.serpentine;
  final Set<String> _selectedMissingReasons = {};

  // Photos
  final ImagePicker _picker = ImagePicker();

  /// Last integer step emitted for the value slider; used to fire haptic only on step change.
  // ignore: unused_field
  int? _lastSliderSteppedValue;

  /// Prior session rating for same plot + assessment (read-only context).
  RatingRecord? _priorRating;
  // ignore: unused_field — kept for potential future display (e.g. session context)
  String? _priorSessionName;

  final ScrollController _assessmentScrollController = ScrollController();

  Future<void> _loadPriorRating() async {
    _priorRating = null;
    _priorSessionName = null;
    try {
      final sessions = await ref.read(sessionsForTrialProvider(widget.trial.id).future);
      final earlierSessions = sessions
          .where((s) =>
              s.id != widget.session.id &&
              s.startedAt.isBefore(widget.session.startedAt))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final repo = ref.read(ratingRepositoryProvider);
      for (final session in earlierSessions) {
        final ratings = await repo.getCurrentRatingsForSession(session.id);
        final list = ratings
            .where((r) =>
                r.plotPk == widget.plot.id &&
                r.assessmentId == _currentAssessment.id)
            .toList();
        final match = list.isNotEmpty ? list.first : null;
        if (match != null) {
          if (mounted) {
            setState(() {
              _priorRating = match;
              _priorSessionName = session.name;
            });
          }
          return;
        }
      }
    } catch (_) {
      // Ignore; leave _priorRating null.
    }
  }

  /// Formatted date from previous record timestamp (e.g. "Mar 16, 2026").
  static String _formatDatePrev(DateTime dt) {
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  void initState() {
    super.initState();
    final raw = widget.initialAssessmentIndex ?? 0;
    _assessmentIndex = raw.clamp(0, widget.assessments.length - 1);
    _currentAssessment = widget.assessments[_assessmentIndex];
    _loadPriorRating();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveAssessment());
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final last = prefs.getString(_kLastRaterNameKey);
      if (last != null && last.trim().isNotEmpty) {
        setState(() => _raterName = last.trim());
      }
      final mode = SessionWalkOrderStore(prefs).getMode(widget.session.id);
      if (mounted) setState(() => _walkOrderMode = mode);
    });
  }

  @override
  void dispose() {
    _assessmentScrollController.dispose();
    WakelockPlus.disable();
    _saveResumePosition();
    _valueController.dispose();
    super.dispose();
  }

  void _scrollToActiveAssessment() {
    if (!_assessmentScrollController.hasClients) return;
    final index = widget.assessments
        .indexWhere((a) => a.id == _currentAssessment.id);
    if (index < 0) return;
    const cardWidth = 110.0;
    const cardGap = 6.0;
    const horizontalPadding = 16.0;
    final targetOffset = (index * (cardWidth + cardGap)) - horizontalPadding;
    final maxExtent = _assessmentScrollController.position.maxScrollExtent;
    _assessmentScrollController.animateTo(
      targetOffset.clamp(0.0, maxExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _saveResumePosition() {
    SharedPreferences.getInstance().then((prefs) {
      SessionResumeStore(prefs).savePosition(
        widget.session.id,
        widget.currentPlotIndex,
        _assessmentIndex,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final existingRatingAsync = ref.watch(
      currentRatingProvider(
        CurrentRatingParams(
          trialId: widget.trial.id,
          plotPk: widget.plot.id,
          assessmentId: _currentAssessment.id,
          sessionId: widget.session.id,
        ),
      ),
    );
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    // Default rater to user name once when last_rater_name is empty
    if (user?.displayName != null &&
        user!.displayName.trim().isNotEmpty &&
        _raterName == null &&
        !_hasDefaultedRaterFromUser) {
      _hasDefaultedRaterFromUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _raterName = user.displayName.trim());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kLastRaterNameKey, user.displayName.trim());
      });
    }

    final seedingEvent = ref
        .watch(seedingEventForTrialProvider(widget.trial.id))
        .valueOrNull;
    final int? dasDays = (seedingEvent != null &&
            seedingEvent.status == 'completed')
        ? widget.session.startedAt
            .difference(seedingEvent.seedingDate)
            .inDays
        : null;
    final ratedPks = ref.watch(ratedPlotPksProvider(widget.session.id)).valueOrNull ?? <int>{};
    final totalPlots = widget.allPlots.length;
    final ratedCount = ratedPks.length;
    final contextLine = dasDays != null
        ? 'Day $dasDays after seeding · $ratedCount / $totalPlots plots rated'
        : '$ratedCount / $totalPlots plots rated';

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        dividerColor: const Color(0xFFE8E5E0),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE8E5E0),
          thickness: 0.5,
          space: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppDesignTokens.backgroundSurface,
        appBar: AppBar(
          leading: const BackButton(color: Colors.white),
          title: const Text(
            'Rating',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: [
            if (!isSessionEditable(widget.session)) ...[
              Builder(
                builder: (context) {
                  final existing = existingRatingAsync.asData?.value;
                  if (existing == null) return const SizedBox.shrink();
                  return TextButton(
                    onPressed: () => _showCorrectDialog(context, existing),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Correct',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'rating_order') {
                  _showRatingOrderSheet(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'rating_order',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert, size: 20),
                      SizedBox(width: 12),
                      Text('Set rating order'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          backgroundColor: const Color(0xFF2D5A40),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildWalkOrderBar(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignTokens.spacing16,
                  AppDesignTokens.spacing8,
                  AppDesignTokens.spacing16,
                  AppDesignTokens.spacing4,
                ),
                child: Text(
                  contextLine,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 88,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildContextCard(context),
                      if (!isSessionEditable(widget.session))
                        _buildClosedSessionBanner(context),
                      _buildAssessmentSelector(context),
                      existingRatingAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, st) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text('Error: $e')),
                        ),
                        data: (existing) => _buildRatingArea(context, existing),
                      ),
                      _buildPhotoStrip(context),
                    ],
                  ),
                ),
              ),
            _buildBottomBar(context),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildClosedSessionBanner(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.lock,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kClosedSessionBlockedMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkOrderBar(BuildContext context) {
    return Material(
      color: AppDesignTokens.cardSurface,
      child: InkWell(
        onTap: () => _showWalkOrderSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.spacing16,
            vertical: 8,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_walk,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Walk order: ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                SessionWalkOrderStore.labelForMode(_walkOrderMode),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWalkOrderSheet(BuildContext context) async {
    final mode = await showModalBottomSheet<WalkOrderMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Walk order',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              for (final m in WalkOrderMode.values)
                ListTile(
                  title: Text(SessionWalkOrderStore.labelForMode(m)),
                  selected: _walkOrderMode == m,
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
      ),
    );
    if (mode == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await SessionWalkOrderStore(prefs).setMode(widget.session.id, mode);
    if (!mounted) return;
    setState(() => _walkOrderMode = mode);
    if (mode == WalkOrderMode.custom && context.mounted) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ArrangePlotsScreen(
            trial: widget.trial,
            session: widget.session,
          ),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  // ===== Photos (Capture + Save) =====

  Future<void> _capturePhoto(BuildContext context) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final existingPhotos = await ref.read(photoRepositoryProvider).getPhotosForPlotInSession(
        trialId: widget.trial.id,
        plotPk: widget.plot.id,
        sessionId: widget.session.id,
      );
      final sequenceNumber = existingPhotos.length + 1;
      final plotLabel = getDisplayPlotLabel(widget.plot, widget.allPlots);
      final capturedAt = DateTime.now();
      final fileName = generatePhotoFileName(
        trialId: widget.trial.id,
        plotLabel: plotLabel,
        sessionId: widget.session.id,
        capturedAt: capturedAt,
        sequenceNumber: sequenceNumber,
      );
      final finalPath = '${photosDir.path}/$fileName';

      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (shot == null) {
        return;
      }

      final userId = await ref.read(currentUserIdProvider.future);
      final usecase = ref.read(savePhotoUseCaseProvider);
      final res = await usecase.execute(
        SavePhotoInput(
          trialId: widget.trial.id,
          plotPk: widget.plot.id,
          sessionId: widget.session.id,
          tempPath: shot.path,
          finalPath: finalPath,
          caption: null,
          raterName: widget.session.raterName,
          performedByUserId: userId,
        ),
      );

      if (!mounted || !context.mounted) return;

      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? 'Failed to save photo')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo saved')),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo error: $e')),
      );
    }
  }

  Widget _buildPhotoStrip(BuildContext context) {
    final theme = Theme.of(context);
    final photosAsync = ref.watch(
      photosForPlotProvider(
        PhotosForPlotParams(
          trialId: widget.trial.id,
          plotPk: widget.plot.id,
          sessionId: widget.session.id,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              'PHOTOS — tap camera to add',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Divider(
            height: 1,
            thickness: 0.5,
            color: Color(0xFFE8E5E0),
          ),
          const SizedBox(height: 8),
          photosAsync.when(
            loading: () {
              const tileSize = 72.0;
              return SizedBox(
                height: tileSize + 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCameraTile(context, tileSize),
                  ],
                ),
              );
            },
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Photo load error: $e',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
          ),
          data: (photos) {
            const tileSize = 72.0;
            return SizedBox(
              height: tileSize + 24,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCameraTile(context, tileSize),
                    for (var i = 0; i < photos.length; i++) ...[
                      const SizedBox(width: 8),
                      _buildPhotoTile(
                        context,
                        photos[i],
                        i + 1,
                        photos.length,
                        tileSize,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          ),
        ],
      ),
    );
  }

  Widget _buildCameraTile(BuildContext context, double size) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _capturePhoto(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 28,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                'Add photo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile(
    BuildContext context,
    Photo photo,
    int index,
    int totalCount,
    double size,
  ) {
    final theme = Theme.of(context);
    final file = File(photo.filePath);
    final exists = file.existsSync();
    final timeStr = DateFormat('HH:mm').format(photo.createdAt);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _viewPhoto(photo),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppDesignTokens.borderCrisp),
            color: theme.colorScheme.surfaceContainerLow,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: exists
                    ? Image.file(file, fit: BoxFit.cover)
                    : Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 32,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$index/$totalCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewPhoto(Photo photo) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewScreen(
          photo: photo,
          onDelete: () async {
            await ref.read(photoRepositoryProvider).deletePhoto(photo.id);
            ref.invalidate(
              photosForPlotProvider(
                PhotosForPlotParams(
                  trialId: widget.trial.id,
                  plotPk: widget.plot.id,
                  sessionId: widget.session.id,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===== UI =====

  // ignore: unused_element - kept for future offline indicator in AppBar or menu
  Widget _buildOfflineIndicator() {
    return const SizedBox.shrink();
  }

  void _showRatingOrderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => RatingOrderSheetContent(
        session: widget.session,
        assessments: List.from(widget.assessments),
        ref: ref,
        onSaved: () {
          ref.invalidate(sessionAssessmentsProvider(widget.session.id));
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Rating order updated. It will apply when you start or continue a session.',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // ignore: unused_element - kept for future tap-to-toggle on dock flag
  Future<void> _toggleFlag(BuildContext context) async {
    final flags = ref
            .read(plotFlagsForPlotSessionProvider(
                (widget.plot.id, widget.session.id)))
            .value ??
        [];
    final db = ref.read(databaseProvider);
    if (flags.isNotEmpty) {
      await (db.delete(db.plotFlags)
            ..where((f) =>
                f.plotPk.equals(widget.plot.id) &
                f.sessionId.equals(widget.session.id)))
          .go();
      ref.invalidate(flaggedPlotIdsForSessionProvider(widget.session.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flag removed')),
        );
      }
    } else {
      await db.into(db.plotFlags).insert(
            PlotFlagsCompanion.insert(
              trialId: widget.trial.id,
              plotPk: widget.plot.id,
              sessionId: widget.session.id,
              flagType: 'FIELD_OBSERVATION',
              description: const drift.Value('Flagged'),
              raterName: drift.Value(widget.session.raterName),
            ),
          );
      ref.invalidate(flaggedPlotIdsForSessionProvider(widget.session.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plot flagged')),
        );
      }
    }
  }

  /// Single elevated context card: plot (primary), trial/crop/rep (secondary),
  /// session (tertiary). Rater shown only in RATER section to avoid duplication.
  Widget _buildContextCard(BuildContext context) {
    final plotCtx = ref.watch(plotContextProvider(widget.plot.id));
    final plotLabel = getDisplayPlotLabel(widget.plot, widget.allPlots);
    final secondaryParts = <String>[
      widget.trial.name,
      if (widget.trial.crop != null && widget.trial.crop!.trim().isNotEmpty)
        widget.trial.crop!.trim(),
      if (widget.plot.rep != null) 'Rep ${widget.plot.rep}',
    ];
    final secondaryLine = secondaryParts.join(' · ');
    final tertiaryLine = widget.session.name.trim().isNotEmpty
        ? widget.session.name
        : 'Session';
    final progressText =
        '${widget.currentPlotIndex + 1} of ${widget.allPlots.length}';
    final showFilteredChip = widget.isFilteredMode &&
        widget.filteredPlotIds != null &&
        widget.filteredPlotIds!.isNotEmpty;
    final filteredChipText = showFilteredChip
        ? (widget.navigationModeLabel != null &&
                widget.navigationModeLabel!.trim().isNotEmpty
            ? '${widget.navigationModeLabel!.trim()} mode • ${widget.filteredPlotIds!.length} plots'
            : 'Filtered mode • ${widget.filteredPlotIds!.length} plots')
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing16,
        AppDesignTokens.spacing16,
        0,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plot $plotLabel',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.primaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (secondaryLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondaryLine,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppDesignTokens.secondaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      tertiaryLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.secondaryText
                            .withValues(alpha: 0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  plotCtx.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (ctx) => ctx.hasTreatment
                        ? Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ctx.treatmentCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Text(
                    progressText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showFilteredChip) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                filteredChipText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          // Thin progress bar — last child inside card, zero external layout impact
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.allPlots.isEmpty
                  ? 0
                  : (widget.currentPlotIndex + 1) / widget.allPlots.length,
              minHeight: 2,
              backgroundColor: AppDesignTokens.borderCrisp,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.currentPlotIndex >= widget.allPlots.length - 1
                    ? AppDesignTokens.successFg
                    : AppDesignTokens.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentSelector(BuildContext context) {
    if (widget.assessments.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.spacing16,
            10,
            AppDesignTokens.spacing16,
            6),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppDesignTokens.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDesignTokens.spacing8),
            Text(
              _currentAssessment.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.primaryText,
              ),
            ),
            if (_currentAssessment.unit != null) ...[
              const SizedBox(width: 6),
              Text(
                '· ${_currentAssessment.unit}',
                style: const TextStyle(
                    fontSize: 13, color: AppDesignTokens.secondaryText),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDesignTokens.spacing16,
          10,
          AppDesignTokens.spacing16,
          6),
      child: SizedBox(
        height: 32,
        child: SingleChildScrollView(
          controller: _assessmentScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0;
                  index < widget.assessments.length;
                  index++) ...[
                if (index > 0) const SizedBox(width: 6),
                _buildAssessmentChip(context, index),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Pill display label: name without trailing unit to reduce clutter.
  static String _assessmentPillLabel(Assessment assessment) {
    final name = assessment.name.trim();
    final unit = assessment.unit?.trim();
    if (unit == null || unit.isEmpty) return name;
    final suffix = ' $unit';
    if (name.length > suffix.length &&
        name.toLowerCase().endsWith(suffix.toLowerCase())) {
      return name.substring(0, name.length - suffix.length).trim();
    }
    return name;
  }

  Widget _buildAssessmentChip(BuildContext context, int index) {
    final assessment = widget.assessments[index];
    final isSelected = assessment.id == _currentAssessment.id;
    final label = _assessmentPillLabel(assessment);
    return GestureDetector(
      onTap: () {
        setState(() {
          _assessmentIndex = index;
          _currentAssessment = assessment;
          _lastSliderSteppedValue = null;
          _valueController.clear();
          _selectedStatus = 'RECORDED';
          _userHasInteracted = false;
          _selectedMissingReasons.clear();
          _carryForwardBaselineNumeric = null;
          _numericValueUserEditedThisVisit = false;
          _carryForwardConfirmSuppressedAssessmentId = null;
          _carryForwardConfirmSuppressedBaseline = null;
        });
        _clampValueToEffectiveRange();
        _scrollToActiveAssessment();
        _loadPriorRating();
        _prefillFromLastValue();
      },
      child: Container(
        height: isSelected ? 32 : 28,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 10,
          vertical: 0,
        ),
        constraints: const BoxConstraints(maxWidth: 160),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDesignTokens.primary
              : AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(isSelected ? 16 : 14),
          border: Border.all(color: AppDesignTokens.borderCrisp),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSelected ? 13 : 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppDesignTokens.secondaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _prefillFromLastValue() {
    final last = ref.read(lastValueMemoryProvider.notifier).get(
          widget.session.id,
          _currentAssessment.id,
        );
    if (last != null && _valueController.text.isEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _valueController.text.isEmpty) {
          setState(() {
            // Re-prefill = new carry-forward context; warn again if user cleared field.
            _carryForwardConfirmSuppressedAssessmentId = null;
            _carryForwardConfirmSuppressedBaseline = null;
            _valueController.text = last.toString();
            _carryForwardBaselineNumeric = last;
            _numericValueUserEditedThisVisit = false;
          });
        }
      });
    }
  }

  void _markNumericValueUserEdited() {
    if (!_numericValueUserEditedThisVisit) {
      setState(() {
        _numericValueUserEditedThisVisit = true;
        _carryForwardConfirmSuppressedAssessmentId = null;
        _carryForwardConfirmSuppressedBaseline = null;
      });
    }
  }

  static bool _doublesMatchCarryForward(double a, double b) =>
      (a - b).abs() < 1e-9;

  /// Carry-forward duplicate: prefilled from previous plot, user never edited, value unchanged.
  bool _shouldConfirmUnchangedCarryForward() {
    if (_selectedStatus != 'RECORDED' || _isTextAssessment) return false;
    final baseline = _carryForwardBaselineNumeric;
    if (baseline == null) return false;
    if (_numericValueUserEditedThisVisit) return false;
    final cur = double.tryParse(_valueController.text.trim());
    if (cur == null) return false;
    if (!_doublesMatchCarryForward(cur, baseline)) return false;
    final supA = _carryForwardConfirmSuppressedAssessmentId;
    final supB = _carryForwardConfirmSuppressedBaseline;
    if (supA != null &&
        supB != null &&
        supA == _currentAssessment.id &&
        _doublesMatchCarryForward(supB, baseline)) {
      return false;
    }
    return true;
  }

  Future<bool> _showCarryForwardConfirmDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(
          'This value is the same as the previous plot. Keep it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Change'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keep & Continue'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showCorrectDialog(
      BuildContext context, RatingRecord existing) async {
    final newValueController = TextEditingController(
      text: existing.resultStatus == 'RECORDED'
          ? (existing.numericValue?.toString() ?? '')
          : '',
    );
    final reasonController = TextEditingController();
    String newStatus = existing.resultStatus;

    final applied = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Correct value'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original: ${existing.resultStatus == "RECORDED" ? existing.numericValue?.toString() ?? "-" : existing.resultStatus}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text('New status',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Wrap(
                    spacing: 6,
                    children: [
                      'RECORDED',
                      'NOT_OBSERVED',
                      'NOT_APPLICABLE',
                      'MISSING_CONDITION',
                      'TECHNICAL_ISSUE'
                    ]
                        .map((s) => ChoiceChip(
                              label:
                                  Text(s, style: const TextStyle(fontSize: 11)),
                              selected: newStatus == s,
                              onSelected: (_) => setState(() => newStatus = s),
                            ))
                        .toList(),
                  ),
                  if (newStatus == 'RECORDED') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: newValueController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'New value',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason *',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'e.g. Data entry error',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Reason is required')),
                    );
                    return;
                  }
                  double? newNumeric;
                  if (newStatus == 'RECORDED') {
                    newNumeric = double.tryParse(newValueController.text);
                  }
                  final userId = await ref.read(currentUserIdProvider.future);
                  final useCase = ref.read(applyCorrectionUseCaseProvider);
                  final result = await useCase.execute(
                    rating: existing,
                    session: widget.session,
                    newResultStatus: newStatus,
                    newNumericValue: newNumeric,
                    newTextValue: newStatus == 'MISSING_CONDITION'
                        ? newValueController.text.trim().isEmpty
                            ? null
                            : newValueController.text.trim()
                        : null,
                    reason: reason,
                    correctedByUserId: userId,
                  );
                  if (!ctx.mounted) return;
                  if (result.success) {
                    ref.invalidate(
                        latestCorrectionForRatingProvider(existing.id));
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text(result.errorMessage ?? 'Failed'),
                          backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Apply correction'),
              ),
            ],
          );
        },
      ),
    );
    newValueController.dispose();
    reasonController.dispose();
    if (applied == true && mounted) setState(() {});
  }

  Widget _buildRatingArea(BuildContext context, RatingRecord? existing) {
    if (existing == null &&
        _selectedStatus == 'RECORDED' &&
        _valueController.text.isEmpty) {
      _prefillFromLastValue();
    }
    // When switching to an assessment that has a saved rating, restore local state from it
    // so we don't show empty or leaked state from the previous assessment.
    if (existing != null && _valueController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _valueController.text.isNotEmpty) return;
        _valueController.text = existing.numericValue?.toString() ??
            existing.textValue?.trim() ??
            '';
        _carryForwardBaselineNumeric = null;
        _numericValueUserEditedThisVisit = false;
        _carryForwardConfirmSuppressedAssessmentId = null;
        _carryForwardConfirmSuppressedBaseline = null;
        if (!_userHasInteracted) {
          _selectedStatus = existing.resultStatus;
          _selectedMissingReasons.clear();
          if (_selectedStatus == 'MISSING_CONDITION' ||
              _selectedStatus == 'TECHNICAL_ISSUE') {
            final t = existing.textValue?.trim() ?? '';
            if (t.isNotEmpty) {
              _selectedMissingReasons.addAll(
                  t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
            }
          }
        }
        final numVal = existing.numericValue;
        _lastSliderSteppedValue = numVal?.round();
        setState(() {});
      });
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.spacing16,
        8,
        AppDesignTokens.spacing16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.spacing16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // When recording: value entry first (primary focus), then status/rater/confidence lower.
                // When not recorded: show selected status clearly in the main value rectangle.
                if (_selectedStatus == 'RECORDED') ...[
                  if (_priorRating != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE8E5E0), width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Previous Value • ${_formatDatePrev(_priorRating!.createdAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${_priorRating!.numericValue?.toString() ?? _priorRating!.textValue ?? '—'} ${_currentAssessment.unit ?? ''}'.trim(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF888780),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'Rater',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showRaterSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: const Color(0xFFE0DDD6)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _raterName != null &&
                                            _raterName!.trim().isNotEmpty
                                        ? _raterName!
                                        : (ref
                                                .watch(currentUserProvider)
                                                .valueOrNull
                                                ?.displayName ??
                                            'Set rater'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isTextAssessment) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _valueController,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      maxLines: 6,
                      minLines: 4,
                      // ignore: prefer_const_constructors
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Add notes or observation…',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: AppDesignTokens.cardSurface,
                      ),
                      autofocus: true,
                    ),
                  ] else if (_hasScaleDefined) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppDesignTokens.primary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _valueController.text.trim().isEmpty
                                ? '${_effectiveMin.round()}'
                                : _valueController.text,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryText,
                            ),
                          ),
                          if (_currentAssessment.unit != null) ...[
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                _currentAssessment.unit!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildQuickButtons(),
                  ] else ...[
                    if (_currentAssessment.minValue != null ||
                        _currentAssessment.maxValue != null ||
                        _currentAssessment.unit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Scale: $_effectiveMin–$_effectiveMax${_currentAssessment.unit != null ? " ${_currentAssessment.unit}" : ""}',
                        style: const TextStyle(
                          color: AppDesignTokens.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppDesignTokens.primary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _valueController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppDesignTokens.primaryText,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: '0',
                          suffixText: _currentAssessment.unit,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                        ),
                        autofocus: true,
                        onChanged: (_) {
                          _markNumericValueUserEdited();
                          setState(() {});
                          _clampValueToEffectiveRange();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildQuickButtons(),
                  ],
                ] else ...[
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final statusLabel = _statusDisplayLabel(_selectedStatus);

                      // Status-specific colours
                      final Color bgColor;
                      final Color borderColor;
                      final Color textColor;
                      final IconData statusIcon;

                      switch (_selectedStatus) {
                        case 'MISSING_CONDITION':
                          bgColor = const Color(0xFFFEF9EE);
                          borderColor = const Color(0xFFF59E0B);
                          textColor = const Color(0xFFB45309);
                          statusIcon = Icons.warning_amber_rounded;
                          break;
                        case 'NOT_OBSERVED':
                          bgColor = AppDesignTokens.cardSurface;
                          borderColor = AppDesignTokens.borderCrisp;
                          textColor = AppDesignTokens.secondaryText;
                          statusIcon = Icons.visibility_off_outlined;
                          break;
                        case 'TECHNICAL_ISSUE':
                          bgColor = const Color(0xFFFFF3EE);
                          borderColor = const Color(0xFFEA580C);
                          textColor = const Color(0xFFEA580C);
                          statusIcon = Icons.build_outlined;
                          break;
                        default:
                          bgColor = AppDesignTokens.cardSurface;
                          borderColor = AppDesignTokens.borderCrisp;
                          textColor = AppDesignTokens.secondaryText;
                          statusIcon = Icons.info_outline;
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(statusIcon, size: 28, color: textColor),
                            const SizedBox(height: 8),
                            Text(
                              statusLabel.isNotEmpty ? statusLabel : _selectedStatus,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedMissingReasons.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: borderColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedMissingReasons.join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFE8E5E0),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _statusPill(
                        context,
                        'Recorded',
                        'RECORDED',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _missingStatusPill(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: _buildOtherStatusDropdown(context),
                    ),
                  ],
                ),
                if (_selectedStatus == 'MISSING_CONDITION' ||
                    _selectedStatus == 'TECHNICAL_ISSUE') ...[
                  const SizedBox(height: 12),
                  Text('Reason',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showReasonSheet(context),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE0DDD6), width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedMissingReasons.isEmpty
                                  ? 'Select reason...'
                                  : '${_selectedStatus == 'MISSING_CONDITION' ? 'Missing' : 'Tech issue'} · ${_selectedMissingReasons.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedMissingReasons.isEmpty
                                    ? Colors.grey.shade400
                                    : _missingActiveColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _selectedMissingReasons.isEmpty
                                ? Icons.chevron_right
                                : Icons.edit_outlined,
                            size: 16,
                            color: _selectedMissingReasons.isEmpty
                                ? Colors.grey
                                : _missingActiveColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if ((_selectedStatus == 'MISSING_CONDITION' ||
                        _selectedStatus == 'TECHNICAL_ISSUE') &&
                    _selectedMissingReasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    color: const Color(0xFFFEF9EE),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_selectedStatus == 'MISSING_CONDITION' ? 'Missing' : 'Tech issue'} · ${_selectedMissingReasons.join(', ')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showReasonSheet(context),
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2D5A40),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_selectedStatus == 'RECORDED') ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confidence',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: SegmentedButton<String>(
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                              textStyle: WidgetStateProperty.all(
                                const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                  value: 'certain', label: Text('Certain')),
                              ButtonSegment(
                                  value: 'uncertain',
                                  label: Text('Uncertain')),
                              ButtonSegment(
                                  value: 'estimated',
                                  label: Text('Estimated')),
                            ],
                            selected: {_confidence},
                            onSelectionChanged: (Set<String> s) {
                              setState(() => _confidence = s.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRaterSheet(BuildContext context) async {
    final controller = TextEditingController(text: _raterName ?? '');
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Rater name',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Enter rater name',
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  setState(() => _raterName = name.isEmpty ? null : name);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                      _kLastRaterNameKey, name.isEmpty ? '' : name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isTextAssessment =>
      _currentAssessment.dataType.toLowerCase() == 'text';

  bool get _hasScaleDefined =>
      _currentAssessment.minValue != null &&
      _currentAssessment.maxValue != null;

  /// Unit-aware default max when assessment.maxValue is null (e.g. plant height cm cap 350).
  static int _defaultMax(String? unit) {
    switch (unit?.toLowerCase().trim()) {
      case 'cm':
        return 350;
      case 'm':
        return 4;
      case '%':
        return 100;
      case 'kg/ha':
        return 20000;
      case 'plants/plot':
        return 999;
      default:
        return 999;
    }
  }

  /// Effective min for value entry; default 0 when scaleMin is null.
  double get _effectiveMin =>
      _currentAssessment.minValue ?? 0.0;

  /// Effective max for value entry; unit-aware default when scaleMax is null.
  double get _effectiveMax =>
      _currentAssessment.maxValue ?? _defaultMax(_currentAssessment.unit).toDouble();

  void _clampValueToEffectiveRange() {
    final v = double.tryParse(_valueController.text);
    if (v == null) return;
    final clamped = v.clamp(_effectiveMin, _effectiveMax);
    if (clamped != v) {
      final step = _effectiveStep;
      final text = step < 1
          ? clamped.toStringAsFixed(1)
          : clamped.round().toString();
      _valueController.text = text;
    }
  }

  /// Step size for display/validation by unit.
  double get _effectiveStep {
    switch (_currentAssessment.unit?.toLowerCase().trim()) {
      case 'm':
        return 0.1;
      case '%':
      case 'cm':
        return 1;
      default:
        return 1;
    }
  }

  // ignore: unused_element
  double get _sliderValue {
    final min = _effectiveMin;
    final max = _effectiveMax;
    final v = double.tryParse(_valueController.text);
    if (v == null) return min;
    return v.clamp(min, max);
  }

  // ignore: unused_element
  int? get _sliderDivisions {
    final min = _effectiveMin;
    final max = _effectiveMax;
    final range = (max - min).abs();
    if (range <= 0) return null;
    if (range <= 100 && min == min.roundToDouble() && max == max.roundToDouble()) {
      return range.round();
    }
    return null;
  }

  // ignore: unused_element
  bool get _showValidRangeWarning {
    return false;
  }

  Widget _buildQuickButtons() {
    final min = _effectiveMin.round();
    final max = _effectiveMax.round();
    final range = max - min;
    final step = _effectiveStep;
    final currentVal = double.tryParse(_valueController.text);
    final currentInt = currentVal?.round();

    // Coarse values — multiples of 10 within range, or full range if ≤10
    final List<int> coarseValues = (range <= 10)
        ? List.generate(range + 1, (i) => min + i)
        : [0, 10, 20, 30, 40, 50, 60, 70, 80, 90]
            .where((v) => v >= min && v <= max)
            .toList();

    void applyFine(double delta) {
      _markNumericValueUserEdited();
      final current = double.tryParse(_valueController.text) ?? _effectiveMin;
      final next = (current + delta).clamp(_effectiveMin, _effectiveMax);
      setState(() {
        _valueController.text = step < 1
            ? next.toStringAsFixed(1)
            : next.round().toString();
      });
      _clampValueToEffectiveRange();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Coarse buttons — 5 per row, wraps to second row for 10 values
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.6,
          children: coarseValues.map((val) {
            final isSelected = currentInt == val;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _markNumericValueUserEdited();
                setState(() => _valueController.text = val.toString());
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppDesignTokens.primary
                      : AppDesignTokens.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppDesignTokens.primary
                        : AppDesignTokens.borderCrisp,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    val.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : AppDesignTokens.primaryText,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // Fine adjustment row — ±step and ±5×step
        Row(
          children: [
            _fineBtn(
              '−${(step * 5) == (step * 5).roundToDouble() && step < 1 ? (step * 5).toStringAsFixed(1) : (step * 5).round()}',
              () => applyFine(-step * 5),
            ),
            const SizedBox(width: 4),
            _fineBtn(
              '−${step < 1 ? step.toStringAsFixed(1) : step.round()}',
              () => applyFine(-step),
            ),
            const SizedBox(width: 4),
            // Value field centered between −step and +step; unit outside so number is visually centered
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppDesignTokens.primary.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _valueController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.primaryText,
                          ),
                          // ignore: prefer_const_constructors
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: '0',
                            // ignore: prefer_const_constructors
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AppDesignTokens.secondaryText,
                            ),
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (_) {
                            _markNumericValueUserEdited();
                            setState(() {});
                            _clampValueToEffectiveRange();
                          },
                        ),
                      ),
                    ),
                    if (_currentAssessment.unit != null &&
                        _currentAssessment.unit!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          _currentAssessment.unit!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _fineBtn(
              '+${step < 1 ? step.toStringAsFixed(1) : step.round()}',
              () => applyFine(step),
            ),
            const SizedBox(width: 4),
            _fineBtn(
              '+${(step * 5) == (step * 5).roundToDouble() && step < 1 ? (step * 5).toStringAsFixed(1) : (step * 5).round()}',
              () => applyFine(step * 5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fineBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 36,
        decoration: BoxDecoration(
          color: AppDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppDesignTokens.borderCrisp,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReasonSheet(BuildContext context) async {
    Set<String> selected = Set.from(_selectedMissingReasons);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            bottom: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select reason',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _missingReasons.map((reason) {
                          final isSelected = selected.contains(reason);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selected.remove(reason);
                                } else {
                                  selected.add(reason);
                                }
                              });
                            },
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFEF9EE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  width: 1,
                                  color: isSelected
                                      ? const Color(0xFFF59E0B)
                                      : Colors.grey,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFFB45309)
                                      : Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedMissingReasons.clear();
                            _selectedMissingReasons.addAll(selected);
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Persistent next-action dock: same location, same order, every time.
  /// Save (secondary) + Save & Next (primary); Prev, Jump, Flag below.
  Widget _buildBottomBar(BuildContext context) {
    final isLastPlot = _effectiveIsLastPlotForNavigation;
    final isLastAssessment = _assessmentIndex >= widget.assessments.length - 1;
    final isVeryLast = isLastPlot && isLastAssessment;
    final canGoBack = !_effectiveIsFirstPlotForNavigation;

    // Dynamic primary button label
    String primaryLabel;
    if (isVeryLast) {
      primaryLabel =
          _isAtEndOfFilteredSequence ? 'Done' : 'Save & Finish';
    } else if (isLastAssessment) {
      primaryLabel = 'Save & Next Plot';
    } else {
      primaryLabel = 'Save & Next';
    }

    final editable = isSessionEditable(widget.session);

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: const BoxDecoration(
          color: AppDesignTokens.cardSurface,
          border: Border(top: BorderSide(color: AppDesignTokens.borderCrisp)),
          boxShadow: [
            BoxShadow(
              color: AppDesignTokens.shadowMedium,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main actions: Save (outlined) + Save & Next (primary, dominant)
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isSaving || !editable
                        ? null
                        : () => _saveRating(context, navigateAfterSave: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppDesignTokens.primary,
                      side:
                          const BorderSide(color: AppDesignTokens.borderCrisp),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDesignTokens.spacing8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving || !editable
                        ? null
                        : () => _saveRating(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppDesignTokens.divider,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  primaryLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                isVeryLast
                                    ? Icons.check_circle_outline
                                    : Icons.arrow_forward,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Secondary: Prev, Jump, Flag (small) — centered as a group
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed:
                      canGoBack ? () => _navigatePlot(context, -1) : null,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Prev', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesignTokens.secondaryText,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showJumpToPlotDialog(context),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Jump', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesignTokens.secondaryText,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showFlagDialog(context),
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  tooltip: 'Flag plot',
                  style: IconButton.styleFrom(
                    foregroundColor: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _showJumpToPlotDialog(BuildContext context) async {
    if (widget.allPlots.isEmpty) return;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Plot'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Plot number',
            hintText: 'e.g. 101',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    if (!context.mounted) return;
    final index = widget.allPlots.indexWhere(
      (p) => getDisplayPlotLabel(p, widget.allPlots) == result,
    );
    if (index < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plot "$result" not found')),
        );
      }
      return;
    }
    if (index == widget.currentPlotIndex) return;
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          trial: widget.trial,
          session: widget.session,
          plot: widget.allPlots[index],
          assessments: widget.assessments,
          allPlots: widget.allPlots,
          currentPlotIndex: index,
          initialAssessmentIndex: null,
        ),
      ),
    );
  }

  // ===== Actions =====

  /// Saves the current rating. When [navigateAfterSave] is true (default), advances to next
  /// assessment or next plot or shows session complete; when false, stays on current plot/assessment.
  Future<void> _saveRating(BuildContext context,
      {bool navigateAfterSave = true,
      bool skipCarryForwardConfirm = false}) async {
    if (!skipCarryForwardConfirm && _shouldConfirmUnchangedCarryForward()) {
      final proceed = await _showCarryForwardConfirmDialog(context);
      if (!context.mounted) return;
      if (!proceed) return;
      if (mounted && _carryForwardBaselineNumeric != null) {
        setState(() {
          _carryForwardConfirmSuppressedAssessmentId =
              _currentAssessment.id;
          _carryForwardConfirmSuppressedBaseline =
              _carryForwardBaselineNumeric;
        });
      }
      return _saveRating(context,
          navigateAfterSave: navigateAfterSave,
          skipCarryForwardConfirm: true);
    }

    double? numericValue;
    String? textValue;
    if (_selectedStatus == 'RECORDED') {
      if (_isTextAssessment) {
        textValue = _valueController.text.trim().isNotEmpty
            ? _valueController.text.trim()
            : null;
      } else {
        numericValue = double.tryParse(_valueController.text);
        if (numericValue == null && _valueController.text.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid number'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (numericValue != null) {
          numericValue = numericValue.clamp(_effectiveMin, _effectiveMax);
        }
      }
    } else if (_selectedStatus == 'MISSING_CONDITION') {
      textValue = _selectedMissingReasons.isEmpty
          ? null
          : _selectedMissingReasons.join(', ');
    }

    setState(() => _isSaving = true);

    final userId = await ref.read(currentUserIdProvider.future);
    final now = DateTime.now();
    final ratingTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final useCase = ref.read(saveRatingUseCaseProvider);
    final result = await useCase.execute(
      SaveRatingInput(
        trialId: widget.trial.id,
        plotPk: widget.plot.id,
        assessmentId: _currentAssessment.id,
        sessionId: widget.session.id,
        resultStatus: _selectedStatus,
        numericValue: numericValue,
        textValue: textValue,
        raterName: _raterName?.trim().isNotEmpty == true
            ? _raterName
            : widget.session.raterName,
        performedByUserId: userId,
        isSessionClosed: widget.session.endedAt != null,
        minValue: _currentAssessment.minValue,
        maxValue: _currentAssessment.maxValue,
        ratingTime: ratingTime,
        confidence: _confidence,
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      if (_raterName != null && _raterName!.trim().isNotEmpty) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_kLastRaterNameKey, _raterName!.trim());
        });
      }
      ref.invalidate(sessionRatingsProvider(widget.session.id));
      ref.invalidate(ratedPlotPksProvider(widget.session.id));
      if (numericValue != null) {
        ref.read(lastValueMemoryProvider.notifier).set(
              widget.session.id,
              _currentAssessment.id,
              numericValue,
            );
      }
      if (!navigateAfterSave) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved')),
          );
        }
        return;
      }
      if (_assessmentIndex < widget.assessments.length - 1) {
        setState(() {
          _assessmentIndex++;
          _currentAssessment = widget.assessments[_assessmentIndex];
          _lastSliderSteppedValue = null;
          _valueController.clear();
          _selectedStatus = 'RECORDED';
          _selectedMissingReasons.clear();
          _carryForwardBaselineNumeric = null;
          _numericValueUserEditedThisVisit = false;
          _carryForwardConfirmSuppressedAssessmentId = null;
          _carryForwardConfirmSuppressedBaseline = null;
        });
        _clampValueToEffectiveRange();
        _scrollToActiveAssessment();
        _loadPriorRating();
        _prefillFromLastValue();
      } else {
        if (!context.mounted) return;
        if (_effectiveIsLastPlotForNavigation) {
          if (_isAtEndOfFilteredSequence) {
            _showEndOfFilteredListDialog(context);
          } else {
            _showSessionCompleteDialog(context);
          }
        } else {
          _navigatePlot(context, 1);
        }
      }
    } else if (result.isDebounced) {
      // silent
    } else {
      if (!context.mounted) return;
      final msg = result.errorMessage ?? 'Save failed';
      if (msg == kClosedSessionBlockedMessage) {
        ref
            .read(diagnosticsStoreProvider)
            .recordError(msg, code: 'closed_session_write_blocked');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSessionCompleteDialog(BuildContext context) async {
    final flaggedIds = await ref
        .read(flaggedPlotIdsForSessionProvider(widget.session.id).future);
    final flaggedCount = flaggedIds.length;
    final photoCount = await ref
        .read(photoRepositoryProvider)
        .getPhotoCountForSession(widget.session.id);
    final plotCount = widget.allPlots.length;
    final summary =
        '$plotCount plots rated · $flaggedCount flagged · $photoCount photos';

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.backgroundSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge)),
        contentPadding: EdgeInsets.zero,
        titlePadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.all(AppDesignTokens.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppDesignTokens.successBg,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.check_circle,
                    color: AppDesignTokens.primary, size: 36),
              ),
              const SizedBox(height: AppDesignTokens.spacing16),
              const Text(
                'All Plots Rated',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryText,
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing8),
              Text(
                "You've completed all $plotCount plots in this session.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppDesignTokens.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing8),
              Text(
                summary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(
                          trial: widget.trial,
                          session: widget.session,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDesignTokens.radiusCard)),
                  ),
                  child: const Text('Back to Session',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: AppDesignTokens.spacing8 + 2),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Keep reviewing plots',
                  style: TextStyle(
                      color: AppDesignTokens.secondaryText, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEndOfFilteredListDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End of Filtered List'),
        content: const Text(
          'You\'ve reached the last plot in this filter.',
          style: TextStyle(fontSize: 14, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Plot Queue'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _continueFullWalkFromFiltered(context);
            },
            child: const Text('Continue Full Walk'),
          ),
        ],
      ),
    );
  }

  void _continueFullWalkFromFiltered(BuildContext context) {
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RatingScreen(
          trial: widget.trial,
          session: widget.session,
          plot: widget.plot,
          assessments: widget.assessments,
          allPlots: widget.allPlots,
          currentPlotIndex: widget.currentPlotIndex,
          initialAssessmentIndex: _assessmentIndex,
          filteredPlotIds: null,
          isFilteredMode: false,
          navigationModeLabel: null,
        ),
      ),
    );
  }

  /// True when current plot is the last entry in [filteredPlotIds] (filter-aware walk).
  bool get _isAtEndOfFilteredSequence {
    final ids = widget.filteredPlotIds;
    if (!widget.isFilteredMode || ids == null || ids.isEmpty) {
      return false;
    }
    final i = ids.indexOf(widget.plot.id);
    return i >= 0 && i == ids.length - 1;
  }

  /// Last plot for Save & Next / session-complete when filter mode is on.
  bool get _effectiveIsLastPlotForNavigation {
    final ids = widget.filteredPlotIds;
    if (widget.isFilteredMode && ids != null && ids.isNotEmpty) {
      final i = ids.indexOf(widget.plot.id);
      if (i < 0) {
        return widget.currentPlotIndex >= widget.allPlots.length - 1;
      }
      return i >= ids.length - 1;
    }
    return widget.currentPlotIndex >= widget.allPlots.length - 1;
  }

  bool get _effectiveIsFirstPlotForNavigation {
    final ids = widget.filteredPlotIds;
    if (widget.isFilteredMode && ids != null && ids.isNotEmpty) {
      final i = ids.indexOf(widget.plot.id);
      if (i < 0) {
        return widget.currentPlotIndex <= 0;
      }
      return i <= 0;
    }
    return widget.currentPlotIndex <= 0;
  }

  void _navigatePlot(BuildContext context, int direction) {
    final ids = widget.filteredPlotIds;
    if (widget.isFilteredMode && ids != null && ids.isNotEmpty) {
      final fi = ids.indexOf(widget.plot.id);
      if (fi >= 0) {
        final nextFi = fi + direction;
        if (nextFi >= 0 && nextFi < ids.length) {
          final targetId = ids[nextFi];
          final fullIndex = widget.allPlots.indexWhere((p) => p.id == targetId);
          if (fullIndex >= 0) {
            _pushRatingReplacementAtFullIndex(context, fullIndex);
            return;
          }
        }
        return;
      }
    }

    final nextIndex = widget.currentPlotIndex + direction;
    if (nextIndex < 0 || nextIndex >= widget.allPlots.length) {
      return;
    }

    // Rep completion feedback: haptic when leaving the last plot in current rep (field speed).
    if (direction == 1) {
      final currentRep = widget.plot.rep;
      if (currentRep != null) {
        var isLastInRep = true;
        for (var i = widget.currentPlotIndex + 1;
            i < widget.allPlots.length;
            i++) {
          if (widget.allPlots[i].rep == currentRep) {
            isLastInRep = false;
            break;
          }
        }
        if (isLastInRep) {
          HapticFeedback.mediumImpact();
          if (context.mounted) {
            final repLabel = 'Rep $currentRep';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppDesignTokens.onPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: AppDesignTokens.spacing8),
                    Text(
                      '$repLabel complete',
                      style: const TextStyle(
                        color: AppDesignTokens.onPrimary,
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 1500),
                backgroundColor: AppDesignTokens.successFg,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(
                  AppDesignTokens.spacing16,
                  0,
                  AppDesignTokens.spacing16,
                  AppDesignTokens.spacing16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        }
      }
    }

    _pushRatingReplacementAtFullIndex(context, nextIndex);
  }

  void _pushRatingReplacementAtFullIndex(
      BuildContext context, int fullIndex) {
    if (fullIndex < 0 || fullIndex >= widget.allPlots.length) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RatingScreen(
          trial: widget.trial,
          session: widget.session,
          plot: widget.allPlots[fullIndex],
          assessments: widget.assessments,
          allPlots: widget.allPlots,
          currentPlotIndex: fullIndex,
          initialAssessmentIndex: null,
          filteredPlotIds: widget.filteredPlotIds,
          isFilteredMode: widget.isFilteredMode,
          navigationModeLabel: widget.navigationModeLabel,
        ),
      ),
    );
  }

  // Used from plot detail or future undo entry point.
  // ignore: unused_element
  Future<void> _undoRating(BuildContext context, RatingRecord existing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Rating'),
        content: Text(
            'Undo rating for Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)} – ${_currentAssessment.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Undo')),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    final userId = await ref.read(currentUserIdProvider.future);
    final useCase = ref.read(undoRatingUseCaseProvider);
    final result = await useCase.execute(
      currentRatingId: existing.id,
      sessionId: widget.session.id,
      isSessionClosed: widget.session.endedAt != null,
      raterName: widget.session.raterName,
      performedByUserId: userId,
    );
    if (!mounted) return;
    if (result.success) {
      ref.invalidate(sessionRatingsProvider(widget.session.id));
      ref.invalidate(ratedPlotPksProvider(widget.session.id));
    } else {
      if (result.errorMessage == kClosedSessionBlockedMessage) {
        ref.read(diagnosticsStoreProvider).recordError(
              result.errorMessage!,
              code: 'closed_session_write_blocked',
            );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Undo failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFlagDialog(BuildContext context) async {
    final descController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Flag Plot ${getDisplayPlotLabel(widget.plot, widget.allPlots)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kQuickNoteTemplates.map((label) {
                return ActionChip(
                  label: Text(label),
                  onPressed: () {
                    final before = descController.text.trim();
                    descController.text =
                        before.isEmpty ? label : '$before, $label';
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'e.g. Weed patch, border effect',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (descController.text.trim().isEmpty) return;
              final db = ref.read(databaseProvider);
              await db.into(db.plotFlags).insert(
                    PlotFlagsCompanion.insert(
                      trialId: widget.trial.id,
                      plotPk: widget.plot.id,
                      sessionId: widget.session.id,
                      flagType: 'FIELD_OBSERVATION',
                      description: drift.Value(descController.text.trim()),
                      raterName: drift.Value(widget.session.raterName),
                    ),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save Flag'),
          ),
        ],
      ),
    );
  }

  static const Color _missingActiveColor = Color(0xFFB45309);

  /// Simple exception statuses only. Missing is handled by a dedicated control.
  static const List<({String value, String label})> _otherStatusOptions = [
    (value: 'NOT_OBSERVED', label: 'Not observed'),
    (value: 'NOT_APPLICABLE', label: 'N/A'),
    (value: 'TECHNICAL_ISSUE', label: 'Tech issue'),
  ];

  Widget _statusPill(BuildContext context, String label, String value) {
    final bool isSelected = _selectedStatus == value;
    final Color bgColor =
        isSelected ? const Color(0xFFE8F5EE) : Colors.white;
    final Color borderColor =
        isSelected ? const Color(0xFF2D5A40) : const Color(0xFFE0DDD6);
    final Color textColor =
        isSelected ? const Color(0xFF2D5A40) : Colors.grey.shade600;
    return GestureDetector(
      onTap: () {
        setState(() {
          _userHasInteracted = true;
          _selectedStatus = value;
          if (value != 'RECORDED') {
            _valueController.clear();
          }
          if (value != 'MISSING_CONDITION' && value != 'TECHNICAL_ISSUE') {
            _selectedMissingReasons.clear();
          }
        });
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(width: 1, color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  /// Dedicated control for Missing so it can later support reasons, subtypes,
  /// and reporting without being flattened into the simple "Other" dropdown.
  Widget _missingStatusPill(BuildContext context) {
    final bool isSelected = _selectedStatus == 'MISSING_CONDITION';
    final Color bgColor = isSelected
        ? const Color(0xFFFEF9EE)
        : Colors.white;
    final Color borderColor = isSelected
        ? const Color(0xFFF59E0B)
        : const Color(0xFFE0DDD6);
    final Color textColor = isSelected
        ? const Color(0xFFB45309)
        : Colors.grey.shade600;
    return GestureDetector(
      onTap: () {
        setState(() {
          _userHasInteracted = true;
          _selectedStatus = 'MISSING_CONDITION';
          _valueController.clear();
          // Keep _selectedMissingReasons; user may open Reason sheet after
        });
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(width: 1, color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          'Missing',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildOtherStatusDropdown(BuildContext context) {
    final bool isSimpleOther =
        _selectedStatus == 'RECORDED' || _selectedStatus == 'MISSING_CONDITION';
    final String displayText = isSimpleOther
        ? 'Other'
        : _statusDisplayLabel(_selectedStatus);
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0DDD6)),
        ),
        alignment: Alignment.center,
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => _otherStatusOptions
          .map(
            (e) => PopupMenuItem<String>(
              value: e.value,
              child: Text(
                e.label,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      onSelected: (String value) {
        setState(() {
          _selectedStatus = value;
          _valueController.clear();
          if (value != 'MISSING_CONDITION' && value != 'TECHNICAL_ISSUE') {
            _selectedMissingReasons.clear();
          }
        });
      },
    );
  }

}

class _PhotoViewerScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${photos.length}'),
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _controller,
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final p = photos[i];
            final file = File(p.filePath);
            final exists = file.existsSync();

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: exists
                          ? InteractiveViewer(
                              child: Image.file(file, fit: BoxFit.contain),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image,
                                    size: 60, color: Colors.white70),
                                const SizedBox(height: 10),
                                const Text('File not found',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 6),
                                Text(
                                  p.filePath,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.filePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (p.caption != null && p.caption!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Caption: ${p.caption}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
