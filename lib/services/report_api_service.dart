// lib/services/report_api_service.dart
//
// Fully on-device report generation. No HTTP, no server.
// Wraps PdfReportGenerator, writes the PDF bytes to device storage,
// and returns the saved file path.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/enriched_scan_result.dart';
import 'pdf_report_generator.dart';

class ReportApiService {
  ReportApiService._();
  static final ReportApiService instance = ReportApiService._();

  /// Generate the PDF on device and save it. Returns the file path.
  Future<String> generateAndDownload(EnrichedScanResult data) async {
    final bytes = await PdfReportGenerator.instance.build(data);
    final reportId =
        'REP${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final dir = await _downloadDir();
    final filePath = '${dir.path}/SolarMitra_Report_$reportId.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<Directory> _downloadDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return getApplicationDocumentsDirectory();
  }
}
