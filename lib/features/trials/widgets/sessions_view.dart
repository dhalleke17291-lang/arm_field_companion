part of '../trial_detail_screen.dart';

class SessionListEntry {
  final bool isHeader;
  final String? date;
  final Session? session;
  const SessionListEntry({required this.isHeader, this.date, this.session});
}

enum _SessionIncompleteAction { keepOpen, reviewSession, plotQueue }

class SessionPill extends StatelessWidget {
  const SessionPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class SessionsView extends ConsumerWidget {
  final Trial trial;
  final VoidCallback? onBack;

  const SessionsView({super.key, required this.trial, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsForTrialProvider(trial.id));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundSurface,
      body: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              Expanded(
                child: Text(
                  'Sessions',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.download_for_offline),
                tooltip: 'Export closed sessions (ZIP per session)',
                onSelected: (value) async {
                  final guard = ref.read(exportGuardProvider);
                  final ran = await guard.runExclusive(() async {
                    final user = await ref.read(currentUserProvider.future);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(value == 'arm_xml'
                              ? 'Exporting XML...'
                              : 'Exporting...')),
                    );
                    final result = value == 'arm_xml'
                        ? await ref
                            .read(
                                exportTrialClosedSessionsArmXmlUsecaseProvider)
                            .execute(
                              trialId: trial.id,
                              trialName: trial.name,
                              exportedByDisplayName: user?.displayName,
                            )
                        : await ref
                            .read(exportTrialClosedSessionsUsecaseProvider)
                            .execute(
                              trialId: trial.id,
                              trialName: trial.name,
                              exportedByDisplayName: user?.displayName,
                            );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    if (result.success) {
                      final box = context.findRenderObject() as RenderBox?;
                      await Share.shareXFiles(
                        [XFile(result.filePath!)],
                        text:
                            '${trial.name} – ${result.sessionCount} closed sessions',
                        sharePositionOrigin: box == null
                            ? const Rect.fromLTWH(0, 0, 100, 100)
                            : box.localToGlobal(Offset.zero) & box.size,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Exported ${result.sessionCount} sessions')),
                      );
                    } else {
                      final scheme = Theme.of(context).colorScheme;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.errorMessage ?? 'Export failed',
                            style: TextStyle(color: scheme.onError),
                          ),
                          backgroundColor: scheme.error,
                        ),
                      );
                    }
                  });
                  if (!ran && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(ExportGuard.busyMessage)),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'csv',
                    child: Text('Closed Sessions (CSV ZIP)'),
                  ),
                  const PopupMenuItem(
                    value: 'arm_xml',
                    child: Text('Closed Sessions (XML ZIP)'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () =>
                    ref.invalidate(sessionsForTrialProvider(trial.id)),
              ),
              data: (sessions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: sessions.isEmpty
                          ? _buildEmptySessions(context, ref)
                          : _buildSessionsList(context, ref, sessions),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySessions(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: Icons.folder_open,
      title: 'No Sessions Yet',
      subtitle: 'Start a session to begin collecting field data.',
      action: FilledButton.icon(
        onPressed: () => tryOpenCreateSessionScreen(
          context: context,
          ref: ref,
          trial: trial,
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Session'),
      ),
    );
  }

  /// Normalize to YYYY-MM-DD so grouping and header formatting never see a full datetime string.
  static String _normalizeSessionDateKey(String sessionDateLocal) {
    if (sessionDateLocal.length >= 10) return sessionDateLocal.substring(0, 10);
    final space = sessionDateLocal.indexOf(' ');
    if (space > 0) return sessionDateLocal.substring(0, space);
    final t = sessionDateLocal.indexOf('T');
    if (t > 0) return sessionDateLocal.substring(0, t);
    return sessionDateLocal;
  }

  Widget _buildSessionsList(
      BuildContext context, WidgetRef ref, List<Session> sessions) {
    final groups = <String, List<Session>>{};
    for (final session in sessions) {
      final key = _normalizeSessionDateKey(session.sessionDateLocal);
      groups.putIfAbsent(key, () => []).add(session);
    }
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final entries = <SessionListEntry>[];
    for (final date in sortedDates) {
      entries.add(SessionListEntry(isHeader: true, date: date));
      for (final session in groups[date]!) {
        entries.add(SessionListEntry(isHeader: false, session: session));
      }
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            if (e.isHeader) {
              return _buildSessionDateHeader(context, e.date!);
            }
            return _buildSessionListTile(context, ref, e.session!);
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'new_session',
            onPressed: () => tryOpenCreateSessionScreen(
              context: context,
              ref: ref,
              trial: trial,
            ),
            backgroundColor: AppDesignTokens.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionDateHeader(BuildContext context, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16,
          vertical: AppDesignTokens.spacing8),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border: Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              size: 14, color: AppDesignTokens.secondaryText),
          const SizedBox(width: 6),
          Text(
            _formatDateHeader(date),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppDesignTokens.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionListTile(
      BuildContext context, WidgetRef ref, Session session) {
    if (session.status == kSessionStatusPlanned) {
      return _buildPlannedSessionTile(context, ref, session);
    }
    final isOpen = isSessionOpenForFieldWork(session);
    final ratings =
        ref.watch(sessionRatingsProvider(session.id)).valueOrNull ?? [];
    final flaggedIds =
        ref.watch(flaggedPlotIdsForSessionProvider(session.id)).valueOrNull ??
            <int>{};
    final hasFlags = flaggedIds.isNotEmpty;
    final issuePlotIds = ratings
        .where((r) => r.resultStatus != 'RECORDED')
        .map((r) => r.plotPk)
        .toSet();
    final hasIssues = issuePlotIds.isNotEmpty;
    final needsAttention = hasFlags || hasIssues;
    final correctionSessionIds = ref
            .watch(sessionIdsWithCorrectionsForTrialProvider(trial.id))
            .valueOrNull ??
        <int>{};
    final hasEdited = ratings.any((r) => r.amended || (r.previousId != null)) ||
        correctionSessionIds.contains(session.id);

    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isOpen) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PlotQueueScreen(trial: trial, session: session)));
            } else {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SessionSummaryScreen(
                          trial: trial, session: session)));
            }
          },
          onLongPress:
              isOpen ? () => _confirmCloseSession(context, ref, session) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppDesignTokens.openSessionBgLight
                        : AppDesignTokens.emptyBadgeBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusXSmall),
                  ),
                  child: Icon(
                    isOpen ? Icons.play_circle : Icons.check_circle,
                    color: isOpen
                        ? AppDesignTokens.openSessionBg
                        : AppDesignTokens.emptyBadgeFg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _shortSessionName(
                            session.name, session.sessionDateLocal),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppDesignTokens.primaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatSessionTimes(session),
                        style: subtitleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ref
                          .watch(sessionTimingContextProvider(session.id))
                          .maybeWhen(
                            data: (t) {
                              if (t.displayLine.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  t.displayLine,
                                  style: subtitleStyle?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: AppDesignTokens.spacing8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (hasEdited)
                            const SessionPill(
                              label: 'Edited',
                              backgroundColor: AppDesignTokens.sectionHeaderBg,
                              foregroundColor: AppDesignTokens.secondaryText,
                            ),
                          ..._sessionStatusChips(isOpen, needsAttention),
                          if (ref
                                  .watch(weatherSnapshotForSessionProvider(
                                      session.id))
                                  .valueOrNull !=
                              null)
                            const Icon(
                              Icons.cloud,
                              size: 16,
                              color: AppDesignTokens.secondaryText,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppDesignTokens.secondaryText,
                  ),
                  tooltip: 'More actions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onSelected: (value) {
                    if (value == 'delete_session') {
                      _confirmAndSoftDeleteSession(context, ref, session);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete_session',
                      child: Text('Move to Recovery'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Specialized tile for a [kSessionStatusPlanned] session.
  ///
  /// Planned sessions carry no ratings or timings; what matters is the ARM
  /// schedule they represent and a clear "Start" affordance. The tile reads
  /// optional ARM metadata through [armSessionMetadataProvider]; when the
  /// provider returns null (non-ARM planned session, or ARM trial imported
  /// before Phase 1b) only the planned date renders.
  Widget _buildPlannedSessionTile(
      BuildContext context, WidgetRef ref, Session session) {
    final armMeta =
        ref.watch(armSessionMetadataProvider(session.id)).valueOrNull;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    final metadataLine = _formatPlannedMetadataLine(armMeta);
    final hasOpenSessionElsewhere =
        ref.watch(openSessionProvider(trial.id)).valueOrNull != null;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing16, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        border: Border.all(color: AppDesignTokens.borderCrisp),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasOpenSessionElsewhere
              ? null
              : () => _startPlannedSession(context, ref, session),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDesignTokens.spacing8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.sectionHeaderBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusXSmall),
                  ),
                  child: const Icon(
                    Icons.event_outlined,
                    color: AppDesignTokens.secondaryText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary: what will be rated (session.name is now the
                      // comma-joined assessment names from ARM import).
                      // Fall back to the date when the name is empty or still
                      // the legacy "Planned — date" pattern that slipped past
                      // the back-fill.
                      Text(
                        _sessionHeadline(session),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppDesignTokens.primaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateHeader(session.sessionDateLocal),
                        style: subtitleStyle?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                      ),
                      if (metadataLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metadataLine,
                          style: subtitleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SessionPill(
                            label: 'Planned',
                            backgroundColor: AppDesignTokens.sectionHeaderBg,
                            foregroundColor: AppDesignTokens.secondaryText,
                            icon: Icons.schedule,
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: hasOpenSessionElsewhere
                                ? null
                                : () =>
                                    _startPlannedSession(context, ref, session),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Start'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                      if (hasOpenSessionElsewhere) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Close the open session on this trial before starting a planned one.',
                          style: subtitleStyle?.copyWith(
                              color: AppDesignTokens.warningFg),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppDesignTokens.secondaryText,
                  ),
                  tooltip: 'More actions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onSelected: (value) {
                    if (value == 'delete_session') {
                      _confirmAndSoftDeleteSession(context, ref, session);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete_session',
                      child: Text('Move to Recovery'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Headline text for a session tile: the session name, with a date fallback
  /// when the name is empty or still the legacy "Planned — $date" form.
  String _sessionHeadline(Session session) {
    final raw = session.name.trim();
    if (raw.isEmpty) return _formatDateHeader(session.sessionDateLocal);
    if (RegExp(r'^Planned\s*[—-]\s*').hasMatch(raw)) {
      return _formatDateHeader(session.sessionDateLocal);
    }
    return raw;
  }

  /// Composes "Timing · Stage · Interval" from ARM session metadata.
  /// Each segment is included only when present; returns empty when nothing
  /// ARM-specific is available.
  String _formatPlannedMetadataLine(ArmSessionMetadataData? m) {
    if (m == null) return '';
    final parts = <String>[];
    final timing = m.timingCode?.trim();
    if (timing != null && timing.isNotEmpty) {
      parts.add(timing);
    }
    final stage =
        _composeCropStage(m.cropStageScale, m.cropStageMaj, m.cropStageMin);
    if (stage.isNotEmpty) {
      parts.add(stage);
    }
    final trt = m.trtEvalInterval?.trim();
    if (trt != null && trt.isNotEmpty) {
      parts.add(trt);
    }
    final plant = m.plantEvalInterval?.trim();
    if (plant != null && plant.isNotEmpty) {
      parts.add(plant);
    }
    return parts.join(' · ');
  }

  String _composeCropStage(String? scale, String? major, String? minor) {
    final maj = major?.trim() ?? '';
    final min = minor?.trim() ?? '';
    final sc = scale?.trim() ?? '';
    if (maj.isEmpty && min.isEmpty) return '';
    final stage = min.isEmpty ? maj : (maj.isEmpty ? min : '$maj–$min');
    return sc.isEmpty ? stage : '$sc $stage';
  }

  Future<void> _startPlannedSession(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final latest = ref.read(trialProvider(trial.id)).valueOrNull ?? trial;
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final fieldWorkKey = 'field_work_started_${trial.id}';
    final fieldWorkSeen = prefs.getBool(fieldWorkKey) ?? false;

    if (latest.status == kTrialStatusDraft && !fieldWorkSeen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Starting Field Work'),
          content: const Text(
            'Once you begin rating or recording applications, the trial '
            'structure will be locked:\n'
            '• Treatments cannot be added or removed\n'
            '• Plot layout cannot be changed\n'
            '• Assessment types cannot be changed\n\n'
            'Ratings and notes can always be added.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not Yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Begin Field Work'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await prefs.setBool(fieldWorkKey, true);
    }

    try {
      final user = await ref.read(currentUserProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      final armMeta =
          ref.read(armSessionMetadataProvider(session.id)).valueOrNull;
      final cropStageBbch = int.tryParse(armMeta?.cropStageMaj?.trim() ?? '');
      final started =
          await ref.read(sessionRepositoryProvider).startPlannedSession(
                session.id,
                raterName: session.raterName ?? user?.displayName,
                startedByUserId: userId,
                cropStageBbch: cropStageBbch,
              );
      if (!context.mounted) return;
      ref.invalidate(sessionsForTrialProvider(trial.id));
      ref.invalidate(openSessionProvider(trial.id));
      ref.invalidate(armSessionMetadataProvider(session.id));
      invalidateTrialReviewProviders(ref, trial.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlotQueueScreen(trial: trial, session: started),
        ),
      );
    } on OpenSessionExistsException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Another session is already open on this trial. Close it first.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not start session'),
          content: SelectableText('$e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<Widget> _sessionStatusChips(bool isOpen, bool needsAttention) {
    if (isOpen && !needsAttention) {
      return const [
        SessionPill(
          label: 'Open',
          backgroundColor: AppDesignTokens.openSessionBg,
          foregroundColor: Colors.white,
        ),
      ];
    }
    if (needsAttention) {
      return [
        if (isOpen)
          const SessionPill(
            label: 'Open',
            backgroundColor: AppDesignTokens.openSessionBg,
            foregroundColor: Colors.white,
          ),
        const SessionPill(
          label: 'Warnings',
          backgroundColor: AppDesignTokens.warningBg,
          foregroundColor: AppDesignTokens.warningFg,
          icon: Icons.warning_amber_outlined,
        ),
      ];
    }
    return [
      const Text(
        'Closed',
        style: TextStyle(
          color: AppDesignTokens.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ];
  }

  Future<void> _confirmAndSoftDeleteSession(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: const Text(
          'This session moves to Recovery. Ratings in this session move to Recovery too. '
          'The trial and its plots are unchanged. You can restore this session later from Recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final user = await ref.read(currentUserProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      await ref.read(sessionRepositoryProvider).softDeleteSession(
            session.id,
            deletedBy: user?.displayName,
            deletedByUserId: userId,
          );
      if (!context.mounted) return;
      final trialId = trial.id;
      ref.invalidate(sessionsForTrialProvider(trialId));
      ref.invalidate(deletedSessionsProvider);
      ref.invalidate(deletedSessionsForTrialRecoveryProvider(trialId));
      ref.invalidate(openSessionProvider(trialId));
      ref.invalidate(sessionRatingsProvider(session.id));
      ref.invalidate(sessionAssessmentsProvider(session.id));
      ref.invalidate(ratedPlotPksProvider(session.id));
      ref.invalidate(derivedSnapshotForSessionProvider(session.id));
      ref.invalidate(lastSessionContextProvider);
      invalidateTrialReviewProviders(ref, trialId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session moved to Recovery')),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not delete session'),
          content: SelectableText('$e'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _formatSessionTimes(Session session) {
    String fmtTime(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final start = fmtTime(session.startedAt);
    final rater = session.raterName != null ? ' · ${session.raterName}' : '';
    if (session.endedAt != null) {
      final end = fmtTime(session.endedAt!);
      return '$start – $end$rater';
    }
    return 'Started $start$rater';
  }

  String _shortSessionName(String name, String dateLocal) {
    if (name.startsWith(dateLocal)) {
      return name.substring(dateLocal.length).trim();
    }
    return name;
  }

  String _formatDateHeader(String dateStr) {
    try {
      // Use only the date part (YYYY-MM-DD); handle "YYYY-MM-DD HH:mm:ss" or "YYYY-MM-DDTHH:mm:ss".
      final dateOnly = dateStr.length >= 10
          ? dateStr.substring(0, 10)
          : (dateStr.contains(' ')
              ? dateStr.split(' ').first
              : (dateStr.contains('T') ? dateStr.split('T').first : dateStr));
      final parts = dateOnly.split('-');
      if (parts.length != 3) return dateStr;
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final day = int.tryParse(parts[2]);
      final monthIdx = int.tryParse(parts[1]);
      if (day == null || monthIdx == null || monthIdx < 1 || monthIdx > 12) {
        return dateStr;
      }
      final month = months[monthIdx];
      final year = parts[0];
      return '$day $month $year';
    } catch (_) {
      return dateStr;
    }
  }

  Future<_SessionIncompleteAction?> _showSessionIncompleteBlockerDialog(
    BuildContext context,
    Session session,
    SessionCompletenessReport report,
  ) {
    final issueLines =
        report.issues.map(_sessionCloseCompletenessIssueLine).take(15).toList();
    return showDialog<_SessionIncompleteAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session incomplete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incomplete target plots: ${report.incompletePlots} of '
                '${report.expectedPlots}.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Resolve these before closing:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...issueLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsOverflowAlignment: OverflowBarAlignment.start,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionIncompleteAction.keepOpen),
            child: const Text('Keep open'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionIncompleteAction.reviewSession),
            child: const Text('Review session'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionIncompleteAction.plotQueue),
            child: const Text('Open Plot Queue'),
          ),
        ],
      ),
    );
  }

  Future<_SessionCloseAttentionAction?> _showSessionCloseCombinedWarningDialog(
    BuildContext context,
    Session session,
    SessionCompletenessReport report,
    SessionCloseAttentionSummary summary, {
    required bool hasCompletenessWarnings,
    required bool legacyNeedsAttention,
    required List<DiagnosticFinding> contextInfoFindings,
  }) {
    final completenessLines = report.issues
        .where(
          (i) => i.severity == SessionCompletenessIssueSeverity.warning,
        )
        .map(_sessionCloseCompletenessIssueLine)
        .toList();
    final legacyLines = legacyNeedsAttention
        ? _legacySessionCloseAttentionLines(summary)
        : <String>[];

    return showDialog<_SessionCloseAttentionAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close session?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This session still has items you may want to review before closing.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (hasCompletenessWarnings) ...[
                const Text(
                  'Completeness',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...completenessLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (legacyNeedsAttention) const SizedBox(height: 12),
              ],
              if (legacyNeedsAttention) ...[
                const Text(
                  'Navigation and data signals',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...legacyLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              if (contextInfoFindings.isNotEmpty) ...[
                if (hasCompletenessWarnings || legacyNeedsAttention)
                  const SizedBox(height: 12),
                const Text(
                  'For your records',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...contextInfoFindings.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      f.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsOverflowAlignment: OverflowBarAlignment.start,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.keepOpen),
            child: const Text('Keep open'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.reviewSummary),
            child: const Text('Review summary'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.plotQueue),
            child: const Text('Open Plot Queue'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, _SessionCloseAttentionAction.closeAnyway),
            child: const Text('Close anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _runCloseSessionUseCase(
    BuildContext context,
    WidgetRef ref,
    Session session, {
    bool forceClose = false,
  }) async {
    final userId = await ref.read(currentUserIdProvider.future);
    final useCase = ref.read(closeSessionUseCaseProvider);
    final result = await useCase.execute(
      sessionId: session.id,
      trialId: trial.id,
      raterName: session.raterName,
      closedByUserId: userId,
      forceClose: forceClose,
    );
    if (context.mounted) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result.success ? 'Session closed' : result.errorMessage ?? 'Error',
          style: TextStyle(
            color: result.success ? AppDesignTokens.successFg : scheme.onError,
          ),
        ),
        backgroundColor:
            result.success ? AppDesignTokens.successBg : scheme.error,
      ));
      if (result.success && context.mounted) {
        // Auto-open session summary (with data grid) so researcher sees their data.
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SessionSummaryScreen(
              trial: trial,
              session: session,
            ),
          ),
        );
        _checkBackupReminder(context);
      }
    }
  }

  Future<void> _checkBackupReminder(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final store = BackupReminderStore(prefs);
    if (store.mode != BackupReminderMode.afterSessionClose) return;
    if (!store.shouldRemind()) return;
    await store.recordReminderShown();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Back Up Your Data?'),
        content: Text(
          'Last backup: ${store.lastBackupLabel}\n\n'
          'Back up now to keep your trial data safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to More tab which has the backup action.
              // The user taps Backup from there.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Go to More → Backup to save your data'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            child: const Text('Back Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCloseSession(
      BuildContext context, WidgetRef ref, Session session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Session'),
        content: Text(
            'Close session "${session.name}"? You can still view ratings but cannot add new ones.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close Session')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    late final SessionClosePolicyResult policy;
    try {
      policy =
          await ref.read(evaluateSessionClosePolicyUseCaseProvider).execute(
                sessionId: session.id,
                trialId: trial.id,
              );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify session before closing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final report = policy.completenessReport;
    final summary = policy.attentionSummary;
    final hasCompletenessWarnings = report.issues.any(
      (i) => i.severity == SessionCompletenessIssueSeverity.warning,
    );
    final legacyNeedsAttention = summary.needsAttention;

    if (policy.decision == SessionClosePolicyDecision.blocked) {
      final action = await _showSessionIncompleteBlockerDialog(
        context,
        session,
        report,
      );
      if (!context.mounted) return;
      switch (action) {
        case _SessionIncompleteAction.keepOpen:
        case null:
          return;
        case _SessionIncompleteAction.reviewSession:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SessionSummaryScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
        case _SessionIncompleteAction.plotQueue:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PlotQueueScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
      }
    }

    if (!context.mounted) return;

    var forceCloseAfterWarningAck = false;

    if (policy.decision == SessionClosePolicyDecision.warnBeforeClose) {
      final action = await _showSessionCloseCombinedWarningDialog(
        context,
        session,
        report,
        summary,
        hasCompletenessWarnings: hasCompletenessWarnings,
        legacyNeedsAttention: legacyNeedsAttention,
        contextInfoFindings: policy.contextInfoFindings,
      );
      if (!context.mounted) return;
      switch (action) {
        case _SessionCloseAttentionAction.keepOpen:
        case null:
          return;
        case _SessionCloseAttentionAction.reviewSummary:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SessionSummaryScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
        case _SessionCloseAttentionAction.plotQueue:
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PlotQueueScreen(
                trial: trial,
                session: session,
              ),
            ),
          );
          return;
        case _SessionCloseAttentionAction.closeAnyway:
          forceCloseAfterWarningAck = true;
          break;
      }
    }

    if (!context.mounted) return;

    // Fire session-close writers before surfacing the diagnostic.
    await runSessionCloseSignalWriters(
      ref,
      trialId: trial.id,
      sessionId: session.id,
    );

    if (!context.mounted) return;

    final snap = await ref
        .read(weatherSnapshotRepositoryProvider)
        .getWeatherSnapshotForParent(
            kWeatherParentTypeRatingSession, session.id);

    if (!context.mounted) return;

    // Show evidence completeness + signal diagnostic before final close.
    // onAllClear / "Close session" both proceed; "Review plots" cancels.
    var proceedAfterDiagnostic = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (ctx) => SessionCloseDiagnostic(
        sessionId: session.id,
        trialId: trial.id,
        session: session,
        attentionSummary: policy.attentionSummary,
        weatherCaptured: snap != null,
        policyDecision: policy.decision,
        onAllClear: () {
          proceedAfterDiagnostic = true;
          Navigator.of(ctx).pop();
        },
        onProceedAnyway: () {
          proceedAfterDiagnostic = true;
          Navigator.of(ctx).pop();
        },
        onWeatherCapture: () async {
          Navigator.of(ctx).pop();
          await showWeatherCaptureBottomSheet(
            context,
            trial: trial,
            session: session,
          );
          if (context.mounted) _confirmCloseSession(context, ref, session);
        },
      ),
    );
    if (!proceedAfterDiagnostic || !context.mounted) return;

    if (policy.decision == SessionClosePolicyDecision.proceedToClose &&
        policy.contextInfoFindings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Session record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'For your records:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...policy.contextInfoFindings.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      f.message,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
    }

    await _runCloseSessionUseCase(
      context,
      ref,
      session,
      forceClose: forceCloseAfterWarningAck,
    );
  }
}
