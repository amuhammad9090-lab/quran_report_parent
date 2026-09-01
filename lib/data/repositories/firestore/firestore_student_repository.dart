// AKTIF — project Firebase: quran-reportweb.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student.dart';
import '../../repositories/student_repository.dart';

/// Baca [Student] dari `schools/{schoolId}/students/{id}` — read-only,
/// sesuai brief (portal orang tua tidak pernah menulis ke koleksi ini).
/// `toJson()`/`fromJson()` dipakai apa adanya dari model shared, TIDAK
/// ada mapping field manual tambahan.
class FirestoreStudentRepository implements StudentRepository {
  final String schoolId;
  final FirebaseFirestore _db;

  FirestoreStudentRepository({required this.schoolId, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('schools').doc(schoolId).collection('students');

  // <-- BARU: timeout 15 detik, konsisten sama firestore_report_repository.dart
  // — biar konsisten kalau ada query yang nyangkut, gak diem-diem forever.
  static const _timeout = Duration(seconds: 15);

  @override
  Future<Student?> getById(String studentId) async {
    final doc = await _col
        .doc(studentId)
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout, onTimeout: () => throw TimeoutException('getById($studentId) timeout'));
    if (!doc.exists) return null;
    return Student.fromJson(doc.data()!);
  }

  @override
  Future<List<Student>> getAll() async {
    final snap = await _col
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout, onTimeout: () => throw TimeoutException('getAll() students timeout'));
    return snap.docs.map((d) => Student.fromJson(d.data())).toList();
  }
}
