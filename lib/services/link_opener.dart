// lib/services/link_opener.dart
//
// Opens an external URL in the device browser/appropriate app using
// url_launcher. Surfaces a snackbar on failure.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<void> openExternalLink(
  String url, {
  BuildContext? context,
  String? label,
}) async {
  final ok = await launchExternal(url);
  if (!ok && context != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open ${label ?? url}'),
      ),
    );
  }
}