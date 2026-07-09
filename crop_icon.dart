import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('assets/app_icon.png');
  final img = decodeImage(file.readAsBytesSync());
  if (img != null) {
    const bgR = 0x66;
    const bgG = 0x9D;
    const bgB = 0xF2;

    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < img.width; x++) {
        final p = img.getPixel(x, y);
        final distanceFromBackground =
            ((p.r - bgR).abs() + (p.g - bgG).abs() + (p.b - bgB).abs()) / 3;
        final alpha = (distanceFromBackground / 153 * p.a).clamp(0, 255);
        img.setPixelRgba(x, y, 255, 255, 255, alpha);
      }
    }

    File('assets/app_icon_foreground.png').writeAsBytesSync(encodePng(img));
    stdout.writeln('Saved assets/app_icon_foreground.png');
  }
}
