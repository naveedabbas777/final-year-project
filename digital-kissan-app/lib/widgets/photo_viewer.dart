import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen interactive photo viewer dialog.
/// Replaces the 4 duplicate `_openSellerPhotoViewer` implementations.
///
/// Usage:
/// ```dart
/// PhotoViewer.show(context, url: photoUrl, caption: sellerName);
/// PhotoViewer.showGallery(context, urls: imageUrls, initialIndex: 0);
/// ```
class PhotoViewer {
  PhotoViewer._();

  /// Show a single photo full-screen.
  static void show(
    BuildContext context, {
    required String url,
    String? caption,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder:
          (_) => _PhotoViewerDialog(
            urls: [url],
            initialIndex: 0,
            caption: caption,
          ),
    );
  }

  /// Show a swipeable gallery of photos.
  static void showGallery(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    String? caption,
  }) {
    if (urls.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder:
          (_) => _PhotoViewerDialog(
            urls: urls,
            initialIndex: initialIndex,
            caption: caption,
          ),
    );
  }
}

class _PhotoViewerDialog extends StatefulWidget {
  const _PhotoViewerDialog({
    required this.urls,
    required this.initialIndex,
    this.caption,
  });

  final List<String> urls;
  final int initialIndex;
  final String? caption;

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late int _currentPage;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Go edge-to-edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Gallery / single image
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder:
                (_, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      widget.urls[i],
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                          ),
                        );
                      },
                      errorBuilder:
                          (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                    ),
                  ),
                ),
          ),

          // Close button
          Positioned(
            top: 44,
            right: 16,
            child: _CircleButton(
              icon: Icons.close,
              onTap: () => Navigator.pop(context),
            ),
          ),

          // Caption + zoom hint
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Column(
              children: [
                // Page dots (only for gallery)
                if (widget.urls.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.urls.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color:
                              _currentPage == i ? Colors.white : Colors.white38,
                        ),
                      );
                    }),
                  ),
                if (widget.caption != null || widget.urls.length > 1)
                  const SizedBox(height: 10),
                // Caption bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_in,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      if (widget.caption != null)
                        Flexible(
                          child: Text(
                            widget.caption!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (widget.caption != null) const SizedBox(width: 12),
                      const Text(
                        'Pinch to zoom',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}
