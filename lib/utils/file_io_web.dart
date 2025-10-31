import 'dart:async';
import 'dart:html' as html;

Future<void> exportFile(String filename, String content) async {
  final blob = html.Blob([content], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<String?> pickFileAndRead() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement();
  input.accept = '.csv,text/csv';
  input.click();
  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.onLoad.listen((e) {
      completer.complete(reader.result as String?);
    });
    reader.onError.listen((e) {
      completer.completeError('ファイル読み込みエラー');
    });
    reader.readAsText(file);
  });
  return completer.future;
}
