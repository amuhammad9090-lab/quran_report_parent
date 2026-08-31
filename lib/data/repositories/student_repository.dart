import '../models/student.dart';

/// Abstraksi sumber data [Student]. UI/provider hanya bergantung pada
/// interface ini — implementasi production ada di
/// `data/repositories/firestore/firestore_student_repository.dart`
/// ([FirestoreStudentRepository]).
///
/// <-- BARU: MockStudentRepository (implementasi development STEP 4-9)
/// sudah dibuang dari file ini — sudah tidak dipakai sejak STEP 10
/// (backend Firestore beneran), cuma bikin bingung kalau dibiarin.
abstract class StudentRepository {
  Future<Student?> getById(String studentId);

  /// Dipakai HANYA oleh [ManageAccountsScreen] (admin) untuk memilih
  /// santri saat membuat akun baru — TIDAK pernah dipanggil dari sisi
  /// orang tua yang sudah login (mereka cuma boleh lihat [Student] milik
  /// mereka sendiri lewat [getById] + scope).
  Future<List<Student>> getAll();
}
