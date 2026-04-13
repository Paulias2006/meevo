import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> exportTsvFile({
  required String filename,
  required String content,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(content);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)]),
  );
  return true;
}
