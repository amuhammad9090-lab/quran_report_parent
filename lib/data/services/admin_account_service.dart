import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/utils/app_config.dart';
import '../../core/utils/parent_auth_constants.dart';
import '../../firebase_options.dart';

/// Semua operasi admin (baca daftar santri/akun, buat akun, nonaktifkan)
/// LEWAT Firestore/Firebase Auth LANGSUNG — sengaja TANPA Cloud
/// Functions, supaya tidak butuh plan Blaze. Aman karena:
///  - Admin login pakai Firebase Auth SUNGGUHAN (lihat [AdminAuthService]
///    di file yang sama) — `firestore.rules` cuma izinkan baca/tulis
///    koleksi ini kalau `request.auth.token.email` cocok daftar admin
///    di rules (BUKAN kalau berhasil login sebagai admin — enforcement
///    beneran ada di server/rules, sama seperti desain login santri).
///  - Bikin akun santri (Firebase Auth user) baru pakai SECONDARY
///    FirebaseApp instance — supaya proses create-user TIDAK
///    menggantikan sesi login admin yang sedang aktif (kalau pakai
///    instance default, `createUserWithEmailAndPassword` otomatis
///    sign-in sebagai user baru itu & admin ke-logout).
class AdminAccountService {
  final FirebaseFirestore _db;

  AdminAccountService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _studentsCol =>
      _db.collection('schools').doc(kSchoolId).collection('students');

  CollectionReference<Map<String, dynamic>> get _accountsCol =>
      _db.collection('schools').doc(kSchoolId).collection('santriAccounts');

  Future<List<Map<String, dynamic>>> listStudents() async {
    final snap = await _studentsCol.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> listAccounts() async {
    final snap = await _accountsCol.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Return {'username': ..., 'password': ...} — password plaintext
  /// SEKALI ini saja, buat ditunjukkan ke admin, tidak pernah tersimpan
  /// di Firestore (cuma di Firebase Auth, ter-hash otomatis olehnya).
  Future<Map<String, String>> createAccount({
    required String studentId,
    required String username,
    required String password,
  }) async {
    final email = usernameToSyntheticEmail(username);

    // Secondary app instance — lihat dokumentasi class.
    final secondaryApp = await Firebase.initializeApp(
      name: 'admin-create-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await secondaryAuth.signOut();

      await _accountsCol.doc(uid).set({
        'studentId': studentId,
        'username': username.trim().toLowerCase(),
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      });

      return {'username': username, 'password': password};
    } finally {
      await secondaryApp.delete();
    }
  }

  /// Nonaktifkan/aktifkan CUKUP lewat field `isActive` di Firestore —
  /// TIDAK perlu men-disable akun Firebase Auth-nya (yang butuh Admin
  /// SDK/Cloud Function). `AuthProvider.login()` sudah cek `isActive`
  /// SETELAH sign-in Firebase Auth berhasil, dan langsung sign-out paksa
  /// kalau false — jadi santri tetap efektif tidak bisa masuk, walau
  /// kredensial Firebase Auth-nya sendiri masih teknisnya valid.
  Future<void> setAccountActive(String accountId, bool isActive) async {
    await _accountsCol.doc(accountId).update({'isActive': isActive});
  }
}

/// Login ADMIN (email/password Firebase Auth SUNGGUHAN — beda dari PIN
/// lokal versi sebelumnya). Instance `FirebaseAuth.instance` DEFAULT
/// dipakai di sini (beda dari `AuthProvider` santri yang juga pakai
/// default instance) — SENGAJA begitu, karena area admin
/// (`/admin`) dan area orang tua (`/`) tidak pernah dibuka bersamaan
/// dalam satu sesi browser yang sama secara wajar (beda rute, beda
/// tujuan pengguna). Kalau nanti itu jadi masalah nyata, tinggal pindah
/// ke secondary app juga.
class AdminAuthService {
  final FirebaseAuth _auth;
  AdminAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Future<void> login(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> logout() => _auth.signOut();
}
