import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/cover_photo/domain/entities/cover_photo.dart';
import 'package:memoir_log/features/cover_photo/presentation/providers/cover_photo_providers.dart';
import 'package:memoir_log/features/cover_photo/presentation/widgets/dithered_image.dart';

/// Renders the cover photo for [localDate] (if any) through the Bayer
/// dither shader so it sits inside the CRT aesthetic.
class CoverPhotoView extends ConsumerWidget {
  const CoverPhotoView({super.key, required this.localDate});
  final DateTime localDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = ref.watch(coverPhotoForDateProvider(localDate));
    return cover.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (either) => either.fold(
        (_) => const SizedBox.shrink(),
        (c) => c == null ? const SizedBox.shrink() : _CoverDithered(cover: c),
      ),
    );
  }
}

class _CoverDithered extends ConsumerStatefulWidget {
  const _CoverDithered({required this.cover});
  final CoverPhoto cover;

  @override
  ConsumerState<_CoverDithered> createState() => _CoverDitheredState();
}

class _CoverDitheredState extends ConsumerState<_CoverDithered> {
  ui.Image? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _CoverDithered old) {
    super.didUpdateWidget(old);
    if (old.cover.storagePath != widget.cover.storagePath) {
      _image?.dispose();
      _image = null;
      _failed = false;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    try {
      final repo = ref.read(coverPhotoRepositoryProvider);
      final urlEither = await repo.signedUrl(widget.cover.storagePath);
      final url = urlEither.toOption().toNullable();
      if (url == null) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      final res = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(res.data!);
      final image = await decodeImageBytes(bytes);
      if (mounted) setState(() => _image = image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '> COVER OFFLINE.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        ),
      );
    }
    final image = _image;
    if (image == null) {
      return const SizedBox(height: 60);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DitheredImage(image: image),
    );
  }
}
