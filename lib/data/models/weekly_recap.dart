/// Satu rekap pekanan MILIK SATU SANTRI (bukan sekelas) — dikirim
/// ("Deploy") dari app guru lewat `WeeklyRecapDeployService`, dibaca
/// portal orang tua lewat `FirestoreWeeklyRecapRepository`.
///
/// SENGAJA 1 dokumen = 1 santri = 1 pekan (bukan 1 dokumen isi array
/// semua santri sekelas) — supaya rules Firestore bisa membatasi akses
/// baca sampai level `namaAnak` cocok (persis pola [SantriRecord]),
/// bukan cuma level kelas+halaqoh. Lihat catatan arsitektur lengkap di
/// `WeeklyRecapDeployService` (app guru).
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
  });

  /// [json] harus sudah punya `deployedAt` dalam bentuk [DateTime]
  /// (dikonversi dari Firestore Timestamp di level repository, sama
  /// polanya seperti [ParentNote.fromJson]) — model ini sengaja tidak
  /// bergantung pada package cloud_firestore.
  factory WeeklyRecap.fromJson(String id, Map<String, dynamic> json) {
    final ts = json['deployedAt'];
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
    );
  }
}
