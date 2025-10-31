import 'dart:async';
import 'package:flutter/services.dart';

Future<void> exportFile(String filename, String content) async {
  // Fallback for non-web: copy content to clipboard and let user save it manually
  await Clipboard.setData(ClipboardData(text: content));
  // No file save capability here; caller should inform the user
}

Future<String?> pickFileAndRead() async {
  // No platform file-picker available in this stub. Return null so caller can fallback to paste dialog.
  return null;
}
