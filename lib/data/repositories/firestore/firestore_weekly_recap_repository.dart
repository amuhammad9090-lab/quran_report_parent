// AKTIF — project Firebase: quran-reportweb.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student.dart';
import '../../models/weekly_recap.dart';
import '../weekly_recap_repository.dart';

/// Baca `schools/{schoolId}/accounts/{guruAccountId}/weeklyRecaps/{id}`.
///
/// BERUBAH (migrasi skema nested per-guru): dulu flat di
/// `schools/{schoolId}/weeklyRecaps`. App guru (WeeklyRecapDeployService)
/// dan firestore.rules sudah pindah ke subcollection nested di bawah
/// `accounts/{guruAccountId}` — koleksi flat lama sudah tidak ada match
/// block-nya lagi di rules, jadi query ke situ selalu gagal
/// permission-denied. [Student.guruAccountId] menentukan subcollection
/// mana yang dibaca.
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

  CollectionReference<Map<String, dynamic>> _col(String guruAccountId) => _db
      .collection('schools')
      .doc(schoolId)
      .collection('accounts')
      .doc(guruAccountId)
      .collection('weeklyRecaps');

  @override
  Future<List<WeeklyRecap>> getRecentForStudent(Student student, {int limit = 12}) async {
    final accountId = student.guruAccountId;
    if (accountId == null) {
      throw StateError(
        'Student ${student.id} (${student.nama}) belum punya guruAccountId — '
        'tidak bisa resolve subcollection weeklyRecaps guru pembimbingnya.',
      );
    }

    // .timeout(...) + GetOptions(source: server) — pola sama seperti
    // FirestoreReportRepository, biar tidak nyangkut nunggu selamanya
    // dan tidak diam-diam kejebak cache lokal yang belum ke-sync.
    final snap = await _col(accountId)
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
      final wStart = data['weekStart'];
      final wEnd = data['weekEnd'];
      return WeeklyRecap.fromJson(d.id, {
        ...data,
        'deployedAt': ts is Timestamp ? ts.toDate() : null,
        // weekStart/weekEnd: field BARU, belum tentu ada di dokumen lama
        // yang di-deploy sebelum app guru diupdate — lihat catatan
        // lengkap soal ini di `WeeklyRecap`. Aman kalau null.
        'weekStart': wStart is Timestamp ? wStart.toDate() : null,
        'weekEnd': wEnd is Timestamp ? wEnd.toDate() : null,
      });
    }).toList();
  }
}
