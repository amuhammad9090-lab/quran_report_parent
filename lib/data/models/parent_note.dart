/// Satu catatan/feedback yang dikirim ORANG TUA ke guru pembimbing —
/// arah kebalikan dari `SantriRecord.catatan` (yang isinya catatan guru
/// untuk orang tua). Disimpan di koleksi terpisah `parentNotes` (BUKAN
/// menulis ke `santriRecords`, yang tetap murni domain guru) supaya
/// portal orang tua tetap tidak pernah menyentuh data laporan sama
/// sekali — lihat catatan arsitektur di
/// `parent_note_repository.dart`.
class ParentNote {
  final String id;
  final String studentId;
  final String namaAnak;
  final String kelas;
  final String halaqoh;

  /// uid guru (app guru, akun anonim) yang membuat laporan TERAKHIR
  /// santri ini saat catatan dikirim — dipakai app guru untuk tahu siapa
  /// yang perlu menerima notifikasi. Boleh null kalau santri belum
  /// pernah punya laporan sama sekali (guru mana pun yang pegang
  /// kelas/halaqoh itu bisa membacanya sebagai catatan umum).
  final String? guruOwnerId;

  final String message;
  final DateTime? createdAt;

  /// Ditandai true oleh app guru setelah notifikasi dibuka/dibaca.
  /// Portal orang tua tidak pernah mengubah field ini sendiri.
  final bool isRead;

  const ParentNote({
    required this.id,
    required this.studentId,
    required this.namaAnak,
    required this.kelas,
    required this.halaqoh,
    required this.message,
    this.guruOwnerId,
    this.createdAt,
    this.isRead = false,
  });

  factory ParentNote.fromJson(String id, Map<String, dynamic> json) {
    final ts = json['createdAt'];
    return ParentNote(
      id: id,
      studentId: json['studentId'] as String? ?? '',
      namaAnak: json['namaAnak'] as String? ?? '',
      kelas: json['kelas'] as String? ?? '',
      halaqoh: json['halaqoh'] as String? ?? '',
      guruOwnerId: json['guruOwnerId'] as String?,
      message: json['message'] as String? ?? '',
      // createdAt disimpan sebagai Firestore Timestamp — dikonversi di
      // implementasi repository (lihat FirestoreParentNoteRepository)
      // sebelum sampai di sini, supaya model ini tidak bergantung pada
      // package cloud_firestore.
      createdAt: ts is DateTime ? ts : null,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
