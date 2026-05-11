import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/cover_photo/data/datasources/cover_photo_remote_data_source.dart';
import 'package:memoir_log/features/cover_photo/domain/entities/cover_photo.dart';
import 'package:memoir_log/features/cover_photo/domain/repositories/cover_photo_repository.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 1280px on the long edge keeps cover photos under ~250KB at q70 — fits
/// the Supabase free-tier storage budget while staying crisp on a phone.
const _maxLongEdge = 1280;
const _jpegQuality = 70;

class CoverPhotoRepositoryImpl implements CoverPhotoRepository {
  CoverPhotoRepositoryImpl({
    required CoverPhotoRemoteDataSource remote,
    required String Function() currentUserId,
  }) : _remote = remote,
       _currentUserId = currentUserId;

  final CoverPhotoRemoteDataSource _remote;
  final String Function() _currentUserId;

  Failure _classify(Object e) {
    if (e is StorageException) return ServerFailure(e.message);
    if (e is PostgrestException) return ServerFailure(e.message);
    if (e is SocketException) return const NetworkFailure('offline');
    return UnknownFailure(e.toString());
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Either<Failure, CoverPhoto?>> coverFor(DateTime localDate) async {
    try {
      final row = await _remote.readCover(
        userId: _currentUserId(),
        localDate: _isoDate(localDate),
      );
      if (row == null) return const Right(null);
      return Right(
        CoverPhoto(
          localDate: localDate,
          storagePath: row['storage_path'] as String,
          dominantHex: row['dominant_hex'] as String?,
          width: (row['width'] as num?)?.toInt(),
          height: (row['height'] as num?)?.toInt(),
        ),
      );
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, CoverPhoto>> attach({
    required DateTime localDate,
    required Uint8List bytes,
  }) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxLongEdge,
        minHeight: _maxLongEdge,
        quality: _jpegQuality,
        keepExif: false,
        format: CompressFormat.jpeg,
      );

      final dominantHex = await _extractDominantHex(compressed);

      final iso = _isoDate(localDate);
      final path = await _remote.uploadCover(
        userId: _currentUserId(),
        localDate: iso,
        bytes: compressed,
        dominantHex: dominantHex,
      );

      return Right(
        CoverPhoto(
          localDate: localDate,
          storagePath: path,
          dominantHex: dominantHex,
        ),
      );
    } catch (e) {
      return Left(_classify(e));
    }
  }

  /// Extracts a single dominant hex from the compressed JPEG bytes. We
  /// intentionally pass the *already-compressed* buffer so the palette
  /// scan happens on the same pixels the diary will eventually dither,
  /// not on an oversized original.
  ///
  /// Returns null on any failure — dominant_hex is optional in the DB
  /// and the narrator prompt rule degrades gracefully when it's absent.
  Future<String?> _extractDominantHex(Uint8List bytes) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(bytes),
        // Cap the sample region — the generator does its own downsample
        // but a soft cap keeps the scan under ~50ms on mid-range phones.
        size: const Size(120, 120),
        maximumColorCount: 8,
      );
      final color = palette.dominantColor?.color;
      if (color == null) return null;
      final r = (color.r * 255).round() & 0xff;
      final g = (color.g * 255).round() & 0xff;
      final b = (color.b * 255).round() & 0xff;
      return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Either<Failure, void>> detach(DateTime localDate) async {
    try {
      await _remote.deleteCover(
        userId: _currentUserId(),
        localDate: _isoDate(localDate),
      );
      return const Right(null);
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, String>> signedUrl(String storagePath) async {
    try {
      return Right(await _remote.signedUrl(storagePath));
    } catch (e) {
      return Left(_classify(e));
    }
  }
}
