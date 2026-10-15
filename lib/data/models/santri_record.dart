import '../../core/utils/text_utils.dart';
import 'enums.dart';
import 'tahfizh_segment.dart';
import 'tilawah_segment.dart';

export 'santri_record_display.dart';
export 'tahfizh_segment.dart';
export 'tilawah_segment.dart';

class SantriRecord {
  final String id;
  final DateTime tanggal;
  final DateTime? createdAt; // waktu laporan ini benar-benar diinput (buat jam di kartu)
  final String kelas; // contoh: "789"
  final String halaqoh; // contoh: "ABCD"
  final String namaAnak;
  final HafalanStatus status;
  final Keterangan keterangan;

  // --- Tahfizh fields ---
  // surahNumber/surahName/ayatMulai/ayatSelesai di bawah ini merepresentasikan
  // SEGMEN PERTAMA saja — dipertahankan buat backward compatibility (laporan
  // lama sebelum ada multi-surah, dan konsumen lama yang belum di-update).
  // Sumber kebenaran buat tampilan lengkap (bisa >1 surah) ada di
  // [tahfizhSegments] / getter [tahfizhSegmentsEffective] di bawah.
  final int? surahNumber;
  final String? surahName;
  final int? ayatMulai;
  final int? ayatSelesai;
  // totalBaris & lineIds SELALU agregat (jumlah/gabungan) dari SEMUA segmen
  // Tahfizh — bukan cuma segmen pertama — supaya statistik/rekap yang baca
  // 2 field ini apa adanya (tanpa tahu soal multi-surah) tetap benar.
  final int? totalBaris; // hasil generate dari engine (baris BARU, sudah dikurangi riwayat)
  final List<String>? lineIds; // id baris fisik yang dihitung di laporan ini
  // Daftar lengkap semua segmen Tahfizh (>= 1 elemen kalau status ada
  // bagian Tahfizh-nya). Null/kosong pada data lama -> lihat
  // [tahfizhSegmentsEffective] yang otomatis fallback ke field tunggal di atas.
  final List<TahfizhSegment>? tahfizhSegments;

  // --- Tahsin fields ---
  // Sub-mode Tahsin (WAFA atau Tilawah). Null = data lama sebelum ada
  // mode ini -> selalu dianggap WAFA (backward compatible).
  final TahsinMode? tahsinMode;
  final WafaLevel? wafaLevel;
  final String? halamanWafa; // halaman buku WAFA, string biar fleksibel (mis. "12-13")

  // --- Tilawah fields (dipakai saat Tahsin bermode Tilawah, saat status
  // Tahsin+Tahfizh bagian Tahsin-nya bermode Tilawah, ATAU saat status
  // Muroja'ah/Tasmi' — semuanya sama bentuknya: surah + rentang ayat,
  // TANPA hitung baris/generate. Field terpisah dari surahNumber/ayatMulai/
  // ayatSelesai di atas supaya Tahsin+Tahfizh bisa menyimpan KEDUANYA
  // sekaligus (bagian tilawah & bagian hafalan baru) tanpa bentrok.
  final int? tilawahSurahNumber;
  final String? tilawahSurahName;
  final int? tilawahAyatMulai;
  final int? tilawahAyatSelesai;
  // Daftar lengkap semua segmen Tilawah (WAFA tidak masuk sini). Sama
  // seperti [tahfizhSegments]: null/kosong pada data lama -> fallback ke
  // field tunggal tilawah* di atas lewat [tilawahSegmentsEffective].
  final List<TilawahSegment>? tilawahSegments;

  final String? catatan;

  // Nilai bebas ketik dari guru (mis. "85", "A", "Mumtaz") — opsional,
  // laporan lama/belum dinilai null. Sama seperti field guru app lainnya,
  // bukan angka standar (jangan di-parse sebagai int) — tampilkan apa
  // adanya.
  final String? nilai;

  // <-- BERUBAH (bug fix: nama field salah tebak, hasilnya SELALU null):
  // keputusan guru Tuntas/Tidak Tuntas untuk SATU PEKAN (bukan per
  // laporan harian) — true = Tuntas, false = Tidak Tuntas, null = guru
  // belum memutuskan pekan ini (laporan lama, atau belum sempat buka
  // "Generate Laporan Pekanan" & pencet tombolnya). Field ini CUMA
  // keisi di laporan TERAKHIR santri pada pekan itu (lihat app guru:
  // `SantriRecord.tuntasPekan` / `GenerateRekapPekananScreen._setTuntas`
  // / `StandarKetuntasan.manualPekanValue`) — laporan lain di pekan yang
  // sama sengaja null. Portal Ortu READ-ONLY, field ini tidak pernah
  // ditulis dari sini. Nama field HARUS persis `tuntasPekan` (bukan
  // `tuntas`) karena itu key yang ditulis app guru ke Firestore.
  final bool? tuntasPekan;

