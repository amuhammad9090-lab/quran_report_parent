import '../models/student.dart';

/// Abstraksi sumber data [Student]. UI/provider hanya bergantung pada
/// interface ini — implementasi Mock* nanti tinggal diganti implementasi
/// backend (Firestore/REST/dst) tanpa mengubah apa pun di atasnya.
abstract class StudentRepository {
  Future<Student?> getById(String studentId);

  /// Dipakai HANYA oleh [ManageAccountsScreen] (admin) untuk memilih
  /// santri saat membuat [SantriAccount] baru — TIDAK pernah dipanggil
  /// dari sisi orang tua yang sudah login (mereka cuma boleh lihat
  /// [Student] milik mereka sendiri lewat [getById] + scope).
  Future<List<Student>> getAll();
}

/// Implementasi sementara (belum ada backend). Struktur datanya SAMA
/// dengan production (`Student.fromJson`), supaya nanti gampang diganti.
///
/// TODO(STEP 10 - integrasi backend): ganti isi class ini dengan
/// implementasi yang baca dari backend production Quran Report (sumber
/// data yang sama dipakai app guru), bukan list hardcoded di bawah.
class MockStudentRepository implements StudentRepository {
  final List<Student> _seed;

  MockStudentRepository({List<Student>? seed}) : _seed = seed ?? _defaultSeed;

  static final _defaultSeed = <Student>[
    const Student(id: 'stu_001', nama: 'Ahmad Fauzan', kelas: '789', halaqoh: 'ABCD'),
    const Student(id: 'stu_002', nama: 'Siti Aisyah', kelas: '789', halaqoh: 'ABCD'),
  ];

  @override
  Future<Student?> getById(String studentId) async {
    try {
      return _seed.firstWhere((s) => s.id == studentId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Student>> getAll() async => List.unmodifiable(_seed);
}
