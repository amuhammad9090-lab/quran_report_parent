import '../models/student.dart';
import '../models/weekly_recap.dart';

/// Abstraksi sumber data [WeeklyRecap] untuk SATU santri. Pola sama
/// persis dengan [ReportRepository] (murni baca, tidak ada write di sisi
/// portal orang tua) — implementasi production ada di
/// `data/repositories/firestore/firestore_weekly_recap_repository.dart`.
abstract class WeeklyRecapRepository {
  /// Rekap pekanan terbaru milik [student], terbaru dulu. [limit]
  /// membatasi berapa pekan ke belakang yang diambil (histori rekap bisa
  /// terus bertambah tiap pekan, tidak perlu ambil semuanya sekaligus).
  Future<List<WeeklyRecap>> getRecentForStudent(Student student, {int limit = 12});
}
