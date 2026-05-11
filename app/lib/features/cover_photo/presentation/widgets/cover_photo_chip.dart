import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/cover_photo/presentation/providers/cover_photo_providers.dart';

/// Sits at the bottom of the *active* (today's) diary page. Tapping
/// opens the system photo picker, compresses + uploads, then refreshes
/// the day's cover provider so the page picks up the new asset.
class CoverPhotoChip extends ConsumerStatefulWidget {
  const CoverPhotoChip({super.key, required this.localDate});
  final DateTime localDate;

  @override
  ConsumerState<CoverPhotoChip> createState() => _CoverPhotoChipState();
}

class _CoverPhotoChipState extends ConsumerState<CoverPhotoChip> {
  bool _busy = false;

  Future<void> _attach() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();

      final repo = ref.read(coverPhotoRepositoryProvider);
      final result = await repo.attach(
        localDate: widget.localDate,
        bytes: bytes,
      );
      result.match(
        (failure) {
          HapticFeedback.heavyImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('photo upload failed: ${failure.message}'),
              ),
            );
          }
        },
        (_) {
          HapticFeedback.mediumImpact();
          ref.invalidate(coverPhotoForDateProvider(widget.localDate));
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final cover = ref.watch(coverPhotoForDateProvider(widget.localDate));

    final hasCover = cover.maybeWhen(
      data: (either) => either.fold((_) => false, (c) => c != null),
      orElse: () => false,
    );

    final label = _busy
        ? '[ UPLOADING... ]'
        : hasCover
        ? '[+ REPLACE PHOTO ]'
        : '[+ PHOTO ]';
    final color = _busy ? crt.fgDim : crt.fgBright;

    return InkWell(
      onTap: _busy ? null : _attach,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: crt.uiType.copyWith(color: color)),
      ),
    );
  }
}
