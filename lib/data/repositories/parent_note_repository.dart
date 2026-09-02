import '../models/parent_note.dart';
import '../models/student.dart';

/// Abstraksi untuk fitur "Catatan untuk Guru" — SATU-SATUNYA jalur
/// tulis yang dimiliki portal orang tua. Sengaja dipisah total dari
/// [ReportRepository] (yang murni baca `santriRecords`) supaya prinsip
/// "orang tua tidak pernah menulis laporan/data santri" tetap terjaga
/// walau sekarang ada 1 pengecualian tertulis: orang tua BOLEH menulis
/// ke koleksi barunya sendiri (`parentNotes`), bukan ke data guru.
///
/// Implementasi production: `firestore/firestore_parent_note_repository.dart`.
abstract class ParentNoteRepository {
  /// Kirim satu catatan baru untuk [student]. [guruOwnerId] opsional —
  /// isi dengan `ownerId` laporan terakhir santri (kalau ada) supaya app
  /// guru tahu siapa yang perlu dapat notifikasi.
  Future<void> send({
    required Student student,
    required String message,
    String? guruOwnerId,
  });

  /// Beberapa catatan TERAKHIR yang pernah dikirim orang tua untuk
  /// [student], terbaru dulu — dipakai menampilkan status kirim
  /// (terkirim/sudah dibaca guru) di Dashboard.
  Future<List<ParentNote>> getRecentForStudent(Student student, {int limit = 5});
}
