// AKTIF — project Firebase: quran-reportweb.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/santri_record.dart';
import '../../models/student.dart';
import '../../repositories/report_repository.dart';

/// Baca [SantriRecord] dari `schools/{schoolId}/accounts/{guruAccountId}/laporan/{id}`.
///
/// BERUBAH (migrasi skema nested per-guru, sinkron dengan app guru &
/// firestore.rules): dulu flat di `schools/{schoolId}/santriRecords`.
/// Koleksi flat itu SUDAH DIHAPUS dari firestore.rules sisi app guru,
/// jadi kalau repo ini masih baca dari situ hasilnya permission-denied
/// ("Gagal memuat data") — bukan soal koneksi. [Student.guruAccountId]
/// (ditulis app guru di dokumen `students/{id}`) menentukan subcollection
/// guru mana yang harus dibaca.
///
/// PENTING (sesuai aturan keamanan brief): query di-filter di level
/// Firestore lewat `.where(...)` — BUKAN ambil semua lalu filter di
/// client. Karena `SantriRecord` tidak punya `studentId` (lihat catatan
/// arsitektur di `report_repository.dart` — desain existing app guru,
/// bukan sesuatu yang kita ubah), filter tetap pakai kombinasi
/// kelas+halaqoh+namaAnak, TAPI dieksekusi sebagai Firestore query
/// (`.where('kelas', ...).where('halaqoh', ...).where('namaAnak', ...)`),
/// jadi dokumen milik santri lain TIDAK PERNAH terkirim ke client sama
/// sekali — bukan cuma disembunyikan di UI.
class FirestoreReportRepository implements ReportRepository {
  final String schoolId;
  final FirebaseFirestore _db;

  FirestoreReportRepository({required this.schoolId, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String guruAccountId) => _db
      .collection('schools')
      .doc(schoolId)
      .collection('accounts')
      .doc(guruAccountId)
      .collection('laporan');

  /// Guru pembimbing untuk santri ini belum ke-assign
  /// ([Student.guruAccountId] null) — gagal jelas, bukan diam-diam baca
  /// koleksi kosong/salah.
  ///
  /// PENTING: ini cuma BIKIN objek exception-nya (tidak throw langsung),
  /// beda dari sebelumnya. Alasannya ada di [watchRecordsForStudent] —
  /// intinya method itu bukan `async`, jadi `throw` langsung di badannya
  /// meledak SAAT DIPANGGIL (bukan lewat jalur Stream), padahal dia
  /// dipanggil sinkron dari `DashboardProvider.load()` yang notabene
  /// dipanggil sinkron lagi dari `create:` callback provider di
  /// `MainShell.build`. Efeknya: exception itu ngebom widget tree lagi
  /// dibangun, bukan ketangkep `onError` Stream — inilah yang bikin app
  /// crash total (cascade "Another exception was thrown:
  /// DiagnosticsProperty<void>") pas ada santri yang guru pembimbingnya
  /// belum di-assign, alih-alih tampil sebagai layar "gagal memuat data"
  /// yang rapi. Dengan dijadikan builder biasa, kedua caller yang beda
  /// gaya (async Future vs Stream) sama-sama bisa pilih cara pas buat
  /// nyalurkan error-nya — lihat pemakaiannya di bawah.
  GuruBelumDitugaskanException _missingAccountIdError(Student student) =>
      GuruBelumDitugaskanException(student);

  @override
  Future<List<SantriRecord>> getRecordsForStudent(Student student) async {
    final accountId = student.guruAccountId;
    // Aman throw langsung di sini: method ini `async`, jadi throw
    // sinkron otomatis dibungkus Dart jadi Future.error — caller yang
    // await + try/catch tetap ketangkep normal.
    if (accountId == null) throw _missingAccountIdError(student);
    final col = _col(accountId);
    // Firestore butuh exact-match string untuk .where() — namaAnak
    // dibandingkan case-sensitive di query (beda dari MockReportRepository
    // yang case-insensitive di Dart). Kalau nanti ada mismatch kapitalisasi
    // antara Student.nama & SantriRecord.namaAnak, pertimbangkan simpan
    // field tambahan `namaAnakLower` khusus buat query (denormalisasi
    // umum di Firestore) — BUKAN mengubah cara app guru menyimpan nama.
    //
    // <-- BARU: .timeout(...) — sebelumnya kalau query ini nyangkut
    // (apa pun sebabnya: koneksi, index, dll), await-nya nunggu
    // SELAMANYA, bikin UI muter tanpa akhir. Sekarang dipaksa gagal
    // eksplisit setelah 15 detik, supaya try/catch di DashboardProvider
    // KETANGKEP dan errornya kelihatan, bukan nyangkut diam-diam.
    // .get(const GetOptions(source: Source.server)) — <-- BARU juga,
    // maksa ambil dari server (bukan diam-diam nunggu cache lokal yang
    // mungkin belum ke-sync).
    final snap = await col
        .where('kelas', isEqualTo: student.kelas)
        .where('halaqoh', isEqualTo: student.halaqoh)
        .where('namaAnak', isEqualTo: student.nama)
        .orderBy('tanggal', descending: true)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Query santriRecords timeout 15 detik (kelas=${student.kelas}, '
            'halaqoh=${student.halaqoh}, namaAnak=${student.nama})',
          ),
        );

    return snap.docs.map((d) => SantriRecord.fromJson(d.data())).toList();
  }

  @override
  Stream<List<SantriRecord>> watchRecordsForStudent(Student student) {
    // Query FILTER-nya sama persis dengan getRecordsForStudent di atas
    // (kelas+halaqoh+namaAnak exact match di level Firestore) — cuma
    // `.snapshots()` dipakai sebagai ganti `.get()` sekali, jadi listener
    // ini otomatis emit ulang setiap kali ada dokumen yang cocok
    // ditambah/diubah/dihapus. `includeMetadataChanges: false` (default)
    // supaya tidak emit dua kali untuk 1 perubahan yang sama (sekali dari
    // cache lokal, sekali konfirmasi server) — cukup 1 emit begitu server
    // konfirmasi.
    final accountId = student.guruAccountId;
    // FIX: dulu `if (accountId == null) _missingAccountId(student);` throw
    // LANGSUNG di sini — itu penyebab crash di log (lihat penjelasan
    // panjang di `_missingAccountIdError` di atas). Sekarang error-nya
    // disalurkan lewat `Stream.error(...)`, jadi lewat jalur Stream yang
    // normal dan otomatis ketangkep `onError` di `DashboardProvider.load`
    // TANPA perlu ubah apa pun di provider-nya — persis kayak error
    // Firestore lain (mis. permission-denied): jadi pesan gagal di UI,
    // bukan crash total.
    if (accountId == null) {
      return Stream.error(_missingAccountIdError(student));
    }
    return _col(accountId)
        .where('kelas', isEqualTo: student.kelas)
        .where('halaqoh', isEqualTo: student.halaqoh)
        .where('namaAnak', isEqualTo: student.nama)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SantriRecord.fromJson(d.data())).toList());
  }
}

