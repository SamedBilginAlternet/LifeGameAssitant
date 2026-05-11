import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures the widget under [boundaryKey] as a PNG and opens the
/// system share sheet. Returns the path of the temp file, or null if
/// the boundary couldn't be located (most often because the page has
/// scrolled out of view).
///
/// Renders at 3x pixel ratio so the PNG looks crisp on a Twitter feed,
/// not pixelated. The diary aesthetic *is* pixel-y, but the bitmap
/// itself should still be sharp.
Future<String?> captureAndShareDiaryPage({
  required GlobalKey boundaryKey,
  String? subject,
}) async {
  final ctx = boundaryKey.currentContext;
  if (ctx == null) return null;
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) return null;
  final bytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );

  final path = await _writePng(bytes);
  await Share.shareXFiles([
    XFile(path, mimeType: 'image/png'),
  ], subject: subject ?? 'memoir_log');
  return path;
}

Future<String> _writePng(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${dir.path}/memoir_log_card_$stamp.png');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
