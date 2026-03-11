import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/widgets/gradient_screen_header.dart';

class ImportedProtocolFileScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const ImportedProtocolFileScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<ImportedProtocolFileScreen> createState() =>
      _ImportedProtocolFileScreenState();
}

class _ImportedProtocolFileScreenState extends State<ImportedProtocolFileScreen> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.filePath);
      final exists = await file.exists();
      if (!exists) {
        setState(() => _error = 'File missing: ${widget.filePath}');
        return;
      }
      final txt = await file.readAsString();
      if (!mounted) return;
      setState(() => _content = txt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EB),
      appBar: GradientScreenHeader(
        title: widget.title ?? 'Imported protocol file',
        subtitle: 'Read-only',
        titleFontSize: 18,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _content == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _content!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
