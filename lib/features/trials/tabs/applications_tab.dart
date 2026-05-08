import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/field_operation_date_rules.dart';
import '../../../core/connectivity/gps_service.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../domain/application_deviation.dart';
import '../../../shared/layout/responsive_layout.dart';
import '../../../domain/trial_cognition/environmental_window_evaluator.dart';
import '../../../shared/widgets/app_empty_state.dart';
import 'application_assistant_screen.dart';
import 'application_sheet_content.dart';

/// Applications tab for trial detail: list and add/edit application events.
/// Uses trial_application_events only (pending → applied workflow).
class ApplicationsTab extends ConsumerStatefulWidget {
  const ApplicationsTab({super.key, required this.trial});

  final Trial trial;

  @override
  ConsumerState<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends ConsumerState<ApplicationsTab> {
  Future<void> _invalidateSessionTimingForTrialSessions(
    WidgetRef ref,
    int trialId,
  ) async {
    final sessions = await ref.read(sessionsForTrialProvider(trialId).future);
    for (final s in sessions) {
      ref.invalidate(sessionTimingContextProvider(s.id));
    }
  }

  Future<void> _onApplicationDeleted(WidgetRef ref, String eventId) async {
    await ref.read(applicationRepositoryProvider).deleteApplication(eventId);
    ref.invalidate(trialApplicationsForTrialProvider(widget.trial.id));
    await _invalidateSessionTimingForTrialSessions(ref, widget.trial.id);
  }

  Future<void> _deleteApplicationFromSheet({
    required BuildContext sheetContext,
    required WidgetRef ref,
    required String eventId,
  }) async {
    await ref.read(applicationRepositoryProvider).deleteApplication(eventId);
    ref.invalidate(trialApplicationsForTrialProvider(widget.trial.id));
    await _invalidateSessionTimingForTrialSessions(ref, widget.trial.id);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  static const List<String> _rateUnits = [
    'L/ha',
    'kg/ha',
    'g/ha',
    'mL/ha',
    'oz/ac',
  ];

  static const List<String> _applicationMethods = [
    'Ground sprayer',
    'Aerial',
    'Chemigation',
    'Hand application',
    'Granular spreader',
    'Other',
  ];

  static const List<String> _nozzleTypes = [
    'Flat fan',
    'Hollow cone',
    'Flood',
    'Air induction',
    'Rotary atomiser',
    'Other',
  ];
  static const List<String> _pressureUnits = ['PSI', 'kPa', 'bar'];
  static const List<String> _speedUnits = ['km/h', 'mph'];
  static const List<String> _waterVolumeUnits = ['L/ha', 'gal/ac'];
  static const List<String> _adjuvantRateUnits = ['L/ha', 'mL/100L', '% v/v'];
  static const List<String> _treatedAreaUnits = ['ha', 'ac', 'm²'];
  static const List<String> _soilMoistureOptions = [
    'Dry',
    'Moist',
    'Wet',
    'Waterlogged',
  ];

  void _openApplicationsFullScreen() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Applications')),
          body: SafeArea(top: false, child: ApplicationsTab(trial: widget.trial)),
        ),
      ),
    );
  }

  /// Local section header: count + label + fullscreen (matches Assessments tab).
  Widget _applicationsSectionHeader(BuildContext context, {required int count}) {
    final title =
        count == 1 ? '1 application' : '$count applications';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.spacing16,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: AppDesignTokens.sectionHeaderBg,
        border:
            Border(bottom: BorderSide(color: AppDesignTokens.borderCrisp)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 16,
            color: AppDesignTokens.primary,
          ),
          const SizedBox(width: AppDesignTokens.spacing8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.2,
                color: AppDesignTokens.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Full screen',
            icon: const Icon(Icons.fullscreen),
            onPressed: _openApplicationsFullScreen,
          ),
        ],
      ),
    );
  }

  /// Pending first, applied after (recent first).
  List<TrialApplicationEvent> _sorted(List<TrialApplicationEvent> list) {
    final pending = list.where((e) => e.status == 'pending').toList()
      ..sort((a, b) => a.applicationDate.compareTo(b.applicationDate));
    final applied = list.where((e) => e.status == 'applied').toList()
      ..sort((a, b) {
        final aDate = a.appliedAt ?? a.applicationDate;
        final bDate = b.appliedAt ?? b.applicationDate;
        return bDate.compareTo(aDate);
      });
    return [...pending, ...applied];
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync =
        ref.watch(trialApplicationsForTrialProvider(widget.trial.id));
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: applicationsAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () => ref.invalidate(
                    trialApplicationsForTrialProvider(widget.trial.id)),
              ),
              data: (list) {
                final sorted = _sorted(list);
                if (sorted.isEmpty) {
                  return _buildEmpty(context, ref);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _applicationsSectionHeader(context, count: sorted.length),
                    Expanded(child: _buildList(context, ref, sorted)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const AppEmptyState(
          icon: Icons.science,
          title: 'No Applications Yet',
          subtitle: 'Record an application for this trial',
          action: null,
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_application_empty',
            onPressed: () => _showApplicationSheet(context, ref, null),
            backgroundColor: AppDesignTokens.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationTile(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent e,
    int index,
  ) {
    final isPending = e.status == 'pending';
    final hasStageCode = e.growthStageCode?.trim().isNotEmpty == true;
    final hasBbch = e.growthStageBbchAtApplication != null;
    final label = hasStageCode
        ? (hasBbch
            ? '${e.growthStageCode!.trim()} (BBCH ${e.growthStageBbchAtApplication})'
            : e.growthStageCode!.trim())
        : (hasBbch
            ? 'BBCH ${e.growthStageBbchAtApplication}'
            : 'Application ${index + 1}');
    final plannedDateStr = DateFormat('MMM d, yyyy').format(e.applicationDate);
    final productsAsync =
        ref.watch(trialApplicationProductsForEventProvider(e.id));
    final prods = productsAsync.valueOrNull ?? [];

    // Treatment name from linked treatmentId.
    final treatments =
        ref.watch(treatmentsForTrialProvider(widget.trial.id)).valueOrNull ??
            [];
    final linkedTreatment = e.treatmentId != null
        ? treatments
            .where((t) => t.id == e.treatmentId)
            .map((t) => t.code.isNotEmpty ? t.code : t.name)
            .firstOrNull
        : null;

    // Compute deviations from existing domain logic.
    final deviations = prods.isNotEmpty
        ? computeApplicationDeviations(e, prods)
        : <ProductDeviationResult>[];
    final hasAnyDeviation = deviations.any((d) => d.exceedsTolerance);

    // Primary product name.
    final String primaryLine;
    if (prods.isEmpty) {
      primaryLine = e.productName?.trim().isNotEmpty == true
          ? e.productName!.trim()
          : 'No product specified';
    } else {
      primaryLine = prods.first.productName;
    }

    final appliedAtStr = e.appliedAt != null
        ? DateFormat('MMM d, yyyy HH:mm').format(e.appliedAt!)
        : null;

    // Context line: treatment · label · date.
    final contextParts = <String>[
      if (linkedTreatment != null) linkedTreatment,
      label,
      plannedDateStr,
    ];

    // Equipment line (only if any field populated).
    final equipParts = <String>[
      if (e.applicationMethod?.trim().isNotEmpty == true) e.applicationMethod!,
      if (e.nozzleType?.trim().isNotEmpty == true) e.nozzleType!,
      if (e.operatingPressure != null && e.pressureUnit != null)
        '${e.operatingPressure} ${e.pressureUnit}',
      if (e.groundSpeed != null && e.speedUnit != null)
        '${e.groundSpeed} ${e.speedUnit}',
    ];

    // Weather line (only if any field populated).
    final weatherParts = <String>[
      if (e.temperature != null) '${e.temperature!.round()}°',
      if (e.humidity != null) '${e.humidity!.round()}% RH',
      if (e.windSpeed != null)
        '${e.windSpeed} m/s${e.windDirection?.trim().isNotEmpty == true ? ' ${e.windDirection}' : ''}',
      if (e.cloudCoverPct != null) '${e.cloudCoverPct!.round()}% cloud',
    ];

    return Card(
      margin: EdgeInsets.fromLTRB(16, index == 0 ? 6 : 4, 16, 4),
      child: InkWell(
        onTap: () => _showApplicationSheet(context, ref, e),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: product name + status chip.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      primaryLine,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppDesignTokens.primaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (hasAnyDeviation)
                    _DeviationChip()
                  else
                    _StatusChip(isPending: isPending),
                ],
              ),
              const SizedBox(height: 2),

              // Context line: treatment · growth stage · date.
              Text(
                contextParts.join(' · '),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: AppDesignTokens.secondaryText,
                ),
              ),

              // Product rates with deviation info.
              if (prods.isEmpty && e.rate != null) ...[
                const SizedBox(height: 1),
                Text(
                  '${e.rate} ${e.rateUnit ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
              for (var i = 0; i < prods.length; i++)
                _buildProductLine(prods[i],
                    i < deviations.length ? deviations[i] : null),

              // Tank-computed rate (when totalProductMixed + totalAreaSprayedHa populated).
              if (deviations.any((d) => d.tankComputedRate != null)) ...[
                const SizedBox(height: 2),
                Text(
                  'Tank rate: ${deviations.firstWhere((d) => d.tankComputedRate != null).tankComputedRate!.toStringAsFixed(2)} '
                  '(±5% tolerance)',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: AppDesignTokens.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              // Equipment line.
              if (equipParts.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing_outlined,
                        size: 12, color: AppDesignTokens.secondaryText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        equipParts.join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: AppDesignTokens.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Weather line (recorded at application: temp, humidity, wind).
              if (weatherParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined,
                        size: 12, color: AppDesignTokens.secondaryText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        weatherParts.join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: AppDesignTokens.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Environmental window (A3 pre/post windows).
              const SizedBox(height: 2),
              _buildEnvWindowLine(ref, e, isPending),

              const SizedBox(height: 6),

              // Action row.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isPending)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () =>
                              _openAssistant(context, ref, e),
                          child: const Text('Guide'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showApplySheet(context, ref, e),
                          child: const Text('Apply'),
                        ),
                      ],
                    )
                  else
                    Expanded(
                      child: Text(
                        appliedAtStr != null
                            ? 'Applied $appliedAtStr'
                            : 'Applied',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: AppDesignTokens.successFg,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _showApplicationSheet(context, ref, e),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductLine(
      TrialApplicationProduct p, ProductDeviationResult? dev) {
    final ratePart = (p.rate != null && p.rateUnit != null)
        ? '${p.rate} ${p.rateUnit}'
        : (p.rate != null ? '${p.rate}' : null);
    if (ratePart == null) return const SizedBox.shrink();

    final parts = <InlineSpan>[];
    parts.add(TextSpan(text: ratePart));

    if (dev != null && dev.plannedRate != null && dev.deviationPct != null) {
      final devLabel = deviationLabel(dev.deviationPct);
      final devColor = dev.exceedsTolerance
          ? AppDesignTokens.warningFg
          : AppDesignTokens.successFg;
      parts.add(TextSpan(
        text: ' (planned: ${dev.plannedRate} · $devLabel)',
        style: TextStyle(color: devColor),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            color: AppDesignTokens.secondaryText,
          ),
          children: parts,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _openAssistant(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent e,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApplicationAssistantScreen(
          trial: widget.trial,
          applicationEvent: e,
          onMarkAsApplied: () => _showApplySheet(context, ref, e),
        ),
      ),
    );
  }

  Future<void> _showApplySheet(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent e,
  ) async {
    final trial =
        ref.read(trialProvider(widget.trial.id)).valueOrNull ?? widget.trial;
    final seedingEvent =
        await ref.read(seedingEventForTrialProvider(trial.id).future);
    if (!context.mounted) return;
    final minD = minimumApplicationOrAppliedDate(
      trialCreatedAt: trial.createdAt,
      seedingDate: seedingEvent?.seedingDate,
    );
    final maxD = dateOnlyLocal(DateTime.now());
    var selectedDate = dateOnlyLocal(DateTime.now());
    if (selectedDate.isBefore(minD)) selectedDate = minD;
    if (selectedDate.isAfter(maxD)) selectedDate = maxD;
    var selectedTime = TimeOfDay.now();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dateStr = DateFormat('MMM d, yyyy').format(selectedDate);
            final timeStr =
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Mark as applied',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: minD,
                                  lastDate: maxD,
                                );
                                if (d != null) {
                                  setSheetState(() => selectedDate = d);
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(dateStr),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: ctx,
                                  initialTime: selectedTime,
                                );
                                if (t != null) {
                                  setSheetState(() => selectedTime = t);
                                }
                              },
                              icon: const Icon(Icons.access_time, size: 18),
                              label: Text(timeStr),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed == true && context.mounted) {
      final appliedAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      final appliedErr = validateAppliedDateTime(
        appliedAt: appliedAt,
        trialCreatedAt: trial.createdAt,
        seedingDate: seedingEvent?.seedingDate,
      );
      final clockErr = validateAppliedTimestampNotInFuture(appliedAt);
      if (appliedErr != null || clockErr != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appliedErr ?? clockErr!),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final userId = await ref.read(currentUserIdProvider.future);
      final user = await ref.read(currentUserProvider.future);
      try {
        await ref.read(applicationRepositoryProvider).markApplicationApplied(
              id: e.id,
              appliedAt: appliedAt,
              performedBy: user?.displayName,
              performedByUserId: userId,
            );
      } on OperationalDateRuleException catch (ex) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ex.message),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      unawaited(_captureApplicationWeatherAndGps(e.id, widget.trial.id, appliedAt));
      ref.invalidate(trialApplicationsForTrialProvider(widget.trial.id));
      await _invalidateSessionTimingForTrialSessions(ref, widget.trial.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application marked as applied.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _captureApplicationWeatherAndGps(
    String applicationId,
    int trialId,
    DateTime appliedAt,
  ) async {
    try {
      final gps = await GpsService.getCurrentPosition(
        timeout: const Duration(seconds: 3),
      );
      if (gps == null) return;
      await ref.read(applicationRepositoryProvider).updateApplicationGps(
            applicationId: applicationId,
            latitude: gps.latitude,
            longitude: gps.longitude,
          );
      await ref
          .read(applicationWeatherBackfillServiceProvider)
          .queueApplicationWeatherBackfill(
            applicationId: applicationId,
            trialId: trialId,
            latitude: gps.latitude,
            longitude: gps.longitude,
            appliedAt: appliedAt,
          );
    } catch (_) {
      // Never propagate — GPS/weather must not affect the apply action.
    }
  }

  Widget _buildEnvWindowLine(
    WidgetRef ref,
    TrialApplicationEvent e,
    bool isPending,
  ) {
    if (isPending) {
      return const Text(
        'Environmental window available after application is confirmed.',
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          color: AppDesignTokens.secondaryText,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final request = ApplicationEnvironmentalRequest(
      trialId: widget.trial.id,
      applicationEventId: e.id,
    );
    final ctxAsync = ref.watch(applicationEnvironmentalContextProvider(request));

    return ctxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ctx) {
        if (ctx.isUnavailable) {
          return const Text(
            'Environmental window unavailable.',
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: AppDesignTokens.secondaryText,
            ),
          );
        }
        final pre = ctx.preWindow;
        final post = ctx.postWindow;
        final preStr = pre.recordCount == 0
            ? 'no records'
            : '${pre.totalPrecipitationMm?.toStringAsFixed(1) ?? '—'} mm';
        final postStr = post.recordCount == 0
            ? 'no records'
            : '${post.totalPrecipitationMm?.toStringAsFixed(1) ?? '—'} mm';
        return Row(
          children: [
            const Icon(Icons.water_drop_outlined,
                size: 12, color: AppDesignTokens.secondaryText),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '72h pre: $preStr · 48h post: $postStr',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: AppDesignTokens.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<TrialApplicationEvent> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  0,
                  0,
                  80,
                ),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final e = list[index];
                  return Dismissible(
                    key: Key(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Application?'),
                          content: const Text(
                            'This application will be permanently deleted.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (_) {
                      unawaited(_onApplicationDeleted(ref, e.id));
                    },
                    child: _buildApplicationTile(context, ref, e, index),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'add_application',
                  onPressed: () => _showApplicationSheet(context, ref, null),
                  backgroundColor: AppDesignTokens.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showApplicationSheet(
    BuildContext context,
    WidgetRef ref,
    TrialApplicationEvent? existing,
  ) async {
    if (!context.mounted) return;
    final scrollController = ScrollController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppDesignTokens.cardSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          final insetBottom = mq.viewInsets.bottom;
          final maxH = (mq.size.height - insetBottom).clamp(0.0, mq.size.height);
          final sheetH = maxH <= 0
              ? mq.size.height * 0.7
              : (maxH * 0.92).clamp(280.0, maxH);
          final rl = ResponsiveLayout.of(ctx);
          final maxW = rl.modalSheetMaxWidth;

          return Padding(
            padding: EdgeInsets.only(bottom: insetBottom),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: sheetH,
                  maxWidth: maxW.isInfinite ? double.infinity : maxW,
                ),
                child: ApplicationSheetContent(
                  trial: widget.trial,
                  existing: existing,
                  scrollController: scrollController,
                  rateUnits: _rateUnits,
                  applicationMethods: _applicationMethods,
                  nozzleTypes: _nozzleTypes,
                  pressureUnits: _pressureUnits,
                  speedUnits: _speedUnits,
                  waterVolumeUnits: _waterVolumeUnits,
                  adjuvantRateUnits: _adjuvantRateUnits,
                  treatedAreaUnits: _treatedAreaUnits,
                  soilMoistureOptions: _soilMoistureOptions,
                  onSaved: () {
                    ref.invalidate(
                        trialApplicationsForTrialProvider(widget.trial.id));
                    ref.invalidate(
                        trialCriticalToQualityProvider(widget.trial.id));
                    unawaited(
                        _invalidateSessionTimingForTrialSessions(
                            ref, widget.trial.id));
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  onDelete: existing != null
                      ? () {
                          unawaited(_deleteApplicationFromSheet(
                            sheetContext: ctx,
                            ref: ref,
                            eventId: existing.id,
                          ));
                        }
                      : null,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      scrollController.dispose();
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPending});

  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPending
            ? AppDesignTokens.emptyBadgeBg
            : AppDesignTokens.successBg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
      ),
      child: Text(
        isPending ? 'Pending' : 'Applied',
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: isPending
              ? AppDesignTokens.secondaryText
              : AppDesignTokens.successFg,
        ),
      ),
    );
  }
}

class _DeviationChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesignTokens.warningBg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusChip),
        border: Border.all(color: AppDesignTokens.warningBorder, width: 0.5),
      ),
      child: const Text(
        'Deviation',
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: AppDesignTokens.warningFg,
        ),
      ),
    );
  }
}
