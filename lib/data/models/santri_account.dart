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

  /// Foto profil ORANG TUA (bukan foto santri) — disimpan sebagai string
  /// base64 LANGSUNG di dokumen Firestore ini (bukan file lokal/cache
  /// HP), sengaja supaya level ketahanannya SAMA PERSIS dengan
  /// [passwordHash]/Firebase Auth: sumber kebenarannya di server, jadi
  /// tidak hilang walau aplikasi cache-nya dibersihkan app cleaner
  /// ATAU aplikasinya di-uninstall lalu install ulang — tinggal login
  /// lagi, foto otomatis kebaca ulang dari sini. Null = belum pernah
  /// upload foto (fallback ke inisial nama di UI).
  ///
  /// Sengaja base64-di-Firestore, BUKAN Firebase Storage — supaya tidak
  /// nambah dependency/setup bucket baru; ukuran dijaga kecil dari sisi
  /// picker (lihat `AuthProvider.updateProfilePhoto`, dikompres ke
  /// maks ~480x480 sebelum di-encode) supaya tetap jauh di bawah limit
  /// 1 dokumen Firestore (1 MiB).
  final String? photoBase64;
  final DateTime? photoUpdatedAt;

  const SantriAccount({
    required this.id,
    required this.studentId,
    required this.username,
    required this.passwordHash,
    this.isActive = true,
    required this.createdAt,
    this.photoBase64,
    this.photoUpdatedAt,
  });

  SantriAccount copyWith({
    String? username,
    String? passwordHash,
    bool? isActive,
    String? photoBase64,
    DateTime? photoUpdatedAt,
  }) {
    return SantriAccount(
      id: id,
      studentId: studentId,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      photoBase64: photoBase64 ?? this.photoBase64,
      photoUpdatedAt: photoUpdatedAt ?? this.photoUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'username': username,
        'passwordHash': passwordHash,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        if (photoBase64 != null) 'photoBase64': photoBase64,
        if (photoUpdatedAt != null) 'photoUpdatedAt': photoUpdatedAt!.toIso8601String(),
      };

  factory SantriAccount.fromJson(Map<String, dynamic> json) => SantriAccount(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        username: json['username'] as String,
        passwordHash: json['passwordHash'] as String,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        photoBase64: json['photoBase64'] as String?,
        photoUpdatedAt: json['photoUpdatedAt'] != null
            ? DateTime.tryParse(json['photoUpdatedAt'] as String)
            : null,
      );
}
