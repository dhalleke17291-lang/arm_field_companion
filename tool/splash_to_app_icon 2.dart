// One-off: builds square 1024×1024 launcher masters from assets/Branding/splash_logo.png
// Background matches lib/splash_screen.dart _nativeSplashColor (0xFF163B28).
//
// Run from repo root: dart run tool/splash_to_app_icon.dart

import 'dart:io';
import 'dart:math' show max;

import 'package:image/image.dart' as img;

const int _out = 1024;
// 0xFF163B28
const int _bgR = 0x16;
const int _bgG = 0x3B;
const int _bgB = 0x28;

void main() {
  final srcFile = File('assets/Branding/splash_logo.png');
  if (!srcFile.existsSync()) {
    stderr.writeln('Missing ${srcFile.path}');
    exit(1);
  }
  final decoded = img.decodePng(srcFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode splash_logo.png');
    exit(1);
  }

  final w = decoded.width;
  final h = decoded.height;
  // [BoxFit.cover] — zoom so the artwork fills the square; center-crop. Reads much
  // larger than [contain] (letterbox), which the splash screen still uses in-app.
  final cover = max(_out / w, _out / h);
  final nw = (w * cover).round().clamp(1, 1 << 20);
  final nh = (h * cover).round().clamp(1, 1 << 20);
  final resized = img.copyResize(
    decoded,
    width: nw,
    height: nh,
    interpolation: img.Interpolation.linear,
  );
  var cx = (nw - _out) ~/ 2;
  var cy = (nh - _out) ~/ 2;
  if (cx < 0) cx = 0;
  if (cy < 0) cy = 0;
  if (cx + _out > nw) cx = nw - _out;
  if (cy + _out > nh) cy = nh - _out;
  final front = img.copyCrop(
    resized,
    x: cx,
    y: cy,
    width: _out,
    height: _out,
  );

  final canvas = img.Image(width: _out, height: _out);
  img.fill(canvas, color: img.ColorRgb8(_bgR, _bgG, _bgB));
  img.compositeImage(canvas, front, dstX: 0, dstY: 0);

  final outBytes = img.encodePng(canvas);
  File('assets/Branding/app_icon.png').writeAsBytesSync(outBytes, flush: true);
  File('assets/Branding/app_icon_ios.png').writeAsBytesSync(outBytes, flush: true);
  stdout.writeln(
    'Wrote $_out x $_out app_icon.png and app_icon_ios.png from splash_logo.png',
  );
}
