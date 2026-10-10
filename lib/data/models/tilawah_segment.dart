class TilawahSegment {
  final int surahNumber;
  final String surahName;
  final int ayatMulai;
  final int ayatSelesai;

  const TilawahSegment({
    required this.surahNumber,
    required this.surahName,
    required this.ayatMulai,
    required this.ayatSelesai,
  });

  String get partText => '$surahName • Ayat $ayatMulai–$ayatSelesai';

  Map<String, dynamic> toJson() => {
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayatMulai': ayatMulai,
        'ayatSelesai': ayatSelesai,
      };

  factory TilawahSegment.fromJson(Map<String, dynamic> json) => TilawahSegment(
        surahNumber: json['surahNumber'] as int,
        surahName: json['surahName'] as String,
        ayatMulai: json['ayatMulai'] as int,
        ayatSelesai: json['ayatSelesai'] as int,
      );
}

/// Satu baris laporan capaian hafalan/tahsin seorang santri pada satu tanggal.
