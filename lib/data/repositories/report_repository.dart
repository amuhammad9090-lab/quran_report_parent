import '../models/student.dart';
import '../models/santri_record.dart';
import '../models/report_lifetime_stats.dart';

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
  /// Semua laporan milik [student], terurut terbaru dulu. One-time fetch
  /// — dipertahankan buat kompatibilitas/kasus yang memang cuma butuh
  /// snapshot sekali (mis. testing), tapi [DashboardProvider] sekarang
  /// pakai [watchRecordsForStudent] di bawah supaya UI update sendiri
  /// begitu guru input/ubah laporan, tanpa orang tua perlu refresh manual.
  Future<List<SantriRecord>> getRecordsForStudent(Student student);

  /// Versi REAL-TIME dari [getRecordsForStudent] — live listener Firestore
  /// (`.snapshots()`), emit ulang daftar terbaru setiap kali ada
  /// perubahan di koleksi `santriRecords` yang cocok filter kelas+halaqoh+
  /// namaAnak milik [student]. Ini yang bikin "Catatan Guru" (dan semua
  /// data turunannya: progress hafalan, insight, dst) di Beranda muncul
  /// LANGSUNG begitu guru submit/edit laporan — tidak perlu buka-tutup
  /// app lagi.
  Stream<List<SantriRecord>> watchRecordsForStudent(Student student);

  // -----------------------------------------------------------------
  // BARU (audit biaya Firestore read): [watchRecordsForStudent] di atas
  // narik SELURUH riwayat laporan santri tanpa batas tanggal, sebagai 1
  // listener yang nyala sepanjang sesi — biayanya (jumlah dokumen yang
  // dibaca tiap kali app dibuka/listener nyambung ulang) MEMBESAR TERUS
  // seiring bertambahnya laporan, tanpa plafon. [DashboardProvider]
  // sekarang pakai 3 method di bawah ini sebagai gantinya:
  // 1. [watchRecentRecordsForStudent] — listener yang SAMA tapi dibatasi
  //    jendela waktu (lihat pemanggilnya), jadi biayanya punya plafon.
  // 2. [getLifetimeStats] — angka "sepanjang riwayat" (total baris,
  //    rasio kehadiran) yang TETAP akurat lifetime, dihitung via
  //    Firestore aggregate query (count()/sum()) — bukan fold dokumen.
  // 3. [getRecordsForStudentBefore] — buat filter "Semua" di layar
  //    Perkembangan, dipanggil LAZY cuma sekali pas orang tua beneran
  //    pilih filter itu (bukan otomatis tiap buka app).
  // -----------------------------------------------------------------

  /// Sama seperti [watchRecordsForStudent], tapi dibatasi cuma laporan
  /// sejak [since] (inklusif). Ini yang dipakai [DashboardProvider]
  /// sebagai listener utama sehari-hari.
  Stream<List<SantriRecord>> watchRecentRecordsForStudent(Student student, {required DateTime since});

  /// Statistik lifetime (lihat [ReportLifetimeStats]) — one-time fetch,
  /// dihitung server-side, TIDAK menarik dokumen laporan satu-satu.
  Future<ReportLifetimeStats> getLifetimeStats(Student student);

  /// Laporan yang tanggalnya SEBELUM [before] (lebih lama dari jendela
  /// default [watchRecentRecordsForStudent]) — one-time fetch, dipanggil
  /// LAZY cuma kalau orang tua benar-benar butuh (filter "Semua" di
  /// Perkembangan/History).
  Future<List<SantriRecord>> getRecordsForStudentBefore(Student student, {required DateTime before});
}

/// Dilempar/di-emit kalau [Student.guruAccountId] masih null — guru
/// pembimbing untuk kelas/halaqoh santri ini belum ditugaskan di app
/// guru. Ditaruh di sini (layer abstrak), bukan di
/// `firestore_report_repository.dart`, supaya [DashboardProvider] (yang
/// cuma boleh bergantung ke [ReportRepository], bukan implementasi
/// konkretnya) tetap bisa cek tipe error ini secara type-safe
/// (`e is GuruBelumDitugaskanException`) tanpa harus import Firestore.
class GuruBelumDitugaskanException implements Exception {
  final Student student;
  const GuruBelumDitugaskanException(this.student);

  @override
  String toString() =>
      'Student ${student.id} (${student.nama}) belum punya guruAccountId — '
      'guru pembimbing untuk kelas ${student.kelas}/halaqoh ${student.halaqoh} '
      'belum ke-assign di app guru.';
}
