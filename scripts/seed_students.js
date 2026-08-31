// Script SEKALI JALAN (bukan Cloud Function, tidak di-deploy) — import
// 302 data Student dari `students_seed.json` (di-extract dari
// `local_seed_data.dart` app guru, kSeedStudentsJson, per 30 Agustus
// 2026) ke Firestore `schools/{schoolId}/students/{id}`.
//
// Kenapa perlu script terpisah (bukan otomatis ter-mirror kayak
// SantriRecord): Student di app guru masih SEED LOKAL, tidak ada
// write-path yang bisa di-mirror (lihat README.md bagian "Data awal").
// Ini one-time bootstrap; kalau nanti app guru dapat fitur
// tambah/edit-santri beneran, ganti pendekatannya jadi mirror-write
// (pola sama seperti GURU_APP_PATCH_storage_service.dart), BUKAN
// jalankan script ini berulang-ulang.
//
// CARA PAKAI:
//   1. Firebase Console -> Project Settings -> Service Accounts ->
//      "Generate new private key" -> simpan sebagai
//      scripts/service-account.json (JANGAN commit ke git — sudah ada
//      di .gitignore kalau Anda pakai git, cek dulu)
//   2. cd scripts && npm install
//   3. node seed_students.js
//
// Aman dijalankan berkali-kali (pakai .set(), bukan .create() — kalau
// ID sudah ada, datanya di-overwrite dengan isi terbaru dari JSON, bukan
// error/duplikat).

const admin = require('firebase-admin');
const students = require('./students_seed.json');

const serviceAccount = require('./service-account.json'); // lihat langkah 1 di atas

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const SCHOOL_ID = 'smpit_al_madinah_tanjungpinang'; // harus SAMA dengan kSchoolId di app_config.dart

async function main() {
  console.log(`Mengimpor ${students.length} santri ke schools/${SCHOOL_ID}/students/...`);

  // Firestore batch max 500 write per batch — 302 santri masih aman 1
  // batch, tapi dipecah per 400 untuk jaga-jaga kalau data nambah nanti.
  const chunks = [];
  for (let i = 0; i < students.length; i += 400) {
    chunks.push(students.slice(i, i + 400));
  }

  for (const chunk of chunks) {
    const batch = db.batch();
    for (const s of chunk) {
      const ref = db.collection('schools').doc(SCHOOL_ID).collection('students').doc(s.id);
      batch.set(ref, s);
    }
    await batch.commit();
    console.log(`  ...${chunk.length} dokumen tersimpan`);
  }

  console.log('Selesai.');
}

main().catch((err) => {
  console.error('Gagal import:', err);
  process.exit(1);
});
