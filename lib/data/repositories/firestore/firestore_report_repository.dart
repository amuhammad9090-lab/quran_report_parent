// AKTIF — project Firebase: quran-reportweb.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/report_lifetime_stats.dart';
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
  /// koleksi kosong/salah. Dipakai semua method di kelas ini yang butuh
  /// `accountId` (langsung `throw` untuk method `async`, atau dibungkus
  /// `Stream.error(...)` untuk method yang return `Stream` — lihat
  /// [watchRecentRecordsForStudent]).
  GuruBelumDitugaskanException _missingAccountIdError(Student student) =>
      GuruBelumDitugaskanException(student);

  /// Filter kelas+halaqoh+namaAnak yang sama dipakai SEMUA method di
  /// kelas ini — diekstrak biar [watchRecentRecordsForStudent],
  /// [getLifetimeStats], dan [getRecordsForStudentBefore] di bawah tidak
  /// mengulang 3 baris `.where(...)` yang sama persis.
  Query<Map<String, dynamic>> _baseQuery(String accountId, Student student) => _col(accountId)
      .where('kelas', isEqualTo: student.kelas)
      .where('halaqoh', isEqualTo: student.halaqoh)
      .where('namaAnak', isEqualTo: student.nama);

  // `tanggal` disimpan sebagai STRING ISO-8601 (lihat `SantriRecord.toJson`
  // — `tanggal.toIso8601String()`), bukan Firestore Timestamp. Selama
  // SEMUA penulisan konsisten pakai format itu (memang begitu — cuma app
  // guru yang menulis field ini), perbandingan `.where('tanggal', ...)`
  // di bawah aman dilakukan sebagai perbandingan string, karena format
  // ISO-8601 lebar-tetap terurut leksikografis sama seperti terurut
  // waktu.
  String _isoCutoff(DateTime dt) => dt.toIso8601String();

  @override
  Stream<List<SantriRecord>> watchRecentRecordsForStudent(Student student, {required DateTime since}) {
    // <-- BARU (audit biaya Firestore read — lihat penjelasan panjang di
    // `report_repository.dart`): listener utama dashboard, TAPI dibatasi
    // `tanggal >= since` (bukan seluruh riwayat tanpa batas). Ini yang
    // dipakai [DashboardProvider] sehari-hari, supaya biaya read TIDAK
    // terus membesar seiring bertambahnya riwayat laporan santri — dia
    // punya plafon (~[since] sampai sekarang), bukan sepanjang riwayat.
    final accountId = student.guruAccountId;
    if (accountId == null) {
      return Stream.error(_missingAccountIdError(student));
    }
    return _baseQuery(accountId, student)
        .where('tanggal', isGreaterThanOrEqualTo: _isoCutoff(since))
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SantriRecord.fromJson(d.data())).toList());
  }

  @override
  Future<List<SantriRecord>> getRecordsForStudentBefore(Student student, {required DateTime before}) async {
    // <-- BARU: one-time fetch (BUKAN listener) buat laporan LEBIH LAMA
    // dari jendela default [watchRecentRecordsForStudent] — dipanggil
    // LAZY, cuma sekali, cuma kalau orang tua benar-benar pilih filter
    // "Semua" di layar Perkembangan (lihat `DashboardProvider`). Bukan
    // listener karena data lama seperti ini tidak butuh update real-time.
    final accountId = student.guruAccountId;
    if (accountId == null) throw _missingAccountIdError(student);

    final snap = await _baseQuery(accountId, student)
        .where('tanggal', isLessThan: _isoCutoff(before))
        .orderBy('tanggal', descending: true)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Query laporan lama (before $before) timeout 15 detik '
            '(kelas=${student.kelas}, halaqoh=${student.halaqoh}, namaAnak=${student.nama})',
          ),
        );

    return snap.docs.map((d) => SantriRecord.fromJson(d.data())).toList();
  }

  // Keterangan yang dihitung "hadir secara fisik" buat kehadiranRatio —
  // SAMA PERSIS dengan `Keterangan.hadir || Keterangan.isSanksiTanpaSetoran`
  // di model (tidakSetoran/tidakTahsin/tidakMurojaah = hadir tapi nggak
  // setor, tetap dihitung hadir). Dituliskan literal di sini (bukan
  // di-derive dari enum) karena aggregate query butuh nilai STRING
  // `.name` yang dikirim ke Firestore, bukan enum Dart-nya.
  static const _hadirSecaraFisikValues = ['hadir', 'tidakSetoran', 'tidakTahsin', 'tidakMurojaah'];

  @override
  Future<ReportLifetimeStats> getLifetimeStats(Student student) async {
    // <-- BARU (audit biaya Firestore read): angka "sepanjang riwayat"
    // (totalBarisTercapai, kehadiranRatio) dulu dihitung dengan nge-fold
    // SELURUH dokumen `laporan` santri di client — Dashboard yang cuma
    // butuh 2 angka ini akhirnya diam-diam membayar biaya baca SEMUA
    // dokumen. Aggregate query Firestore (`count()`/`aggregate(sum(...))`)
    // menghitung angka LIFETIME yang SAMA PERSIS langsung di server —
    // biayanya cuma 1 read per hingga 1000 dokumen yang cocok, BUKAN 1
    // read per dokumen. 3 query kecil di bawah (total, hadir, sum
    // totalBaris) jauh lebih murah daripada fetch semua dokumen, berapa
    // pun panjang riwayat santrinya.
    final accountId = student.guruAccountId;
    if (accountId == null) throw _missingAccountIdError(student);

    final base = _baseQuery(accountId, student);

    // Sengaja sequential (bukan Future.wait) — 3 query ini masing-masing
    // sudah SANGAT ringan (aggregate, bukan fetch dokumen), jadi selisih
    // latensi dari paralel ke sequential tidak signifikan buat data yang
    // cuma dipakai sekali per sesi, dan ini lebih gampang dibaca.
    final totalSnap = await base.count().get().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('getLifetimeStats: count total timeout 15 detik'),
        );

    final hadirSnap = await base
        .where('keterangan', whereIn: _hadirSecaraFisikValues)
        .count()
        .get()
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('getLifetimeStats: count hadir timeout 15 detik'),
        );

    final sumSnap = await base.aggregate(sum('totalBaris')).get().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('getLifetimeStats: sum totalBaris timeout 15 detik'),
        );

    return ReportLifetimeStats(
      totalCount: totalSnap.count ?? 0,
      hadirCount: hadirSnap.count ?? 0,
      totalBarisTercapai: (sumSnap.getSum('totalBaris') ?? 0).toInt(),
    );
  }
}

