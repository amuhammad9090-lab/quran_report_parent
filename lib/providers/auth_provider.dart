import 'package:flutter/foundation.dart';

import '../core/access/parent_access_scope.dart';
import '../data/models/student.dart';
import '../data/repositories/santri_account_repository.dart';
import '../data/repositories/student_repository.dart';
import '../data/services/auth_hash_service.dart';

enum AuthStatus { unknown, loggedOut, loading, loggedIn, error }

/// Login SANTRI (bukan akun orang tua terpisah — lihat brief), read-only.
/// Tidak ada method apa pun di sini yang menulis ke [SantriRecord]/
/// [Student] — provider ini hanya menghasilkan [ParentAccessScope] untuk
/// dikonsumsi provider/repository lain.
class AuthProvider extends ChangeNotifier {
  final SantriAccountRepository accountRepository;
  final StudentRepository studentRepository;

  AuthProvider({
    required this.accountRepository,
    required this.studentRepository,
  });

  AuthStatus status = AuthStatus.unknown;
  String? errorMessage;
  ParentAccessScope? scope;
  Student? currentStudent;

  Future<void> login(String username, String password) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    final account = await accountRepository.getByUsername(username);
    if (account == null || !account.isActive) {
      status = AuthStatus.error;
      errorMessage = 'Username atau password salah.';
      notifyListeners();
      return;
    }

    final valid = AuthHashService.instance.verify(password, account.passwordHash);
    if (!valid) {
      status = AuthStatus.error;
      errorMessage = 'Username atau password salah.';
      notifyListeners();
      return;
    }

    final student = await studentRepository.getById(account.studentId);
    if (student == null) {
      status = AuthStatus.error;
      errorMessage = 'Data santri untuk akun ini tidak ditemukan.';
      notifyListeners();
      return;
    }

    currentStudent = student;
    scope = ParentAccessScope(studentId: student.id, santriAccountId: account.id);
    status = AuthStatus.loggedIn;
    notifyListeners();
  }

  void logout() {
    status = AuthStatus.loggedOut;
    scope = null;
    currentStudent = null;
    notifyListeners();
  }
}
