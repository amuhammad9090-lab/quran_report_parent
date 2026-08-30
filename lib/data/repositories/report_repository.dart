import '../models/enums.dart';
import '../models/santri_record.dart';
import '../models/student.dart';

/// Abstraksi sumber data [SantriRecord] untuk SATU santri (portal orang
/// tua tidak pernah butuh daftar lintas-santri).
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
abstract class ReportRepository {
  /// Semua laporan milik [student], terurut terbaru dulu.
  Future<List<SantriRecord>> getRecordsForStudent(Student student);
}

/// TODO(STEP 10 - integrasi backend): ganti dengan implementasi backend
/// yang membaca dari sumber data yang SAMA dengan app guru (read-only).
/// Query production harus tetap memfilter di level backend/database
/// (bukan ambil semua lalu filter di client) — lihat aturan keamanan.
class MockReportRepository implements ReportRepository {
  final List<SantriRecord> _seed;

  MockReportRepository({List<SantriRecord>? seed}) : _seed = seed ?? _defaultSeed;

  // Data contoh untuk keperluan development STEP 4-9 — kelas/halaqoh/nama
  // SENGAJA sama persis dengan seed di MockStudentRepository, karena
  // matching dilakukan lewat 3 field itu (lihat dokumentasi class).
  static final _defaultSeed = <SantriRecord>[
    SantriRecord(
      id: 'rec_001',
      tanggal: DateTime(2026, 8, 26),
      kelas: '789',
      halaqoh: 'ABCD',
      namaAnak: 'Ahmad Fauzan',
      status: HafalanStatus.tahfizh,
      keterangan: Keterangan.hadir,
      tahfizhSegments: const [
        TahfizhSegment(
          surahNumber: 67,
          surahName: 'Al-Mulk',
          ayatMulai: 1,
          ayatSelesai: 15,
          totalBaris: 30,
          lineIds: [],
        ),
      ],
      catatan: "Alhamdulillah, bacaan semakin lancar. Perlu meningkatkan muroja'ah pada hafalan surah Al-Mulk.",
    ),
    SantriRecord(
      id: 'rec_002',
      tanggal: DateTime(2026, 8, 24),
      kelas: '789',
      halaqoh: 'ABCD',
      namaAnak: 'Ahmad Fauzan',
      status: HafalanStatus.murojaahTasmi,
      keterangan: Keterangan.hadir,
      tilawahSegments: const [
        TilawahSegment(surahNumber: 78, surahName: "An-Naba'", ayatMulai: 1, ayatSelesai: 20),
      ],
    ),
    SantriRecord(
      id: 'rec_003',
      tanggal: DateTime(2026, 8, 22),
      kelas: '789',
      halaqoh: 'ABCD',
      namaAnak: 'Ahmad Fauzan',
      status: HafalanStatus.tahsin,
      keterangan: Keterangan.izinSakit,
      tahsinMode: TahsinMode.wafa,
      wafaLevel: WafaLevel.wafa3,
      halamanWafa: '12-13',
    ),
  ];

  @override
  Future<List<SantriRecord>> getRecordsForStudent(Student student) async {
    final matched = _seed.where((r) {
      final sameKelas = r.kelas.trim() == student.kelas.trim();
      final sameHalaqoh = r.halaqoh.trim().toLowerCase() == student.halaqoh.trim().toLowerCase();
      final sameNama = r.namaAnak.trim().toLowerCase() == student.nama.trim().toLowerCase();
      return sameKelas && sameHalaqoh && sameNama;
    }).toList();

    matched.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return matched;
  }
}
