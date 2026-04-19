import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/export_guard.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';
import 'audit_log_enrichment.dart';
import 'audit_log_pdf_export.dart';

enum AuditLogSort {
  dateNewest,
  dateOldest,
  name,
  trial,
  session,
  plot,
  eventType,
}

extension on AuditLogSort {
  String get label {
    switch (this) {
      case AuditLogSort.dateNewest:
        return 'Date (newest)';
      case AuditLogSort.dateOldest:
        return 'Date (oldest)';
      case AuditLogSort.name:
        return 'Name (who)';
      case AuditLogSort.trial:
        return 'Trial';
      case AuditLogSort.session:
        return 'Session';
      case AuditLogSort.plot:
        return 'Plot';
      case AuditLogSort.eventType:
        return 'Event type';
    }
  }
}

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key, this.limit = 500, this.trialId});

  /// When set, only [audit_events] rows for this trial are shown (same sort/export/enrichment).
  final int? trialId;

  final int limit;

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  AuditLogSort _sort = AuditLogSort.dateNewest;

  List<EnrichedAuditEvent> _applySort(List<EnrichedAuditEvent> list) {
    final copy = List<EnrichedAuditEvent>.from(list);
    switch (_sort) {
      case AuditLogSort.dateNewest:
        copy.sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));
        break;
      case AuditLogSort.dateOldest:
        copy.sort((a, b) => a.event.createdAt.compareTo(b.event.createdAt));
        break;
      case AuditLogSort.name:
        copy.sort((a, b) {
          final na = a.event.performedBy ?? '';
          final nb = b.event.performedBy ?? '';
          final c = na.compareTo(nb);
          return c != 0 ? c : b.event.createdAt.compareTo(a.event.createdAt);
        });
        break;
      case AuditLogSort.trial:
        copy.sort((a, b) {
          final na = a.trialName ?? '';
          final nb = b.trialName ?? '';
          final c = na.compareTo(nb);
          return c != 0 ? c : b.event.createdAt.compareTo(a.event.createdAt);
        });
        break;
      case AuditLogSort.session:
        copy.sort((a, b) {
          final na = a.sessionName ?? '';
          final nb = b.sessionName ?? '';
          final c = na.compareTo(nb);
          return c != 0 ? c : b.event.createdAt.compareTo(a.event.createdAt);
        });
        break;
      case AuditLogSort.plot:
        copy.sort((a, b) {
          final na = a.plotLabel ?? '';
          final nb = b.plotLabel ?? '';
          final c = na.compareTo(nb);
          return c != 0 ? c : b.event.createdAt.compareTo(a.event.createdAt);
        });
        break;
      case AuditLogSort.eventType:
        copy.sort((a, b) {
          final c = a.event.eventType.compareTo(b.event.eventType);
          return c != 0 ? c : b.event.createdAt.compareTo(a.event.createdAt);
        });
        break;
    }
    return copy;
  }

  /// Exports **all** matching rows from the database (not limited to [widget.limit]).
  Future<void> _exportFull(BuildContext context) async {
    final guard = ref.read(exportGuardProvider);
    final ran = await guard.runExclusive(() async {
      if (!context.mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppDesignTokens.cardSurface,
            content: Row(
              children: [
                const CircularProgressIndicator(color: AppDesignTokens.primary),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Building PDF export…',
                    style: TextStyle(
                      color: AppDesignTokens.primaryText.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      try {
        final db = ref.read(databaseProvider);
        final q = db.select(db.auditEvents);
        final tid = widget.trialId;
        if (tid != null) {
          q.where((t) => t.trialId.equals(tid));
        }
        q.orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]);
        final events = await q.get();
        nav.pop();

        if (events.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nothing to export.')),
            );
          }
          return;
        }

        final pdfBytes = await AuditLogPdfExport(
          events: events,
          scopeDescription: widget.trialId != null
              ? 'Trial id ${widget.trialId} only'
              : 'All trials',
        ).build();

        final tempDir = await getTemporaryDirectory();
        final safeStamp =
            DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
        final filePath = p.join(
          tempDir.path,
          widget.trialId != null
              ? 'trial_${widget.trialId}_audit_$safeStamp.pdf'
              : 'agnexis_audit_$safeStamp.pdf',
        );
        await File(filePath).writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/pdf')],
          subject: widget.trialId != null
              ? 'Trial activity export ${DateTime.now().toIso8601String().substring(0, 10)}'
              : 'Audit log export ${DateTime.now().toIso8601String().substring(0, 10)}',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported ${events.length} events as PDF'),
            ),
          );
        }
      } catch (e) {
        if (nav.canPop()) nav.pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
    if (!ran && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ExportGuard.busyMessage)),
      );
    }
  }

  /// Replaces raw plotPk in description with display label (e.g. 101) when available.
  static String _descriptionWithPlotLabel(
    String description, {
    required int? plotPk,
    required String? plotLabel,
  }) {
    if (plotPk == null || plotLabel == null || plotLabel.isEmpty) {
      return description;
    }
    // Replace "plot 40" / "plot 40" patterns so UI shows "plot 101" instead of raw ID.
    final pattern = RegExp('plot\\s+$plotPk\\b', caseSensitive: false);
    return description.replaceAll(pattern, 'plot $plotLabel');
  }

  /// Format time for list: "11 Mar 2026, 11:10 PM".
  static String _formatDateTime(DateTime at) {
    const months = [
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
    final hour = at.hour == 0 ? 12 : (at.hour > 12 ? at.hour - 12 : at.hour);
    final ampm = at.hour < 12 ? 'AM' : 'PM';
    final min = at.minute.toString().padLeft(2, '0');
    final month = at.month >= 1 && at.month <= 12 ? months[at.month - 1] : '';
    return '${at.day} $month ${at.year}, $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final trialRepo = ref.watch(trialRepositoryProvider);
    final sessionRepo = ref.watch(sessionRepositoryProvider);
    final plotRepo = ref.watch(plotRepositoryProvider);

    final scoped = widget.trialId != null;
    final title = scoped ? 'Activity' : 'Audit log';
    final subtitle = scoped
        ? 'This trial · export = full history (PDF)'
        : 'Latest ${widget.limit} on screen · export = full history (PDF)';

    final stream = () {
      final q = db.select(db.auditEvents);
      final tid = widget.trialId;
      if (tid != null) {
        q.where((t) => t.trialId.equals(tid));
      }
      q
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
        ..limit(widget.limit);
      return q.watch();
    }();

    return StreamBuilder<List<AuditEvent>>(
      stream: stream,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <AuditEvent>[];

        if (snapshot.connectionState == ConnectionState.waiting &&
            events.isEmpty) {
          return Scaffold(
            backgroundColor: AppDesignTokens.backgroundSurface,
            appBar: GradientScreenHeader(title: title),
            body: const SafeArea(top: false, child: Center(child: CircularProgressIndicator())),
          );
        }

        if (events.isEmpty) {
          return Scaffold(
            backgroundColor: AppDesignTokens.backgroundSurface,
            appBar: GradientScreenHeader(title: title),
            body: SafeArea(top: false, child: Center(
              child: Text(
                scoped
                    ? 'No audit events recorded for this trial yet.'
                    : 'No audit events recorded yet.',
                style: const TextStyle(color: AppDesignTokens.secondaryText),
              ),
            )),
          );
        }

        return Scaffold(
          backgroundColor: AppDesignTokens.backgroundSurface,
          appBar: GradientScreenHeader(
            title: title,
            subtitle: subtitle,
            
            actions: [
              PopupMenuButton<AuditLogSort>(
                icon: const Icon(Icons.sort, color: Colors.white),
                tooltip: 'Sort by',
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => AuditLogSort.values
                    .map((s) => PopupMenuItem<AuditLogSort>(
                          value: s,
                          child: Text(s.label),
                        ))
                    .toList(),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.white),
                tooltip: 'Export full history as PDF',
                onPressed: () => _exportFull(context),
              ),
            ],
          ),
          body: SafeArea(top: false, child: FutureBuilder<List<EnrichedAuditEvent>>(
            future: enrichAuditEvents(
              events,
              trialRepo: trialRepo,
              sessionRepo: sessionRepo,
              plotRepo: plotRepo,
            ),
            builder: (context, enrichSnapshot) {
              if (!enrichSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final enriched = enrichSnapshot.data!;
              final sorted = _applySort(enriched);

              return ListView.separated(
                padding: const EdgeInsets.all(AppDesignTokens.spacing16),
                itemCount: sorted.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDesignTokens.spacing12),
                itemBuilder: (context, i) {
                  final item = sorted[i];
                  final e = item.event;
                  final contextLine = item.contextLine;
                  // Show display label (e.g. 101) instead of raw plotPk in description when available.
                  final displayDescription = _descriptionWithPlotLabel(
                    e.description,
                    plotPk: e.plotPk,
                    plotLabel: item.plotLabel,
                  );
                  return Container(
                    padding: const EdgeInsets.all(AppDesignTokens.spacing16),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.cardSurface,
                      borderRadius:
                          BorderRadius.circular(AppDesignTokens.radiusCard),
                      border: Border.all(color: AppDesignTokens.borderCrisp),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppDesignTokens.primaryTint,
                                borderRadius: BorderRadius.circular(
                                    AppDesignTokens.radiusXSmall),
                              ),
                              child: const Icon(
                                Icons.history_outlined,
                                size: 20,
                                color: AppDesignTokens.primary,
                              ),
                            ),
                            const SizedBox(width: AppDesignTokens.spacing12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.eventType,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppDesignTokens.primaryText,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (e.performedBy != null &&
                                      e.performedBy!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      e.performedBy!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppDesignTokens.secondaryText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignTokens.spacing8),
                        Text(
                          displayDescription,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppDesignTokens.primaryText,
                            height: 1.35,
                          ),
                        ),
                        if (contextLine.isNotEmpty) ...[
                          const SizedBox(height: AppDesignTokens.spacing8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDesignTokens.spacing8,
                              vertical: AppDesignTokens.spacing4,
                            ),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.sectionHeaderBg,
                              borderRadius: BorderRadius.circular(
                                  AppDesignTokens.radiusXSmall),
                            ),
                            child: Text(
                              contextLine,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.primaryText,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDesignTokens.spacing8),
                        Text(
                          _formatDateTime(e.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          )),
        );
      },
    );
  }
}
