// fix_username_auth.js
//
// Ganti email Firebase Auth santri (dipakai buat login), nyusul field
// `username` di Firestore santriAccounts yang udah diubah manual.
//
// CARA PAKAI (dari folder `scripts` yang sama, service-account.json
// udah ada di situ):
//   node fix_username_auth.js <UID> <username_baru>
//
// Contoh:
//   node fix_username_auth.js abc123xyz budi_santri
//
// UID diambil dari Firestore: buka dokumen santriAccounts yang mau
// diganti usernya, document ID itu = UID-nya.

const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const EMAIL_DOMAIN = 'quranreport-parent.app'; // samain sama yang dipakai app

async function main() {
  const [, , uid, newUsername] = process.argv;

  if (!uid || !newUsername) {
    console.error('Pemakaian: node fix_username_auth.js <UID> <username_baru>');
    process.exit(1);
  }

  const newEmail = `${newUsername}@${EMAIL_DOMAIN}`;

  const before = await admin.auth().getUser(uid);
  console.log(`User ditemukan. Email sekarang: ${before.email}`);
  console.log(`Akan diganti jadi: ${newEmail}`);

  const updated = await admin.auth().updateUser(uid, { email: newEmail });
  console.log(`\nBerhasil. Email baru: ${updated.email}`);
  console.log('Password TIDAK berubah, tetap sama seperti sebelumnya.');
}

main().catch((err) => {
  console.error('Gagal:', err.message);
  process.exit(1);
});
