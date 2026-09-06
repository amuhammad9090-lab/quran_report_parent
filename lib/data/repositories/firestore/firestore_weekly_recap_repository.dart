// AKTIF — project Firebase: quran-reportweb.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student.dart';
import '../../models/weekly_recap.dart';
import '../weekly_recap_repository.dart';

/// Baca `schools/{schoolId}/weeklyRecaps/{id}`.
///
/// Query di-filter di level Firestore (`.where(...)`) memakai
/// kelas+halaqoh+`namaAnakLower` — BUKAN ambil semua dokumen kelas lalu
/// filter di client (sama prinsip keamanan seperti
/// [FirestoreReportRepository]). Karena 1 dokumen = 1 santri (lihat
/// catatan arsitektur di [WeeklyRecap]), kombinasi where ini + rules
/// Firestore (lihat `firestore.rules`) memastikan dokumen milik santri
/// LAIN tidak pernah terkirim ke client sama sekali.
///
/// Query pakai `namaAnakLower` (bukan `namaAnak` apa adanya) supaya
/// tetap cocok walau ada beda kapitalisasi antara `Student.nama` (data
/// master) dengan nama yang diketik guru di form laporan.
class FirestoreWeeklyRecapRepository implements WeeklyRecapRepository {
  final String schoolId;
  final FirebaseFirestore _db;

  FirestoreWeeklyRecapRepository({required this.schoolId, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('schools').doc(schoolId).collection('weeklyRecaps');

  @override
  Future<List<WeeklyRecap>> getRecentForStudent(Student student, {int limit = 12}) async {
    // .timeout(...) + GetOptions(source: server) — pola sama seperti
    // FirestoreReportRepository, biar tidak nyangkut nunggu selamanya
    // dan tidak diam-diam kejebak cache lokal yang belum ke-sync.
    final snap = await _col
        .where('kelas', isEqualTo: student.kelas)
        .where('halaqoh', isEqualTo: student.halaqoh)
        .where('namaAnakLower', isEqualTo: student.nama.trim().toLowerCase())
        .orderBy('deployedAt', descending: true)
        .limit(limit)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Query weeklyRecaps timeout 15 detik (kelas=${student.kelas}, '
            'halaqoh=${student.halaqoh}, namaAnak=${student.nama})',
          ),
        );

    return snap.docs.map((d) {
      final data = d.data();
      final ts = data['deployedAt'];
      return WeeklyRecap.fromJson(d.id, {
        ...data,
        'deployedAt': ts is Timestamp ? ts.toDate() : null,
      });
    }).toList();
  }
}
