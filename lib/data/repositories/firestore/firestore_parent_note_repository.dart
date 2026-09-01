import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/parent_note.dart';
import '../../models/student.dart';
import '../parent_note_repository.dart';

/// Baca/tulis `schools/{schoolId}/parentNotes/{id}`.
///
/// Ini SATU-SATUNYA repository di portal orang tua yang benar-benar
/// menulis ke Firestore (bandingkan dengan `firestore_report_repository.dart`
/// yang murni baca). Aturan keamanannya ada di `firestore.rules` —
/// `allow create` khusus koleksi ini mengizinkan santri yang sedang
/// login menulis dokumen SELAMA `studentId`-nya cocok dengan
/// `myAccount().studentId` sendiri (tidak bisa mengatasnamakan santri
/// lain) dan `isRead` dikirim `false` (tidak bisa langsung menandai
/// catatannya sendiri "sudah dibaca").
///
/// CATATAN UNTUK SISI APP GURU (tidak ada di repo ini): supaya catatan
/// ini benar-benar "muncul di notif app guru" seperti diminta, app guru
/// perlu (1) listen ke koleksi ini — query
/// `where('guruOwnerId', isEqualTo: uidGuruYangLogin)` atau, kalau mau
/// semua guru kebagian, `where('kelas', ...).where('halaqoh', ...)` —
/// lalu render badge/notifikasi untuk dokumen `isRead == false`, dan
/// (2) menulis `isRead: true` (lewat `update`) begitu guru membuka
/// notifikasi itu. Skema field dokumennya persis seperti [ParentNote].
class FirestoreParentNoteRepository implements ParentNoteRepository {
  final String schoolId;
  final FirebaseFirestore _db;

  FirestoreParentNoteRepository({required this.schoolId, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('schools').doc(schoolId).collection('parentNotes');

  @override
  Future<void> send({
    required Student student,
    required String message,
    String? guruOwnerId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    await _col.add({
      'studentId': student.id,
      'namaAnak': student.nama,
      'kelas': student.kelas,
      'halaqoh': student.halaqoh,
      'guruOwnerId': guruOwnerId,
      'message': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Kirim catatan timeout 15 detik (studentId=${student.id})',
      ),
    );
  }

  @override
  Future<List<ParentNote>> getRecentForStudent(Student student, {int limit = 5}) async {
    final snap = await _col
        .where('studentId', isEqualTo: student.id)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get(const GetOptions(source: Source.server))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Ambil catatan orang tua timeout 15 detik (studentId=${student.id})',
          ),
        );

    return snap.docs.map((d) {
      final data = d.data();
      final ts = data['createdAt'];
      return ParentNote.fromJson(d.id, {
        ...data,
        'createdAt': ts is Timestamp ? ts.toDate() : null,
      });
    }).toList();
  }
}
