import 'enums.dart';
import 'santri_record.dart'; // re-exports tahfizh_segment.dart & tilawah_segment.dart

/// Getter "turunan" (computed, bukan field asli) milik [SantriRecord] —
/// diekstrak jadi extension di file terpisah supaya `santri_record.dart`
/// (dulu 1 file 431 baris) di bawah 300 baris. Dipakai PERSIS seperti
/// getter instance biasa (`record.capaianText`, dst) di mana pun
/// `santri_record.dart` di-import — lihat `export` di file itu.
extension SantriRecordDisplay on SantriRecord {
  /// Semua segmen Tahfizh laporan ini. Kalau [tahfizhSegments] belum ada
  /// (data lama sebelum fitur multi-surah), otomatis di-generate 1 segmen
  /// dari field tunggal surahNumber/surahName/ayatMulai/ayatSelesai +
  /// totalBaris/lineIds — jadi laporan lama tetap kebaca normal.
  List<TahfizhSegment> get tahfizhSegmentsEffective {
    if (tahfizhSegments != null && tahfizhSegments!.isNotEmpty) return tahfizhSegments!;
    if (surahNumber != null && surahName != null && ayatMulai != null && ayatSelesai != null) {
      return [
        TahfizhSegment(
          surahNumber: surahNumber!,
          surahName: surahName!,
          ayatMulai: ayatMulai!,
          ayatSelesai: ayatSelesai!,
          totalBaris: totalBaris ?? 0,
          lineIds: lineIds ?? const [],
        ),
      ];
    }
    return const [];
  }

  /// Semua segmen Tilawah laporan ini (dipakai Tahsin-mode-Tilawah &
  /// Muroja'ah/Tasmi'). Fallback yang sama seperti [tahfizhSegmentsEffective]
  /// buat laporan lama.
  List<TilawahSegment> get tilawahSegmentsEffective {
    if (tilawahSegments != null && tilawahSegments!.isNotEmpty) return tilawahSegments!;
    if (tilawahSurahNumber != null &&
        tilawahSurahName != null &&
        tilawahAyatMulai != null &&
        tilawahAyatSelesai != null) {
      return [
        TilawahSegment(
          surahNumber: tilawahSurahNumber!,
          surahName: tilawahSurahName!,
          ayatMulai: tilawahAyatMulai!,
          ayatSelesai: tilawahAyatSelesai!,
        ),
      ];
    }
    return const [];
  }

  /// Teks ringkas bagian Tahsin saja (WAFA atau Tilawah) — dipakai baik
  /// untuk status Tahsin murni maupun sebagai salah satu bagian dari
  /// Tahsin+Tahfizh.
  String get _tahsinPartText {
    final mode = tahsinMode ?? TahsinMode.wafa; // null = data lama -> WAFA
    if (mode == TahsinMode.tilawah) {
      final segs = tilawahSegmentsEffective;
      if (segs.isEmpty) return 'Tilawah • -';
      return 'Tilawah • ${segs.map((s) => s.partText).join(' + ')}';
    }
    final level = wafaLevel?.label ?? '-';
    final hal = halamanWafa ?? '-';
    return '$level • Hal. $hal';
  }

  /// Teks ringkas bagian Tahfizh saja (hafalan baru, hasil generate baris).
  /// Kalau lebih dari 1 surah (setoran nyambung lintas surah), digabung
  /// dengan " + ", mis. "Al-Baqarah • Ayat 280–286 + Ali 'Imran • Ayat 1–5".
  String get _tahfizhPartText {
    final segs = tahfizhSegmentsEffective;
    if (segs.isEmpty) return '-';
    return segs.map((s) => s.partText).join(' + ');
  }

  /// Teks ringkas untuk status Muroja'ah/Tasmi' (selalu bentuk Tilawah).
  String get _murojaahPartText {
    final segs = tilawahSegmentsEffective;
    if (segs.isEmpty) return '-';
    return segs.map((s) => s.partText).join(' + ');
  }

  /// Total jumlah ayat yang disetorkan di laporan ini — dijumlahkan dari
  /// SEMUA segmen (Tahfizh + Tilawah, keduanya bisa ada bareng di status
  /// Tahsin+Tahfizh), dipakai buat chart "Ayat Tersetor/Minggu" di tab
  /// Statistik. Rentang ayatMulai..ayatSelesai dihitung inklusif kedua
  /// ujungnya (mis. ayat 5–8 = 4 ayat).
  int get jumlahAyat {
    int rangeCount(int mulai, int selesai) =>
        selesai >= mulai ? (selesai - mulai + 1) : 0;
    final tahfizh = tahfizhSegmentsEffective.fold<int>(
      0,
      (sum, s) => sum + rangeCount(s.ayatMulai, s.ayatSelesai),
    );
    final tilawah = tilawahSegmentsEffective.fold<int>(
      0,
      (sum, s) => sum + rangeCount(s.ayatMulai, s.ayatSelesai),
    );
    return tahfizh + tilawah;
  }

  /// Ringkasan Muroja'ah/Tasmi' (surah+ayat yang diulang) — versi publik
  /// dari [_murojaahPartText], alasannya sama dengan [tahsinSummaryText]:
  /// dipakai di luar kelas ini (hero Beranda Portal Ortu, mode
  /// Muroja'ah) tanpa perlu tahu detail internal segmennya.
  String get murojaahSummaryText => _murojaahPartText;

  /// Ringkasan bagian Tahsin saja (WAFA level+halaman, ATAU Tilawah
  /// surah+ayat — tergantung [tahsinMode] yang dipakai guru saat input,
  /// bukan cuma WAFA) — versi publik dari [_tahsinPartText], dipakai di
  /// luar kelas ini (mis. hero Beranda Portal Ortu) buat nampilin
  /// capaian Tahsin terakhir apa adanya sesuai mode aslinya.
  String get tahsinSummaryText => _tahsinPartText;

  /// Ringkasan capaian untuk ditampilkan di kartu / laporan.
  String get capaianText {
    switch (status) {
      case HafalanStatus.tahfizh:
        return _tahfizhPartText;
      case HafalanStatus.tahsin:
        return _tahsinPartText;
      case HafalanStatus.tahsinTahfizh:
        return '$_tahsinPartText + $_tahfizhPartText';
      case HafalanStatus.murojaahTasmi:
        return _murojaahPartText;
    }
  }
}
