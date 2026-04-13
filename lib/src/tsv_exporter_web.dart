// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<bool> exportTsvFile({
  required String filename,
  required String content,
}) async {
  final blob = html.Blob([content], 'text/tab-separated-values');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
  return true;
}
