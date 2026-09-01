// Script SEKALI PANGGIL (bukan Cloud Function, tidak di-deploy) — benerin
// field `halaqoh` di collection `students` yang salah format.
//
// PENYEBAB BUG: field `halaqoh` di `students` tersimpan dengan prefix
// "Halaqoh " (contoh: "Halaqoh B"), sedangkan app guru nulis `halaqoh`
// di `santriRecords` cuma hurufnya doang (contoh: "B") — beda persis
// karena query Portal Orang Tua exact-match, `.where('halaqoh', ...)`
// gak pernah ketemu, laporan keliatan "Belum ada" padahal datanya ada.
//
// Script ini strip "Halaqoh " (case-insensitive, dengan/tanpa spasi
// setelahnya) dari SEMUA dokumen students, jadi tersisa cuma hurufnya
// ("Halaqoh B" -> "B"), match sama format app guru.
//
// CARA PAKAI:
//   cd scripts
//   node fix_halaqoh.js
//
// Aman dijalankan berkali-kali (idempotent) — dokumen yang halaqoh-nya
// udah bener (gak ada prefix "Halaqoh ") dilewatin aja, gak diubah.

const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const SCHOOL_ID = 'smpit_al_madinah_tanjungpinang'; // <-- samain kalau beda

async function main() {
  const db = admin.firestore();
  const col = db.collection('schools').doc(SCHOOL_ID).collection('students');
  const snap = await col.get();

  console.log(`Ketemu ${snap.size} dokumen students. Mengecek field halaqoh...`);

  let fixed = 0;
  let skipped = 0;
  const batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const current = (data.halaqoh || '').toString();
    // Strip "Halaqoh " di depan, case-insensitive, apa pun jumlah spasinya.
    const stripped = current.replace(/^halaqoh\s*/i, '').trim();

    if (stripped !== current) {
      batch.update(doc.ref, { halaqoh: stripped });
      console.log(`  FIX  ${doc.id} (${data.nama || '?'}): "${current}" -> "${stripped}"`);
      fixed++;
      batchCount++;
    } else {
      skipped++;
    }

    // Firestore batch max 500 operasi — commit & mulai batch baru kalau
    // mepet, biar aman buat sekolah dengan santri sangat banyak.
    if (batchCount >= 400) {
      await batch.commit();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`\nSelesai. Diperbaiki: ${fixed}. Dilewati (udah bener): ${skipped}.`);
}

main().catch((err) => {
  console.error('Gagal:', err);
  process.exit(1);
});
