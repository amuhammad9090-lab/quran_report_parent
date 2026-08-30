/// Akun login untuk PORTAL ORANG TUA — BUKAN [UserAccount] (itu punya
/// app guru, untuk Admin/Guru Pembimbing). Entitas ini sengaja dipisah,
/// bukan menambah field username/password ke [Student], supaya:
///  - `Student` (data master, dipakai autocomplete di app guru) tetap
///    murni data profil, tidak tercampur kredensial;
///  - app guru TIDAK PERLU disentuh sama sekali untuk fitur ini — akun
///    dikelola dari sisi web parent sendiri (lihat halaman admin
///    terkunci PIN di presentation/screens/admin/).
///
/// `passwordHash` dibuat dengan [AuthHashService] yang SAMA persis
/// dengan yang dipakai app guru (file di-share apa adanya) — supaya
/// kalau nanti backend production disatukan, mekanisme hashing sudah
/// konsisten dari awal.
class SantriAccount {
  final String id;
  final String studentId; // FK -> Student.id
  final String username;
  final String passwordHash;

  /// Guru/admin bisa nonaktifkan akses tanpa menghapus akunnya (mis.
  /// santri pindah/lulus). Login ditolak kalau false, walau
  /// username/password benar.
  final bool isActive;

  final DateTime createdAt;

  const SantriAccount({
    required this.id,
    required this.studentId,
    required this.username,
    required this.passwordHash,
    this.isActive = true,
    required this.createdAt,
  });

  SantriAccount copyWith({
    String? username,
    String? passwordHash,
    bool? isActive,
  }) {
    return SantriAccount(
      id: id,
      studentId: studentId,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'username': username,
        'passwordHash': passwordHash,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SantriAccount.fromJson(Map<String, dynamic> json) => SantriAccount(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        username: json['username'] as String,
        passwordHash: json['passwordHash'] as String,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
