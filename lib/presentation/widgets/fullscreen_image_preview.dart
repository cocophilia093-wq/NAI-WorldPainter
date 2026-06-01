import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<void> showFullscreenImagePreview(
  BuildContext context, {
  String? imagePath,
  String? imageUrl,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullscreenImagePreview(imagePath: imagePath, imageUrl: imageUrl);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _FullscreenImagePreview extends StatelessWidget {
  final String? imagePath;
  final String? imageUrl;

  const _FullscreenImagePreview({this.imagePath, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (imagePath != null && File(imagePath!).existsSync()) {
      child = Image.file(File(imagePath!), fit: BoxFit.contain);
    } else if (imageUrl != null) {
      child = Image.network(imageUrl!, fit: BoxFit.contain);
    } else {
      child = const Icon(Icons.broken_image, size: 72, color: Colors.white54);
    }

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: SizedBox.expand(
                child: Center(child: child),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
