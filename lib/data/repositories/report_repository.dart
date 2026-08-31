import '../models/student.dart';
import '../models/santri_record.dart';

/// Abstraksi sumber data [SantriRecord] untuk SATU santri (portal orang
/// tua tidak pernah butuh daftar lintas-santri). Implementasi production
/// ada di `data/repositories/firestore/firestore_report_repository.dart`
/// ([FirestoreReportRepository]).
///
/// PENTING — soal matching: [SantriRecord] TIDAK punya `studentId` (lihat
/// catatan di `AccessScope` app guru — ini memang desain existing, bukan
/// sesuatu yang kita ubah). Guru sendiri men-scope datanya lewat
/// kelas+halaqoh, BUKAN foreign key. Supaya konsisten dan tidak
/// menciptakan cara matching baru yang berbeda dari app guru, portal
/// parent memfilter laporan dengan cara yang SAMA: `kelas` + `halaqoh`
/// cocok PERSIS dengan data [Student], dan `namaAnak` cocok
/// (case-insensitive) dengan `Student.nama`. Ini dilakukan DI LEVEL
/// REPOSITORY (bukan filter di widget), sesuai aturan keras keamanan.
///
/// <-- BARU: MockReportRepository (implementasi development STEP 4-9)
/// sudah dibuang dari file ini — sudah tidak dipakai sejak STEP 10
/// (backend Firestore beneran), cuma bikin bingung kalau dibiarin.
abstract class ReportRepository {
  /// Semua laporan milik [student], terurut terbaru dulu.
  Future<List<SantriRecord>> getRecordsForStudent(Student student);
}
