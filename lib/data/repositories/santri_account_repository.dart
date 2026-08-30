import '../models/santri_account.dart';
import '../services/auth_hash_service.dart';

/// Abstraksi sumber data [SantriAccount] — dipakai oleh AuthProvider
/// (login) DAN oleh halaman admin ("Kelola Akun Orang Tua", terkunci
/// PIN admin) untuk membuat/menonaktifkan akun. Lihat catatan di
/// [SantriAccount]: entitas ini sengaja berdiri sendiri, tidak
/// menyentuh model/data app guru sama sekali.
abstract class SantriAccountRepository {
  Future<SantriAccount?> getByUsername(String username);
  Future<List<SantriAccount>> getAll();
  Future<void> create(SantriAccount account);
  Future<void> setActive(String accountId, bool isActive);
}

/// TODO(STEP 10 - integrasi backend): ganti dengan implementasi backend.
/// Sampai saat itu, data disimpan in-memory saja (hilang saat refresh) —
/// cukup untuk pengembangan STEP 4-9.
class MockSantriAccountRepository implements SantriAccountRepository {
  MockSantriAccountRepository() {
    // Akun demo untuk keperluan development STEP 4-9 saja — SATU-SATUNYA
    // tempat password plaintext boleh terlihat, dan hanya karena ini
    // data seed development (hilang saat refresh), bukan data production.
    // Username & password ini WAJIB diganti oleh mekanisme di
    // ManageAccountsScreen begitu STEP 10 (backend) jalan.
    _accounts.addAll([
      SantriAccount(
        id: 'acc_001',
        studentId: 'stu_001',
        username: 'ahmad.fauzan',
        passwordHash: AuthHashService.instance.hash('demo123'),
        createdAt: DateTime(2026, 1, 1),
      ),
      SantriAccount(
        id: 'acc_002',
        studentId: 'stu_002',
        username: 'siti.aisyah',
        passwordHash: AuthHashService.instance.hash('demo123'),
        createdAt: DateTime(2026, 1, 1),
      ),
    ]);
  }

  final List<SantriAccount> _accounts = [];

  @override
  Future<SantriAccount?> getByUsername(String username) async {
    try {
      return _accounts.firstWhere(
        (a) => a.username.toLowerCase() == username.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SantriAccount>> getAll() async => List.unmodifiable(_accounts);

  @override
  Future<void> create(SantriAccount account) async {
    _accounts.add(account);
  }

  @override
  Future<void> setActive(String accountId, bool isActive) async {
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return;
    _accounts[idx] = _accounts[idx].copyWith(isActive: isActive);
  }
}
