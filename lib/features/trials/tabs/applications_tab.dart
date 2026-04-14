import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/app_design_tokens.dart';
import '../../../core/field_operation_date_rules.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_standard_widgets.dart';
import '../../../core/widgets/loading_error_widgets.dart';
import '../../../shared/widgets/app_empty_state.dart';
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
    return Column(
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
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const Expanded(
          child: AppEmptyState(
            icon: Icons.science,
            title: 'No Applications Yet',
            subtitle: 'Record an application for this trial',
            action: null,
          ),
        ),
        TabListBottomAddButton(
          label: 'Add Application',
          onPressed: () => _showApplicationSheet(context, ref, null),
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
    final label = e.growthStageCode?.trim().isNotEmpty == true
        ? e.growthStageCode!.trim()
        : 'Application ${index + 1}';
    final plannedDateStr = DateFormat('MMM d, yyyy').format(e.applicationDate);
    final productsAsync =
        ref.watch(trialApplicationProductsForEventProvider(e.id));
    final prods = productsAsync.valueOrNull;
    final String primaryLine;
    final String? rateLine;
    if (prods == null || prods.isEmpty) {
      primaryLine = e.productName?.trim().isNotEmpty == true
          ? e.productName!.trim()
          : 'No product specified';
      rateLine = (e.rate != null && e.rateUnit != null)
          ? '${e.rate} ${e.rateUnit}'
          : null;
    } else if (prods.length == 1) {
      final p = prods.first;
      primaryLine = p.productName;
      rateLine = (p.rate != null && p.rateUnit != null)
          ? '${p.rate} ${p.rateUnit}'
          : (p.rate != null ? '${p.rate}' : null);
    } else {
      primaryLine = '${prods.first.productName} + ${prods.length - 1} more';
      rateLine = '${prods.length} products';
    }
    final appliedAtStr = e.appliedAt != null
        ? DateFormat('MMM d, yyyy HH:mm').format(e.appliedAt!)
        : null;

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
                  _StatusChip(isPending: isPending),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$label · $plannedDateStr',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: AppDesignTokens.secondaryText,
                ),
              ),
              if (rateLine != null) ...[
                const SizedBox(height: 1),
                Text(
                  rateLine,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: AppDesignTokens.secondaryText,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isPending)
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
                      child: const Text('Apply Now'),
                    )
                  else
                    Expanded(
                      child: Text(
                        appliedAtStr != null
                            ? 'Applied on $appliedAtStr'
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
                child: FloatingActionButton.extended(
                  heroTag: 'add_application',
                  onPressed: () => _showApplicationSheet(context, ref, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Application'),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => ApplicationSheetContent(
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
              unawaited(
                  _invalidateSessionTimingForTrialSessions(ref, widget.trial.id));
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
