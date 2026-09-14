// AKTIF — project Firebase: quran-reportweb.

import 'dart:async';

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
    //
    // <-- BARU: .timeout(...) — sebelumnya kalau query ini nyangkut
    // (apa pun sebabnya: koneksi, index, dll), await-nya nunggu
    // SELAMANYA, bikin UI muter tanpa akhir. Sekarang dipaksa gagal
    // eksplisit setelah 15 detik, supaya try/catch di DashboardProvider
    // KETANGKEP dan errornya kelihatan, bukan nyangkut diam-diam.
    // .get(const GetOptions(source: Source.server)) — <-- BARU juga,
    // maksa ambil dari server (bukan diam-diam nunggu cache lokal yang
    // mungkin belum ke-sync).
    final snap = await _col
        .where('kelas', isEqualTo: student.kelas)
        .where('halaqoh', isEqualTo: student.halaqoh)
        .where('namaAnak', isEqualTo: student.nama)
        .orderBy('tanggal', descending: true)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Query santriRecords timeout 15 detik (kelas=${student.kelas}, '
            'halaqoh=${student.halaqoh}, namaAnak=${student.nama})',
          ),
        );

    return snap.docs.map((d) => SantriRecord.fromJson(d.data())).toList();
  }

  @override
  Stream<List<SantriRecord>> watchRecordsForStudent(Student student) {
    // Query FILTER-nya sama persis dengan getRecordsForStudent di atas
    // (kelas+halaqoh+namaAnak exact match di level Firestore) — cuma
    // `.snapshots()` dipakai sebagai ganti `.get()` sekali, jadi listener
    // ini otomatis emit ulang setiap kali ada dokumen yang cocok
    // ditambah/diubah/dihapus. `includeMetadataChanges: false` (default)
    // supaya tidak emit dua kali untuk 1 perubahan yang sama (sekali dari
    // cache lokal, sekali konfirmasi server) — cukup 1 emit begitu server
    // konfirmasi.
    return _col
        .where('kelas', isEqualTo: student.kelas)
        .where('halaqoh', isEqualTo: student.halaqoh)
        .where('namaAnak', isEqualTo: student.nama)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SantriRecord.fromJson(d.data())).toList());
  }
}
