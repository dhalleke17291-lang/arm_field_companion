import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/widgets/gradient_screen_header.dart';

class AuditLogScreen extends ConsumerWidget {
  final int limit;

  const AuditLogScreen({super.key, this.limit = 500});

  Future<void> _export(BuildContext context, List<AuditEvent> events) async {
    final buffer = StringBuffer();
    buffer.writeln('Audit Log');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Rows: ${events.length}');
    buffer.writeln('');

    buffer.writeln('created_at,event_type,trial_id,session_id,plot_pk,performed_by,description');
    for (final e in events) {
      buffer.writeln(_csvRow([
        e.createdAt.toIso8601String(),
        e.eventType,
        e.trialId?.toString() ?? '',
        e.sessionId?.toString() ?? '',
        e.plotPk?.toString() ?? '',
        e.performedBy ?? '',
        e.description,
      ]));
    }

    try {
      await Share.share(
        buffer.toString(),
        subject: 'Audit log ${DateTime.now().toIso8601String().substring(0, 10)}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Export opened')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static String _csvRow(List<String> values) {
    return values.map(_csvEscape).join(',');
  }

  static String _csvEscape(String v) {
    final needsQuotes = v.contains(',') || v.contains('\n') || v.contains('"');
    if (!needsQuotes) return v;
    final escaped = v.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    final stream = (db.select(db.auditEvents)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();

    return StreamBuilder<List<AuditEvent>>(
      stream: stream,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <AuditEvent>[];

        return Scaffold(
          backgroundColor: const Color(0xFFF4F1EB),
          appBar: GradientScreenHeader(
            title: 'Audit log',
            subtitle: 'Recent events',
            titleFontSize: 18,
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                tooltip: 'Export audit log',
                onPressed: events.isEmpty ? null : () => _export(context, events),
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : events.isEmpty
                  ? const Center(child: Text('No audit events recorded yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = events[i];
                        final subtitle = <String>[
                          if (e.trialId != null) 'Trial ${e.trialId}',
                          if (e.sessionId != null) 'Session ${e.sessionId}',
                          if (e.plotPk != null) 'Plot ${e.plotPk}',
                        ].join(' · ');
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.history_outlined),
                            title: Text(
                              e.eventType,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  e.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  e.createdAt.toIso8601String().substring(0, 19),
                                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                                ),
                              ],
                            ),
                            trailing: e.performedBy == null
                                ? null
                                : Text(
                                    e.performedBy!,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
