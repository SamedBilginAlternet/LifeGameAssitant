class CoverPhoto {
  const CoverPhoto({
    required this.localDate,
    required this.storagePath,
    this.dominantHex,
    this.width,
    this.height,
  });

  final DateTime localDate;
  final String storagePath;
  final String? dominantHex;
  final int? width;
  final int? height;
}
