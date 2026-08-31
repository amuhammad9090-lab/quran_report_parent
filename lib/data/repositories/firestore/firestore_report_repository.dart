// AKTIF — project Firebase: quran-reportweb.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/santri_record.dart';
import '../../models/student.dart';
import '../../repositories/report_repository.dart';

/// Baca [SantriRecord] dari `schools/{schoolId}/santriRecords/{id}`.
///
/// PENTING (sesuai aturan keamanan brief): query di-filter di level
/// Firestore lewat `.where(...)` — BUKAN ambil semua lalu filter di
/// client. Karena `SantriRecord` tidak punya `studentId` (lihat catatan
/// arsitektur di `report_repository.dart` — desain existing app guru,
/// bukan sesuatu yang kita ubah), filter tetap pakai kombinasi
/// kelas+halaqoh+namaAnak, TAPI dieksekusi sebagai Firestore query
/// (`.where('kelas', ...).where('halaqoh', ...).where('namaAnak', ...)`),
/// jadi dokumen milik santri lain TIDAK PERNAH terkirim ke client sama
/// sekali — bukan cuma disembunyikan di UI.
class FirestoreReportRepository implements ReportRepository {
  final String schoolId;
  final FirebaseFirestore _db;

  FirestoreReportRepository({required this.schoolId, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('schools').doc(schoolId).collection('santriRecords');

  @override
  Future<List<SantriRecord>> getRecordsForStudent(Student student) async {
    // Firestore butuh exact-match string untuk .where() — namaAnak
    // dibandingkan case-sensitive di query (beda dari MockReportRepository
    // yang case-insensitive di Dart). Kalau nanti ada mismatch kapitalisasi
    // antara Student.nama & SantriRecord.namaAnak, pertimbangkan simpan
    // field tambahan `namaAnakLower` khusus buat query (denormalisasi
    // umum di Firestore) — BUKAN mengubah cara app guru menyimpan nama.
    final snap = await _col
        .where('kelas', isEqualTo: student.kelas)
        .where('halaqoh', isEqualTo: student.halaqoh)
        .where('namaAnak', isEqualTo: student.nama)
        .orderBy('tanggal', descending: true)
        .get();

    return snap.docs.map((d) => SantriRecord.fromJson(d.data())).toList();
  }
}
