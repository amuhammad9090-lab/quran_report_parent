// AKTIF — project Firebase: quran-reportweb. Login diverifikasi lewat
// Firebase Authentication (email sintetis), BUKAN passwordHash — lihat
// firestore.rules & AuthProvider.login() untuk alurnya.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/santri_account.dart';

/// Beda dari `SantriAccountRepository` interface yang di lib/ (yang masih
/// berbasis passwordHash) — repository ini SENGAJA versi baru, cuma baca
/// metadata (studentId, isActive) pakai UID Firebase Auth yang SUDAH
/// login, bukan cari-by-username-lalu-cek-password. Password sama sekali
/// tidak lewat sini.
class FirestoreSantriAccountRepository {
  final String schoolId;
  final FirebaseFirestore _db;

  FirestoreSantriAccountRepository({required this.schoolId, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('schools').doc(schoolId).collection('santriAccounts');

  /// [uid] = `FirebaseAuth.instance.currentUser!.uid` SETELAH sign-in
  /// berhasil — bukan sebelum. Rules `firestore.rules` cuma izinkan baca
  /// dokumen milik uid yang sedang login.
  Future<SantriAccount?> getByUid(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['isActive'] == false) return null;
    final photoTs = data['photoUpdatedAt'];
    return SantriAccount(
      id: uid,
      studentId: data['studentId'] as String,
      username: data['username'] as String,
      passwordHash: '', // tidak dipakai lagi di desain Firebase Auth
      isActive: data['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      photoBase64: data['photoBase64'] as String?,
      photoUpdatedAt: photoTs is Timestamp ? photoTs.toDate() : null,
    );
  }

  /// Simpan/hapus foto profil orang tua untuk akun [uid] SENDIRI.
  ///
  /// SENGAJA pakai `.set(..., SetOptions(merge: true))` cuma di 2 field
  /// ini (bukan tulis ulang dokumen penuh) — supaya field lain
  /// (studentId/username/isActive/dst, yang dikelola dari sisi
  /// admin/guru) tidak pernah ketiban tertimpa dari sisi orang tua.
  /// Ini SATU-SATUNYA operasi tulis milik portal orang tua selain
  /// `ParentNoteRepository` (lihat catatan arsitektur di sana) — dan
  /// scope-nya sengaja dibatasi ke dokumen akun MILIK SENDIRI, bukan
  /// data akademik santri (rules Firestore harus membatasi update field
  /// di sini cuma untuk `request.auth.uid == uid`, dan cuma untuk 2
  /// field `photoBase64`/`photoUpdatedAt`).
  ///
  /// [base64Data] null = hapus foto (balik ke fallback inisial).
  Future<void> updatePhoto(String uid, String? base64Data) {
    return _col.doc(uid).set({
      'photoBase64': base64Data ?? FieldValue.delete(),
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
