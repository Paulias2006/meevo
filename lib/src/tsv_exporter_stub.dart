import 'package:flutter/services.dart';

Future<bool> exportTsvFile({
  required String filename,
  required String content,
}) async {
  await Clipboard.setData(ClipboardData(text: content));
  return true;
}
