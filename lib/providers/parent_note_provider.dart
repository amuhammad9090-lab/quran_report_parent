import 'package:flutter/foundation.dart';

import '../data/models/parent_note.dart';
import '../data/models/santri_record.dart';
import '../data/models/student.dart';
import '../data/repositories/parent_note_repository.dart';

/// State untuk kartu "Catatan untuk Guru" di Dashboard: kirim catatan
/// baru + daftar catatan terakhir yang sudah dikirim (dengan status
/// terkirim/sudah dibaca guru).
class ParentNoteProvider extends ChangeNotifier {
  final ParentNoteRepository repository;
  final Student student;

  ParentNoteProvider({required this.repository, required this.student});

  bool isSending = false;
  bool isLoadingHistory = false;
  String? error;
  List<ParentNote> recent = [];

  Future<void> loadRecent() async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      recent = await repository.getRecentForStudent(student, limit: 5);
    } catch (e) {
      // Diamkan di UI utama — riwayat catatan sifatnya pelengkap, tidak
      // boleh bikin seluruh Dashboard terlihat error kalau ini gagal.
      debugPrint('ParentNoteProvider.loadRecent GAGAL: $e');
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// [latestRecord] (kalau ada) dipakai untuk isi `guruOwnerId` — guru
  /// yang membuat laporan terakhir santri ini, supaya app guru tahu
  /// siapa yang perlu menerima notifikasi.
  Future<bool> sendNote(String message, {SantriRecord? latestRecord}) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      error = 'Catatan tidak boleh kosong.';
      notifyListeners();
      return false;
    }

    isSending = true;
    error = null;
    notifyListeners();
    try {
      await repository.send(
        student: student,
        message: trimmed,
        guruOwnerId: latestRecord?.ownerId,
      );
      await loadRecent();
      return true;
    } catch (e) {
      debugPrint('ParentNoteProvider.sendNote GAGAL: $e');
      error = 'Gagal mengirim catatan. Coba lagi.';
      notifyListeners();
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}
