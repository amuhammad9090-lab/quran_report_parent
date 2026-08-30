// USULAN PATCH untuk app guru — lib/data/services/storage_service.dart
// BELUM DITERAPKAN ke repo Anda. Ini draf yang menunjukkan PERSIS di
// mana & seberapa kecil perubahannya, supaya Anda bisa review dulu
// sebelum saya (atau Anda) benar-benar apply ke repo guru.
//
// Prinsip: Hive TETAP jadi sumber utama (app guru tetap jalan offline
// 100% sama seperti sekarang, tidak ada behaviour yang berubah kalau
// device offline/Firestore gagal). Firestore MURNI tambahan mirror,
// dibungkus try/catch supaya kalau gagal (mis. offline), fungsi upsert/
// delete yang guru pakai TIDAK PERNAH gagal gara-gara Firestore.
//
// Baris yang DIUBAH ditandai `// <-- BARU`.

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // <-- BARU
import '../models/santri_record.dart';
import '../models/folder.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _boxName = 'santri_records';
  static const _folderBoxName = 'report_folders';
  late Box<String> _box;
  late Box<String> _folderBox;

  // <-- BARU: schoolId & flag Firestore opsional. Kalau null (Firestore
  // belum di-init atau memang belum dipakai), semua behaviour PERSIS
  // sama seperti sekarang — jadi aman di-merge kapan saja, bahkan
  // sebelum project Firebase Anda siap.
  String? _schoolId; // <-- BARU

  Future<void> init({String? schoolId}) async {
    // <-- BARU: parameter opsional, default null = behaviour lama
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _folderBox = await Hive.openBox<String>(_folderBoxName);
    _schoolId = schoolId; // <-- BARU
  }

  // --- Laporan ---
  List<SantriRecord> getAll() {
    return _box.values
        .map((raw) => SantriRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  Future<void> upsert(SantriRecord record) async {
    await _box.put(record.id, jsonEncode(record.toJson())); // <-- TIDAK BERUBAH, tetap paling depan
    _mirrorToFirestore(record); // <-- BARU — fire-and-forget, lihat catatan di bawah
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    _mirrorDeleteToFirestore(id); // <-- BARU
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _folderBox.clear();
  }

  // --- Folder --- (TIDAK diubah — folder murni struktur organisasi guru,
  // tidak relevan buat portal orang tua, jadi tidak di-mirror)
  List<ReportFolder> getAllFolders() {
    return _folderBox.values
        .map((raw) => ReportFolder.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> upsertFolder(ReportFolder folder) async {
    await _folderBox.put(folder.id, jsonEncode(folder.toJson()));
  }

  Future<void> deleteFolder(String folderId) async {
    await _folderBox.delete(folderId);
    for (final r in getAll().where((r) => r.folderId == folderId)) {
      await upsert(r.copyWith(clearFolder: true));
    }
  }

  // <-- BARU: 2 method di bawah ini semuanya baru.
  //
  // SENGAJA "fire-and-forget" (tidak di-await oleh upsert/delete di
  // atas, tidak melempar exception ke pemanggil) — supaya guru simpan
  // laporan TETAP INSTAN & TETAP JALAN walau device offline/Firestore
  // lagi down. Kalau Firestore gagal, laporan tetap tersimpan aman di
  // Hive seperti biasa; sync ke Firestore tinggal nyusul kapan saja
  // (idealnya nanti ditambah antrian retry, tapi itu di luar scope
  // patch minimal ini).
  void _mirrorToFirestore(SantriRecord record) {
    final schoolId = _schoolId;
    if (schoolId == null) return; // Firestore belum diaktifkan
    // FirebaseFirestore.instance
    //     .collection('schools').doc(schoolId)
    //     .collection('santriRecords').doc(record.id)
    //     .set(record.toJson())
    //     .catchError((_) {}); // diam-diam gagal, Hive tetap sumber kebenaran
  }

  void _mirrorDeleteToFirestore(String id) {
    final schoolId = _schoolId;
    if (schoolId == null) return;
    // FirebaseFirestore.instance
    //     .collection('schools').doc(schoolId)
    //     .collection('santriRecords').doc(id)
    //     .delete()
    //     .catchError((_) {});
  }
}
