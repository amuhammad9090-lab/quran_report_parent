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
  // <-- BERSIH (audit biaya Firestore read, lanjutan): dulu ada
  // `getRecordsForStudent`/`watchRecordsForStudent` di sini — versi
  // one-time/listener TANPA batas tanggal, narik SELURUH riwayat laporan
  // santri sekaligus. Sudah tidak dipanggil dari mana pun sejak
  // [DashboardProvider] pindah ke [watchRecentRecordsForStudent] +
  // [getLifetimeStats] + [getRecordsForStudentBefore] di bawah — DIHAPUS
  // total (bukan cuma dibiarkan nganggur) supaya tidak ada yang nanti
  // tidak sadar manggil versi unbounded-nya lagi.
  //
  // 3 method yang aktif dipakai sekarang:
  // 1. [watchRecentRecordsForStudent] — listener utama, dibatasi jendela
  //    waktu, jadi biayanya punya plafon.
  // 2. [getLifetimeStats] — angka "sepanjang riwayat" (total baris,
  //    rasio kehadiran) yang TETAP akurat lifetime, dihitung via
  //    Firestore aggregate query (count()/sum()) — bukan fold dokumen.
  // 3. [getRecordsForStudentBefore] — buat filter "Semua" di layar
  //    Perkembangan, dipanggil LAZY cuma sekali pas orang tua beneran
  //    pilih filter itu (bukan otomatis tiap buka app).

  /// Live listener Firestore (`.snapshots()`), dibatasi cuma laporan
  /// sejak [since] (inklusif) — emit ulang daftar terbaru setiap kali ada
  /// perubahan di koleksi `laporan` yang cocok filter kelas+halaqoh+
  /// namaAnak milik [student]. Ini yang dipakai [DashboardProvider]
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
