import '../../core/utils/text_utils.dart';

/// Data master satu santri — sumber "siapa saja yang ada", dipakai untuk
/// autocomplete di form laporan & untuk hitung "santri yang diampu" di
/// Profile. TIDAK menggantikan [SantriRecord] (laporan tetap berdiri
/// sendiri, identitas santri di laporan tetap teks bebas untuk backward
/// compatibility — lihat catatan di ACCESS_CONTROL.md).
class Student {
  final String id;
  final String nama;
  final String kelas;
  final String halaqoh;

  /// Opsional untuk future-proofing multi-sekolah. Data lama tanpa field
  /// ini tetap terbaca (null = sekolah default/tunggal).
  final String? schoolId;

  /// BARU (migrasi skema nested per-guru): id akun guru pembimbing yang
  /// megang kelas+halaqoh santri ini. Ditulis oleh app guru
  /// (ApiStudentRepository) di dokumen `students/{id}` sejak data guru
  /// dipindah dari koleksi flat (`schools/{schoolId}/santriRecords` dkk)
  /// ke nested `schools/{schoolId}/accounts/{guruAccountId}/...`. WAJIB
  /// ada supaya Portal Ortu tahu subcollection guru mana yang harus
  /// dibaca/ditulis untuk santri ini — lihat firestore.rules & repo-repo
  /// di data/repositories/firestore/. Null = data lama / belum ke-assign
  /// guru (repo yang butuh ini akan gagal-jelas, bukan diam-diam salah
  /// akun, lihat masing-masing repo).
  final String? guruAccountId;

  const Student({
    required this.id,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    this.schoolId,
    this.guruAccountId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'kelas': kelas,
        'halaqoh': halaqoh,
        'schoolId': schoolId,
        'guruAccountId': guruAccountId,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        nama: json['nama'] as String,
        kelas: json['kelas'] as String,
        halaqoh: normalizeHalaqoh(json['halaqoh'] as String),
        schoolId: json['schoolId'] as String?,
        guruAccountId: json['guruAccountId'] as String?,
      );
}
