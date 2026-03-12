import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../../core/app_info.dart';
import '../data/export_repository.dart';

/// Result of an ARM XML export. Use [success] for UI.
class ArmXmlExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  const ArmXmlExportResult._({
    required this.success,
    this.filePath,
    this.errorMessage,
  });

  factory ArmXmlExportResult.ok(String filePath) =>
      ArmXmlExportResult._(success: true, filePath: filePath);

  factory ArmXmlExportResult.failure(String message) =>
      ArmXmlExportResult._(success: false, errorMessage: message);
}

/// Export a closed session to ARM-style XML.
/// Structure is schema-agnostic (placeholder until real ARM schema is provided).
/// Pre-export validation: session must be closed.
class ExportSessionArmXmlUsecase {
  final ExportRepository repo;

  ExportSessionArmXmlUsecase(this.repo);

  /// Same contract as CSV export for consistency. [isSessionClosed] required for export.
  Future<ArmXmlExportResult> exportSessionToArmXml({
    required int sessionId,
    required int trialId,
    required String trialName,
    required String sessionName,
    required String sessionDateLocal,
    String? sessionRaterName,
    String? exportedByDisplayName,
    bool isSessionClosed = true,
    bool requireSessionClosed = true,
  }) async {
    try {
      if (requireSessionClosed && !isSessionClosed) {
        return ArmXmlExportResult.failure(
          'Session must be closed before export. Close the session first.',
        );
      }

      final rows = await repo.buildSessionExportRows(sessionId: sessionId);
      final exportTimestampUtc = DateTime.now().toUtc().toIso8601String();

      // Unique treatment ids (for single emit per treatment)
      final treatmentKeys = <int?>{};
      for (final m in rows) {
        treatmentKeys.add(m['treatment_id'] as int?);
      }

      final builder = XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="UTF-8"');
      builder.element('arm_export', nest: () {
        builder.attribute('version', '1.0');
        builder.attribute('source', 'ARM Field Companion');
        builder.attribute('app_version', kAppVersion);
        builder.attribute('export_timestamp_utc', exportTimestampUtc);
        if (exportedByDisplayName != null) {
          builder.attribute('exported_by', exportedByDisplayName);
        }

        builder.element('trial', nest: () {
          builder.attribute('id', trialId.toString());
          builder.element('name', nest: trialName);
        });

        builder.element('session', nest: () {
          builder.attribute('id', sessionId.toString());
          builder.element('name', nest: sessionName);
          builder.element('session_date_local', nest: sessionDateLocal);
          if (sessionRaterName != null && sessionRaterName.isNotEmpty) {
            builder.element('rater_name', nest: sessionRaterName);
          }
        });

        builder.element('treatments', nest: () {
          for (final m in rows) {
            final tid = m['treatment_id'] as int?;
            if (tid == null) continue;
            final code = m['treatment_code']?.toString() ?? '';
            final name = m['treatment_name']?.toString() ?? '';
            if (treatmentKeys.contains(tid)) {
              treatmentKeys.remove(tid);
              builder.element('treatment', nest: () {
                builder.attribute('id', tid.toString());
                builder.element('code', nest: code);
                builder.element('name', nest: name);
              });
            }
          }
        });

        builder.element('assessments', nest: () {
          final seen = <int>{};
          for (final m in rows) {
            final aid = m['assessment_id'] as int;
            if (seen.contains(aid)) continue;
            seen.add(aid);
            final name = m['assessment_name']?.toString() ?? '';
            final unit = m['unit']?.toString();
            builder.element('assessment', nest: () {
              builder.attribute('id', aid.toString());
              builder.element('name', nest: name);
              if (unit != null && unit.isNotEmpty) {
                builder.element('unit', nest: unit);
              }
            });
          }
        });

        builder.element('plots', nest: () {
          final seen = <int>{};
          for (final m in rows) {
            final plotPk = m['plot_pk'] as int;
            if (seen.contains(plotPk)) continue;
            seen.add(plotPk);
            final plotId = m['plot_id']?.toString() ?? '';
            final rep = m['rep']?.toString();
            final treatmentId = m['treatment_id']?.toString();
            final treatmentCode = m['treatment_code']?.toString();
            builder.element('plot', nest: () {
              builder.attribute('plot_pk', plotPk.toString());
              builder.element('plot_id', nest: plotId);
              if (rep != null) builder.element('rep', nest: rep);
              if (treatmentId != null) builder.element('treatment_id', nest: treatmentId);
              if (treatmentCode != null) builder.element('treatment_code', nest: treatmentCode);
            });
          }
        });

        builder.element('ratings', nest: () {
          for (final m in rows) {
            final status = m['effective_result_status']?.toString() ?? m['result_status']?.toString() ?? '';
            final numVal = m['effective_numeric_value'] ?? m['numeric_value'];
            final textVal = m['effective_text_value'] ?? m['text_value'];
            builder.element('rating', nest: () {
              builder.attribute('plot_pk', (m['plot_pk'] as int).toString());
              builder.attribute('assessment_id', (m['assessment_id'] as int).toString());
              builder.element('result_status', nest: status);
              if (numVal != null) builder.element('numeric_value', nest: numVal.toString());
              if (textVal != null && textVal.toString().isNotEmpty) {
                builder.element('text_value', nest: textVal.toString());
              }
              if (m['rater_name'] != null) {
                builder.element('rater_name', nest: m['rater_name'].toString());
              }
              builder.element('created_at', nest: (m['created_at'] ?? '').toString());
            });
          }
        });
      });

      final doc = builder.buildDocument();
      final xmlString = doc.toXmlString(pretty: true);

      final path = await _writeXml(
        sessionId: sessionId,
        trialName: trialName,
        sessionName: sessionName,
        xml: xmlString,
      );

      return ArmXmlExportResult.ok(path);
    } catch (e, st) {
      return ArmXmlExportResult.failure(
        'ARM XML export failed: ${e.toString()}\n${st.toString().split('\n').take(3).join('\n')}',
      );
    }
  }

  Future<String> _writeXml({
    required int sessionId,
    required String trialName,
    required String sessionName,
    required String xml,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTrial = _safeFilePart(trialName);
    final safeSession = _safeFilePart(sessionName);
    final file = File(
      '${dir.path}/AFC_arm_export_${safeTrial}_${safeSession}_session_$sessionId.xml',
    );
    await file.writeAsString(xml, flush: true);
    return file.path;
  }

  String _safeFilePart(String s) {
    return s
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
