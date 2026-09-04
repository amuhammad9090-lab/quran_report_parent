// fix_halaqoh.js
//
// One-time script: normalisasi field `halaqoh` di collection `students`
// dari format panjang ("Halaqoh B") ke format pendek ("B"), biar match
// sama konvensi yang dipakai app guru di `santriRecords` (namaAnak,
// kelas, halaqoh dicek EXACT MATCH di firestore.rules).
//
// CARA PAKAI:
// 1. npm install firebase-admin
// 2. Firebase Console -> project quran-reportweb -> Project settings
//    -> Service accounts -> "Generate new private key" -> simpan sebagai
//    serviceAccountKey.json di folder yang sama dengan script ini.
//    JANGAN commit file ini ke git, hapus setelah selesai dipakai.
// 3. node fix_halaqoh.js            (DRY RUN dulu, cuma nampilin apa yang
//                                    akan diubah, TIDAK menulis apa-apa)
// 4. node fix_halaqoh.js --apply    (baru ini yang beneran nulis ke Firestore)

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const SCHOOL_ID = 'smpit_al_madinah_tanjungpinang'; // sama seperti kSchoolId di app
const APPLY = process.argv.includes('--apply');

async function main() {
  const studentsRef = db
    .collection('schools')
    .doc(SCHOOL_ID)
    .collection('students');

  const snapshot = await studentsRef.get();
  console.log(`Total dokumen students: ${snapshot.size}`);

  let toFix = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const halaqoh = data.halaqoh;

    if (typeof halaqoh === 'string' && halaqoh.trim().toLowerCase().startsWith('halaqoh ')) {
      const newHalaqoh = halaqoh.trim().slice('halaqoh '.length).trim();
      console.log(`${doc.id} (${data.nama}): "${halaqoh}" -> "${newHalaqoh}"`);
      toFix++;

      if (APPLY) {
        batch.update(doc.ref, { halaqoh: newHalaqoh });
        batchCount++;
        // Firestore batch max 500 operasi
        if (batchCount >= 400) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }
    }
  }

  if (APPLY && batchCount > 0) {
    await batch.commit();
  }

  console.log(`\nTotal yang perlu/sudah diubah: ${toFix}`);
  console.log(APPLY ? 'SELESAI, sudah ditulis ke Firestore.' : 'DRY RUN doang, belum ada yang ditulis. Jalankan ulang dengan --apply kalau hasil di atas sudah benar.');
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});