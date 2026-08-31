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
    return SantriAccount(
      id: uid,
      studentId: data['studentId'] as String,
      username: data['username'] as String,
      passwordHash: '', // tidak dipakai lagi di desain Firebase Auth
      isActive: data['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
