/// Firebase Auth butuh format email, tapi santri login pakai username
/// biasa (sesuai brief: "Username / NIS / ID Santri") — jadi username
/// dikonversi ke email SINTETIS dengan domain tetap ini. Domain ini
/// TIDAK PERNAH dikirim email beneran (tidak perlu domain nyata/DNS
/// valid), cuma dipakai sebagai namespace unik di Firebase Auth. Dipakai
/// konsisten di [AuthProvider] (login) dan [ManageAccountsScreen]
/// (pembuatan akun) — HARUS selalu sama supaya username yang sama
/// menghasilkan email yang sama persis di kedua tempat.
const kParentAuthEmailDomain = 'quranreport-parent.app';

String usernameToSyntheticEmail(String username) =>
    '${username.trim().toLowerCase()}@$kParentAuthEmailDomain';

/// Email admin — HARUS SAMA PERSIS dengan yang ditulis di daftar
/// `isAdmin()` pada `firestore_integration/firestore.rules`. Bukan
/// email beneran (tidak perlu bisa terima email), cuma identifier akun
/// Firebase Auth admin. Buat akunnya manual sekali lewat Firebase
/// Console -> Authentication -> Add user, pakai email & password ini.
const kAdminEmail = 'admin@quranreport-parent-admin.local';
