/// Satu rekap pekanan MILIK SATU SANTRI (bukan sekelas) — dikirim
/// ("Deploy") dari app guru lewat `WeeklyRecapDeployService`, dibaca
/// portal orang tua lewat `FirestoreWeeklyRecapRepository`.
///
/// SENGAJA 1 dokumen = 1 santri = 1 pekan (bukan 1 dokumen isi array
/// semua santri sekelas) — supaya rules Firestore bisa membatasi akses
/// baca sampai level `namaAnak` cocok (persis pola [SantriRecord]),
/// bukan cuma level kelas+halaqoh. Lihat catatan arsitektur lengkap di
/// `WeeklyRecapDeployService` (app guru).
///
/// --- CATATAN BUG "kartu pekan tidak hilang walau laporan dihapus" ---
/// Dokumen ini adalah SNAPSHOT BEKU hasil "Deploy" — begitu dibuat, dia
/// TIDAK menyimpan referensi apa pun (tidak ada `reportIds`/`lineIds`)
/// ke laporan harian ([SantriRecord]) sumbernya. Jadi kalau guru
/// menghapus laporan harian di app guru SETELAH rekap ini di-deploy,
/// dokumen `weeklyRecaps` ini TIDAK otomatis berubah/terhapus — portal
/// orang tua akan terus menampilkannya apa adanya sampai dihapus manual
/// di Firestore. Ini BUKAN bug di portal orang tua (portal ini
/// read-only, secara sengaja TIDAK PERNAH menghapus data guru), akar
/// masalahnya ada di app guru:
///   1. `WeeklyRecapDeployService.deploy(...)` perlu ikut menyimpan
///      identitas laporan sumbernya saat deploy — field baru yang
///      disepakati di sini: `weekStart`/`weekEnd` (Timestamp, rentang
///      tanggal pekan yang direkap) DAN idealnya `reportIds`
///      (List<String> id dokumen laporan harian yang jadi sumber).
///   2. Alur hapus/edit laporan harian di app guru (mis. di
///      `records_provider.dart`) perlu, setelah berhasil hapus,
///      MENGECEK apakah laporan itu bagian dari rekap yang sudah
///      di-deploy (via `reportIds`), dan kalau iya: hapus ATAU
///      regenerate ulang dokumen `weeklyRecaps` terkait.
///
/// Sebagai JARING PENGAMAN sementara (bukan pengganti fix di atas),
/// [weekStart]/[weekEnd] di sini SUDAH disiapkan nullable — begitu app
/// guru mulai mengirim 2 field itu, `HistoryScreen` otomatis
/// menyembunyikan kartu rekap yang sudah tidak punya laporan harian
/// sama sekali lagi di rentang tanggal tersebut (lihat
/// `weeklyRecapIsLikelyStale` di file ini). Untuk dokumen LAMA yang
/// belum punya `weekStart`/`weekEnd` (null), kartu tetap ditampilkan
/// apa adanya seperti sebelumnya (tidak ada perubahan perilaku) karena
/// tidak ada cukup info buat memvalidasinya.
class WeeklyRecap {
  final String id;
  final String kelas;
  final String halaqoh;
  final int weekIndex;
  final String bulanLabel;
  final String rangeLabel;
  final String periode;
  final String? guruPembimbing;
  final String namaAnak;
  final String tanggalLabel;
  final String capaian;
  final int totalBaris;
  final String keterangan;
  final String catatan;
  final DateTime? deployedAt;
  final String? deployedByNama;

  /// BARU — opsional, lihat catatan arsitektur di atas. Diisi dari
  /// field Firestore `weekStart`/`weekEnd` KALAU app guru sudah
  /// mengirimnya saat deploy; null untuk dokumen lama/belum diupdate.
  final DateTime? weekStart;
  final DateTime? weekEnd;

  const WeeklyRecap({
    required this.id,
    required this.kelas,
    required this.halaqoh,
    required this.weekIndex,
    required this.bulanLabel,
    required this.rangeLabel,
    required this.periode,
    required this.namaAnak,
    required this.tanggalLabel,
    required this.capaian,
    required this.totalBaris,
    required this.keterangan,
    required this.catatan,
    this.guruPembimbing,
    this.deployedAt,
    this.deployedByNama,
    this.weekStart,
    this.weekEnd,
  });

  /// [json] harus sudah punya `deployedAt`/`weekStart`/`weekEnd` dalam
  /// bentuk [DateTime] (dikonversi dari Firestore Timestamp di level
  /// repository, sama polanya seperti [ParentNote.fromJson]) — model ini
  /// sengaja tidak bergantung pada package cloud_firestore.
  factory WeeklyRecap.fromJson(String id, Map<String, dynamic> json) {
    final ts = json['deployedAt'];
    final wStart = json['weekStart'];
    final wEnd = json['weekEnd'];
    return WeeklyRecap(
      id: id,
      kelas: json['kelas'] as String? ?? '',
      halaqoh: json['halaqoh'] as String? ?? '',
      weekIndex: json['weekIndex'] as int? ?? 0,
      bulanLabel: json['bulanLabel'] as String? ?? '',
      rangeLabel: json['rangeLabel'] as String? ?? '',
      periode: json['periode'] as String? ?? '',
      guruPembimbing: json['guruPembimbing'] as String?,
      namaAnak: json['namaAnak'] as String? ?? '',
      tanggalLabel: json['tanggalLabel'] as String? ?? '',
      capaian: json['capaian'] as String? ?? '',
      totalBaris: json['totalBaris'] as int? ?? 0,
      keterangan: json['keterangan'] as String? ?? '',
      catatan: json['catatan'] as String? ?? '',
      deployedAt: ts is DateTime ? ts : null,
      deployedByNama: json['deployedByNama'] as String?,
      weekStart: wStart is DateTime ? wStart : null,
      weekEnd: wEnd is DateTime ? wEnd : null,
    );
  }
}

/// Heuristik jaring-pengaman untuk bug "kartu pekan tidak hilang walau
/// laporan dihapus" — lihat catatan panjang di [WeeklyRecap]. Return
/// true kalau rekap ini KEMUNGKINAN BESAR sudah basi (laporan
/// sumbernya sudah dihapus semua dari app guru) dan sebaiknya
/// disembunyikan dari daftar.
///
/// SENGAJA konservatif (banyak `return false`) — heuristik ini TIDAK
/// bisa mendeteksi penghapusan SEBAGIAN laporan dalam 1 pekan (itu
/// butuh `reportIds` per-laporan, bukan cuma rentang tanggal), cuma
/// kasus yang tadi user tes: SEMUA laporan di pekan itu sudah dihapus.
/// Daripada salah sembunyikan kartu yang masih valid, default-nya
/// selalu TAMPILKAN kalau raguragu.
bool weeklyRecapIsLikelyStale(WeeklyRecap recap, List<DateTime> liveReportDates) {
  final start = recap.weekStart;
  final end = recap.weekEnd;
  // Tidak ada info rentang tanggal (dokumen lama / app guru belum
  // update field ini) -> tidak bisa divalidasi, jangan sembunyikan.
  if (start == null || end == null) return false;

  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);

  final anyReportStillExists = liveReportDates.any((d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(startDay) && !day.isAfter(endDay);
  });

  return !anyReportStillExists;
}