  // Folder tempat laporan ini disimpan (null = tidak di dalam folder mana pun,
  // tampil di section "Laporan" biasa).
  final String? folderId;

  // Id user (guru pembimbing) yang membuat laporan ini. OPSIONAL & backward
  // compatible — laporan lama (sebelum ada auth) tidak punya ini dan
  // TETAP bisa dibaca/ditampilkan normal (null). Field ini untuk
  // keperluan audit/riwayat ke depan; access control TIDAK mengandalkan
  // field ini (lihat AccessScope — scoping dari kelas+halaqoh).
  final String? ownerId;

  SantriRecord({
    required this.id,
    required this.tanggal,
    this.createdAt,
    required this.kelas,
    required this.halaqoh,
    required this.namaAnak,
    required this.status,
    required this.keterangan,
    this.surahNumber,
    this.surahName,
    this.ayatMulai,
    this.ayatSelesai,
    this.totalBaris,
    this.lineIds,
    this.tahfizhSegments,
    this.tahsinMode,
    this.wafaLevel,
    this.halamanWafa,
    this.tilawahSurahNumber,
    this.tilawahSurahName,
    this.tilawahAyatMulai,
    this.tilawahAyatSelesai,
    this.tilawahSegments,
    this.catatan,
    this.nilai,
    this.tuntasPekan,
    this.folderId,
    this.ownerId,
  });

