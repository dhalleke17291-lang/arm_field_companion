import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../export/export_format.dart';

class ExportFormatSheet extends ConsumerStatefulWidget {
  const ExportFormatSheet({
    super.key,
    required this.trial,
    required this.allowedFormats,
  });
  final Trial trial;
  final List<ExportFormat> allowedFormats;

  @override
  ConsumerState<ExportFormatSheet> createState() => _ExportFormatSheetState();
}

class _ExportFormatSheetState extends ConsumerState<ExportFormatSheet> {
  ExportFormat _selected = ExportFormat.armHandoff;

  @override
  void initState() {
    super.initState();
    _initSelected(widget.allowedFormats);
  }

  @override
  void didUpdateWidget(covariant ExportFormatSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allowedFormats != widget.allowedFormats) {
      _initSelected(widget.allowedFormats);
    }
  }

  void _initSelected(List<ExportFormat> allowed) {
    if (allowed.isEmpty) {
      _selected = ExportFormat.flatCsv;
      return;
    }
    _selected = allowed.contains(_selected) ? _selected : allowed.first;
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.allowedFormats;
    if (allowed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No export options available for this trial.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Export',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Choose a format for ${widget.trial.name}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        ...allowed.map((format) {
          final isSelected = _selected == format;
          return InkWell(
            onTap: () => setState(() => _selected = format),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F5EE) : Colors.white,
                border: const Border(
                  bottom: BorderSide(
                    color: Color(0xFFF0EDE8),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    format.icon,
                    color: isSelected
                        ? const Color(0xFF2D5A40)
                        : Colors.grey.shade400,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              format.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF2D5A40)
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            if (format.badge.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D5A40),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  format.badge,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          format.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (format == ExportFormat.evidenceReport) ...[
                          const SizedBox(height: 6),
                          Text(
                            'For session-level execution review and '
                            'defensibility, export the Session Field Execution '
                            'Report from the session summary screen.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2D5A40),
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5A40),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text(
                'Export',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
