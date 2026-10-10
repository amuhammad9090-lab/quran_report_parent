/// generate barisnya sendiri. Laporan bisa punya LEBIH DARI SATU segmen
/// kalau santri setoran nyambung lintas surah dalam 1 pertemuan (mis.
/// abis akhir Al-Baqarah, lanjut awal Ali 'Imran).
class TahfizhSegment {
  final int surahNumber;
  final String surahName;
  final int ayatMulai;
  final int ayatSelesai;
  final int totalBaris; // baris baru hasil generate KHUSUS segmen ini
  final List<String> lineIds; // id baris fisik yang dihitung di segmen ini

  const TahfizhSegment({
    required this.surahNumber,
    required this.surahName,
    required this.ayatMulai,
    required this.ayatSelesai,
    required this.totalBaris,
    required this.lineIds,
  });

  String get partText => '$surahName • Ayat $ayatMulai–$ayatSelesai';

  Map<String, dynamic> toJson() => {
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayatMulai': ayatMulai,
        'ayatSelesai': ayatSelesai,
        'totalBaris': totalBaris,
        'lineIds': lineIds,
      };

  factory TahfizhSegment.fromJson(Map<String, dynamic> json) => TahfizhSegment(
        surahNumber: json['surahNumber'] as int,
        surahName: json['surahName'] as String,
        ayatMulai: json['ayatMulai'] as int,
        ayatSelesai: json['ayatSelesai'] as int,
        totalBaris: json['totalBaris'] as int? ?? 0,
        lineIds: (json['lineIds'] as List?)?.map((e) => e as String).toList() ?? const [],
      );
}

/// Satu segmen "bentuk Tilawah": surah + rentang ayat TANPA hitung baris.
/// Dipakai untuk Tahsin bermode Tilawah, bagian Tahsin di Tahsin+Tahfizh
/// (saat modenya Tilawah), dan Muroja'ah/Tasmi'. Bisa lebih dari satu
/// segmen dengan alasan yang sama seperti [TahfizhSegment].