  SantriRecord copyWith({
    DateTime? tanggal,
    String? kelas,
    String? halaqoh,
    String? namaAnak,
    HafalanStatus? status,
    Keterangan? keterangan,
    int? surahNumber,
    String? surahName,
    int? ayatMulai,
    int? ayatSelesai,
    int? totalBaris,
    List<String>? lineIds,
    List<TahfizhSegment>? tahfizhSegments,
    TahsinMode? tahsinMode,
    WafaLevel? wafaLevel,
    String? halamanWafa,
    int? tilawahSurahNumber,
    String? tilawahSurahName,
    int? tilawahAyatMulai,
    int? tilawahAyatSelesai,
    List<TilawahSegment>? tilawahSegments,
    String? catatan,
    String? nilai,
    bool? tuntasPekan,
    String? folderId,
    bool clearTahfizh = false,
    bool clearTahsin = false,
    bool clearTilawah = false,
    bool clearFolder = false,
    bool clearTuntasPekan = false,
  }) {
    return SantriRecord(
      id: id,
      tanggal: tanggal ?? this.tanggal,
      createdAt: createdAt,
      ownerId: ownerId,
      kelas: kelas ?? this.kelas,
      halaqoh: halaqoh ?? this.halaqoh,
      namaAnak: namaAnak ?? this.namaAnak,
      status: status ?? this.status,
      keterangan: keterangan ?? this.keterangan,
      surahNumber: clearTahfizh ? null : (surahNumber ?? this.surahNumber),
      surahName: clearTahfizh ? null : (surahName ?? this.surahName),
      ayatMulai: clearTahfizh ? null : (ayatMulai ?? this.ayatMulai),
      ayatSelesai: clearTahfizh ? null : (ayatSelesai ?? this.ayatSelesai),
      totalBaris: clearTahfizh ? null : (totalBaris ?? this.totalBaris),
      lineIds: clearTahfizh ? null : (lineIds ?? this.lineIds),
      tahfizhSegments: clearTahfizh ? null : (tahfizhSegments ?? this.tahfizhSegments),
      tahsinMode: clearTahsin ? null : (tahsinMode ?? this.tahsinMode),
      wafaLevel: clearTahsin ? null : (wafaLevel ?? this.wafaLevel),
      halamanWafa: clearTahsin ? null : (halamanWafa ?? this.halamanWafa),
      tilawahSurahNumber:
          clearTilawah ? null : (tilawahSurahNumber ?? this.tilawahSurahNumber),
      tilawahSurahName: clearTilawah ? null : (tilawahSurahName ?? this.tilawahSurahName),
      tilawahAyatMulai: clearTilawah ? null : (tilawahAyatMulai ?? this.tilawahAyatMulai),
      tilawahAyatSelesai:
          clearTilawah ? null : (tilawahAyatSelesai ?? this.tilawahAyatSelesai),
      tilawahSegments: clearTilawah ? null : (tilawahSegments ?? this.tilawahSegments),
      catatan: catatan ?? this.catatan,
      nilai: nilai ?? this.nilai,
      tuntasPekan: clearTuntasPekan ? null : (tuntasPekan ?? this.tuntasPekan),
      folderId: clearFolder ? null : (folderId ?? this.folderId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tanggal': tanggal.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'kelas': kelas,
        'halaqoh': halaqoh,
        'namaAnak': namaAnak,
        'status': status.name,
        'keterangan': keterangan.name,
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayatMulai': ayatMulai,
        'ayatSelesai': ayatSelesai,
        'totalBaris': totalBaris,
        'lineIds': lineIds,
        'tahfizhSegments': tahfizhSegments?.map((s) => s.toJson()).toList(),
        'tahsinMode': tahsinMode?.name,
        'wafaLevel': wafaLevel?.name,
        'halamanWafa': halamanWafa,
        'tilawahSurahNumber': tilawahSurahNumber,
        'tilawahSurahName': tilawahSurahName,
        'tilawahAyatMulai': tilawahAyatMulai,
        'tilawahAyatSelesai': tilawahAyatSelesai,
        'tilawahSegments': tilawahSegments?.map((s) => s.toJson()).toList(),
        'catatan': catatan,
        'nilai': nilai,
        'tuntasPekan': tuntasPekan,
        'folderId': folderId,
        'ownerId': ownerId,
      };

  factory SantriRecord.fromJson(Map<String, dynamic> json) => SantriRecord(
        id: json['id'] as String,
        tanggal: DateTime.parse(json['tanggal'] as String),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        kelas: json['kelas'] as String,
        halaqoh: normalizeHalaqoh(json['halaqoh'] as String),
        namaAnak: json['namaAnak'] as String,
        status: HafalanStatus.values.byName(json['status'] as String),
        keterangan: Keterangan.values.byName(json['keterangan'] as String),
        surahNumber: json['surahNumber'] as int?,
        surahName: json['surahName'] as String?,
        ayatMulai: json['ayatMulai'] as int?,
        ayatSelesai: json['ayatSelesai'] as int?,
        totalBaris: json['totalBaris'] as int?,
        lineIds: (json['lineIds'] as List?)?.map((e) => e as String).toList(),
        // Field baru (multi-surah) — data lama belum punya ini, default
        // null aman: tahfizhSegmentsEffective otomatis fallback ke field
        // tunggal surahNumber/dst di atas (backward compatible).
        tahfizhSegments: (json['tahfizhSegments'] as List?)
            ?.map((e) => TahfizhSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        // Field baru (tahsinMode & tilawah*) — data lama belum punya ini,
        // default null aman (backward compatible): tahsinMode null berarti
        // "WAFA" (lihat _tahsinPartText), tilawah* null berarti belum
        // pernah diisi bentuk Tilawah sama sekali.
        tahsinMode: json['tahsinMode'] != null
            ? TahsinMode.values.byName(json['tahsinMode'] as String)
            : null,
        wafaLevel: json['wafaLevel'] != null
            ? WafaLevel.values.byName(json['wafaLevel'] as String)
            : null,
        halamanWafa: json['halamanWafa'] as String?,
        tilawahSurahNumber: json['tilawahSurahNumber'] as int?,
        tilawahSurahName: json['tilawahSurahName'] as String?,
        tilawahAyatMulai: json['tilawahAyatMulai'] as int?,
        tilawahAyatSelesai: json['tilawahAyatSelesai'] as int?,
        tilawahSegments: (json['tilawahSegments'] as List?)
            ?.map((e) => TilawahSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        catatan: json['catatan'] as String?,
        nilai: json['nilai'] as String?,
        tuntasPekan: json['tuntasPekan'] as bool?,
        folderId: json['folderId'] as String?,
        // Field baru — data lama pasti belum punya ini, default null aman
        // (backward compatible, tidak ada migration destructive).
        ownerId: json['ownerId'] as String?,
      );
}

