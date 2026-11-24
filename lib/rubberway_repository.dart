import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RubberwayRepository {
  static Future<Directory> getRubberwayDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory("${base.path}/Rubberway");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<File>> getAllPdfs() async {
    final dir = await getRubberwayDir();
    final all = dir.listSync();

    final pdfs = all
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith(".pdf"))
        .toList();

    pdfs.sort((a, b) {
      final sa = a.statSync().modified;
      final sb = b.statSync().modified;
      return sb.compareTo(sa); // plus récents d'abord
    });

    return pdfs;
  }
}
