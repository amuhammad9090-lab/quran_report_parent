/// Access scope untuk akun ORANG TUA yang sedang login.
///
/// Berbeda dengan app guru (yang scoping-nya kelas+halaqoh, bisa banyak
/// santri), portal ini SELALU discope ke SATU [studentId] — akun santri
/// yang dipakai login. Tidak ada mode "lihat semua".
///
/// ATURAN KERAS (lihat aturan keras #9 & #10 dari brief):
///  - Setiap query data (repository) WAJIB menerima/menerapkan
///    [studentId] ini di level repository/service, BUKAN filter di UI.
///  - Tidak ada write access sama sekali di scope ini — hanya getter,
///    tidak ada method mutate.
class ParentAccessScope {
  final String studentId;
  final String santriAccountId;

  const ParentAccessScope({
    required this.studentId,
    required this.santriAccountId,
  });
}
