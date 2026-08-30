// BELUM AKTIF — file ini SENGAJA di luar lib/ supaya project sekarang
// tetap bisa di-build & demo tanpa Firebase. Begitu project Firebase
// sudah dibuat & `flutterfire configure` dijalankan:
//   1. Uncomment firebase_core & cloud_firestore di pubspec.yaml
//   2. Pindahkan file ini ke lib/data/repositories/firestore/
//   3. Ganti Provider<StudentRepository> di main.dart jadi
//      FirestoreStudentRepository(schoolId: '...')

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../lib/data/models/student.dart';
import '../../lib/data/repositories/student_repository.dart';

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

  @override
  Future<Student?> getById(String studentId) async {
    final doc = await _col.doc(studentId).get();
    if (!doc.exists) return null;
    return Student.fromJson(doc.data()!);
  }

  @override
  Future<List<Student>> getAll() async {
    final snap = await _col.get();
    return snap.docs.map((d) => Student.fromJson(d.data())).toList();
  }
}
