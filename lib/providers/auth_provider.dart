import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/access/parent_access_scope.dart';
import '../core/utils/parent_auth_constants.dart';
import '../data/models/student.dart';
import '../data/repositories/firestore/firestore_santri_account_repository.dart';
import '../data/repositories/student_repository.dart';

enum AuthStatus { unknown, loggedOut, loading, loggedIn, error }

/// Login SANTRI (bukan akun orang tua terpisah — lihat brief), read-only.
/// Tidak ada method apa pun di sini yang menulis ke [SantriRecord]/
/// [Student] — provider ini hanya menghasilkan [ParentAccessScope] untuk
/// dikonsumsi provider/repository lain.
///
/// STEP 10 (final): password diverifikasi lewat FIREBASE AUTH (bukan
/// `AuthHashService` lagi) — lihat catatan lengkap di
/// `firestore_santri_account_repository.dart` & `firestore.rules` untuk
/// alasan pergeseran desain ini. `FirebaseAuth.instance` di sini SELALU
/// instance DEFAULT (bukan yang dipakai admin bikin akun — lihat
/// `admin_account_service.dart`, itu pakai secondary app instance
/// terpisah supaya tidak numpang-ganti sesi login santri yang aktif).
class AuthProvider extends ChangeNotifier {
  final FirestoreSantriAccountRepository accountRepository;
  final StudentRepository studentRepository;
  final FirebaseAuth _auth;

  AuthProvider({
    required this.accountRepository,
    required this.studentRepository,
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  AuthStatus status = AuthStatus.unknown;
  String? errorMessage;
  ParentAccessScope? scope;
  Student? currentStudent;

  Future<void> login(String username, String password) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final email = usernameToSyntheticEmail(username);
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) throw StateError('uid null setelah sign-in berhasil');

      final ok = await _loadAccountAndStudent(uid);
      if (!ok) {
        await _auth.signOut();
        status = AuthStatus.error;
        errorMessage ??= 'Akun tidak ditemukan atau sudah dinonaktifkan.';
        notifyListeners();
        return;
      }

      status = AuthStatus.loggedIn;
      notifyListeners();
    } on FirebaseAuthException {
      // Sengaja tidak bedakan "user-not-found" vs "wrong-password" ke
      // pengguna — pesan generik supaya tidak bocorin username mana yang
      // valid (enumeration attack).
      status = AuthStatus.error;
      errorMessage = 'Username atau password salah.';
      notifyListeners();
    } catch (_) {
      status = AuthStatus.error;
      errorMessage = 'Terjadi kesalahan. Coba lagi.';
      notifyListeners();
    }
  }

  /// Dipanggil SEKALI di awal (lihat `_AuthGate` di app.dart) buat
  /// memulihkan sesi Firebase Auth yang mungkin masih tersimpan di
  /// browser (mis. tab di-refresh / pull-to-refresh) — supaya orang tua
  /// TIDAK perlu login ulang tiap kali halaman dimuat ulang, cuma
  /// [logout] manual yang beneran mengakhiri sesi.
  Future<void> restoreSession() async {
    status = AuthStatus.loading;
    notifyListeners();

    // Di web, `currentUser` bisa masih null SESAAT walau sebenarnya ada
    // sesi tersimpan (SDK belum selesai rehydrate dari IndexedDB). Kalau
    // null, tunggu emisi PERTAMA dari authStateChanges() biar nggak
    // salah nganggap "belum pernah login".
    final user = _auth.currentUser ?? await _auth.authStateChanges().first;
    if (user == null) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }

    final ok = await _loadAccountAndStudent(user.uid);
    if (!ok) {
      await _auth.signOut();
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }

    status = AuthStatus.loggedIn;
    notifyListeners();
  }

  /// Isi [currentStudent]/[scope] dari [uid] Firebase Auth yang sudah
  /// login — dipakai bareng oleh [login] dan [restoreSession] supaya
  /// logikanya (akun aktif? data santri ada?) tidak dobel-tulis.
  /// Return false kalau akun/data santri tidak valid (pemanggil yang
  /// putuskan sikapnya: [login] set errorMessage, [restoreSession] diam
  /// saja balik ke loggedOut).
  Future<bool> _loadAccountAndStudent(String uid) async {
    try {
      final account = await accountRepository.getByUid(uid);
      if (account == null) return false;

      final student = await studentRepository.getById(account.studentId);
      if (student == null) {
        errorMessage = 'Data santri untuk akun ini tidak ditemukan.';
        return false;
      }

      currentStudent = student;
      scope = ParentAccessScope(studentId: student.id, santriAccountId: uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ganti password akun santri yang SEDANG login. Butuh [currentPassword]
  /// buat re-autentikasi dulu (syarat Firebase Auth untuk operasi
  /// sensitif seperti ganti password — kalau sesi login sudah agak lama,
  /// tanpa ini akan gagal dengan `requires-recent-login`).
  ///
  /// Ini beneran mengganti password di Firebase Auth (server), BUKAN
  /// disimpan di penyimpanan lokal browser — jadi TIDAK akan balik ke
  /// password lama walau cache/local storage browser dihapus.
  ///
  /// Return null kalau sukses, atau pesan error yang aman ditampilkan ke
  /// orang tua kalau gagal.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'Sesi login tidak valid, silakan login ulang.';
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Password lama salah.';
        case 'weak-password':
          return 'Password baru terlalu lemah (minimal 6 karakter).';
        case 'requires-recent-login':
          return 'Sesi login sudah terlalu lama. Logout lalu login ulang sebelum ganti password.';
        default:
          return 'Gagal mengganti password (${e.code}).';
      }
    } catch (_) {
      return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  void logout() {
    _auth.signOut();
    status = AuthStatus.loggedOut;
    scope = null;
    currentStudent = null;
    notifyListeners();
  }
}
