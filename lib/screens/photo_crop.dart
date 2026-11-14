import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../services/file_service.dart';
import '../widgets/common.dart';

/// Change / remove the profile photo. Pick a photo, move and zoom it in the
/// circle, then it's saved (small, square) as your account picture.
Future<void> changeProfilePhoto(BuildContext context) async {
  final has = FirebaseAuth.instance.currentUser?.photoURL != null;
  final choice = await pickOne<String>(context, title: 'Profile photo', current: '', options: [
    ('pick', 'Choose a photo'),
    if (has) ('remove', 'Remove photo'),
  ]);
  if (choice == null || !context.mounted) return;
  if (choice == 'remove') {
    await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
    await FirebaseAuth.instance.currentUser?.reload();
    Avatar.changed.value++;
    return;
  }
  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  final bytes = r?.files.single.bytes;
  if (bytes == null || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => _CropScreen(bytes), fullscreenDialog: true));
}

class _CropScreen extends StatefulWidget {
  final Uint8List bytes;
  const _CropScreen(this.bytes);
  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  final crop = CropController();
  bool saving = false;

  Future<void> _done(Uint8List out) async {
    final m = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      // Keep it small: 512×512 JPEG.
      final decoded = img.decodeImage(out);
      final small = decoded == null ? out : Uint8List.fromList(img.encodeJpg(img.copyResize(decoded, width: 512, height: 512), quality: 88));
      final a = await FileService.uploadBytes(small, 'profile.jpg');
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(a.url);
      await FirebaseAuth.instance.currentUser?.reload();
      Avatar.changed.value++;
      nav.pop();
      m.showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (mounted) setState(() => saving = false);
      m.showSnackBar(SnackBar(content: Text('Couldn’t save the photo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF111116),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                const Expanded(child: Text('Move and scale', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          setState(() => saving = true);
                          crop.crop();
                        },
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save', style: TextStyle(color: Color(0xFFB9ACFA), fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            Expanded(
              child: Crop(
                image: widget.bytes,
                controller: crop,
                aspectRatio: 1,
                withCircleUi: true,
                baseColor: const Color(0xFF111116),
                maskColor: Colors.black.withOpacity(0.55),
                interactive: true,
                onCropped: _done,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Drag to move · pinch or scroll to zoom', style: TextStyle(color: Colors.white60, fontSize: 12.5)),
            ),
          ]),
        ),
      );
}
