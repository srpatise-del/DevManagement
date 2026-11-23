import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String title;

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.title = 'ดูรูปภาพ',
  });

  static void show(
    BuildContext context, {
    String? imageUrl,
    Uint8List? imageBytes,
    String title = 'ดูรูปภาพ',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: imageUrl,
          imageBytes: imageBytes,
          title: title,
        ),
      ),
    );
  }

  Future<void> _openExternal(BuildContext context) async {
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      final uri = Uri.parse(imageUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่สามารถเปิด URL ในแอปภายนอกได้')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (imageUrl != null && imageUrl!.startsWith('http')) ...[
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              tooltip: 'ดาวน์โหลด / บันทึกรูปภาพ',
              onPressed: () => _openExternal(context),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser, color: Colors.white),
              tooltip: 'เปิดในเบราว์เซอร์',
              onPressed: () => _openExternal(context),
            ),
          ],
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: _buildImageWidget(),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.contain,
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final total = loadingProgress.expectedTotalBytes;
          final loaded = loadingProgress.cumulativeBytesLoaded;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: total != null ? loaded / total : null,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'กำลังโหลดรูปภาพ...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
              SizedBox(height: 12),
              Text(
                'ไม่สามารถโหลดรูปภาพได้',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          );
        },
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 64),
        SizedBox(height: 12),
        Text(
          'ไม่มีข้อมูลรูปภาพ',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
