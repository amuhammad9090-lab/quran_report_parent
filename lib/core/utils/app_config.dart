/// Single-tenant untuk sekarang — 1 sekolah (SMPIT Al Madinah,
/// Tanjungpinang). Semua koleksi Firestore dinamespace di bawah
/// `schools/{kSchoolId}/...` (lihat `firestore.rules` & repository
/// Firestore).
///
/// PENTING: nilai ini HARUS SAMA PERSIS dengan `schoolId` yang dipakai
/// di data seed app guru (`kSeedStudentsJson` /
/// `local_seed_data.dart`) — bukan slug sembarang yang saya karang.
/// Kalau nanti app guru ganti schoolId-nya, ganti juga di sini DAN di
/// `functions/index.js` (`SCHOOL_ID`) — 2 tempat itu harus selalu
/// sinkron manual untuk sekarang. Kalau portal ini dipakai lebih dari 1
/// sekolah nanti, ini yang perlu diganti jadi dinamis, bukan konstanta.
const String kSchoolId = 'smpit_al_madinah_tanjungpinang';
