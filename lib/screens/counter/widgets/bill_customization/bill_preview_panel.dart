import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class BillPreviewPanel extends StatelessWidget {
  final String previewFormat;
  final Uint8List? previewBytes;
  final bool isGenerating;
  final ValueChanged<String> onFormatChanged;
  final VoidCallback onGeneratePreview;

  const BillPreviewPanel({
    super.key,
    required this.previewFormat,
    required this.previewBytes,
    required this.isGenerating,
    required this.onFormatChanged,
    required this.onGeneratePreview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 16,
              spacing: 16,
              children: [
                Text(
                  'Live Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ToggleButtons(
                      isSelected: [
                        previewFormat == 'Thermal',
                        previewFormat == 'A4',
                        previewFormat == 'A5',
                      ],
                      onPressed: (index) {
                        final newFormat = index == 0
                            ? 'Thermal'
                            : (index == 1 ? 'A4' : 'A5');
                        onFormatChanged(newFormat);
                      },
                      borderRadius: BorderRadius.circular(8),
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      selectedColor: isDark
                          ? const Color(0xFF052E16)
                          : const Color(0xFF22C55E),
                      fillColor: isDark
                          ? Colors.transparent
                          : const Color(0xFFF1F8F5),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Thermal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'A4',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'A5',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: isGenerating ? null : onGeneratePreview,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Generate Preview'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: previewBytes == null
                  ? const Center(
                      child: Text(
                        'Click "Generate Preview" to see the bill format',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : PdfPreview(
                      build: (format) async => previewBytes!,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      allowPrinting: false,
                      allowSharing: false,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
