import 'package:flutter/services.dart';

class FieldScheduleShareService {
  static const MethodChannel _shareChannel = MethodChannel(
    'br.com.mapasjw.cartas/share',
  );

  static Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String title,
  }) async {
    await _shareChannel.invokeMethod<void>('shareFile', {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': mimeType,
      'title': title,
    });
  }
}
