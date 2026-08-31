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

      final account = await accountRepository.getByUid(uid);
      if (account == null) {
        // Akun Firebase Auth ada tapi dokumen metadata tidak ada/isActive
        // false — jangan biarkan orang login tanpa data santri yang valid.
        await _auth.signOut();
        status = AuthStatus.error;
        errorMessage = 'Akun tidak ditemukan atau sudah dinonaktifkan.';
        notifyListeners();
        return;
      }

      final student = await studentRepository.getById(account.studentId);
      if (student == null) {
        await _auth.signOut();
        status = AuthStatus.error;
        errorMessage = 'Data santri untuk akun ini tidak ditemukan.';
        notifyListeners();
        return;
      }

      currentStudent = student;
      scope = ParentAccessScope(studentId: student.id, santriAccountId: uid);
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

  void logout() {
    _auth.signOut();
    status = AuthStatus.loggedOut;
    scope = null;
    currentStudent = null;
    notifyListeners();
  }
}
