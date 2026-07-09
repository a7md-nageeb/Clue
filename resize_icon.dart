import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/app_icon_foreground.png').readAsBytesSync();
  final image = img.decodePng(bytes);
  if (image == null) return;

  final scaledWidth = (1024 * 0.75).toInt();
  final scaled = img.copyResize(
    image,
    width: scaledWidth,
    height: scaledWidth,
    interpolation: img.Interpolation.linear,
  );

  final outImage = img.Image(width: 1024, height: 1024, numChannels: 4);

  final dx = (1024 - scaledWidth) ~/ 2;
  final dy = (1024 - scaledWidth) ~/ 2;

  img.compositeImage(outImage, scaled, dstX: dx, dstY: dy);

  File(
    'assets/app_icon_foreground_padded.png',
  ).writeAsBytesSync(img.encodePng(outImage));
  print("Done!");
}
