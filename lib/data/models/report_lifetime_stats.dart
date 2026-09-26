/// Statistik SEPANJANG RIWAYAT (lifetime) satu santri, dihitung
/// SERVER-SIDE lewat Firestore aggregate query (`count()`/`sum()`) — BUKAN
/// dengan fetch semua dokumen `laporan` lalu di-fold di client.
///
/// Alasan file ini ada: [DashboardProvider] dulu menghitung
/// `totalBarisTercapai` dan `kehadiranRatio` dengan cara fold seluruh
/// `records` yang di-listen live tanpa batas tanggal — biayanya (jumlah
/// Firestore read) MEMBESAR TERUS seiring bertambahnya laporan santri,
/// tanpa plafon. Aggregate query menghitung angka yang SAMA PERSIS
/// (lifetime, bukan windowed) tapi biayanya cuma beberapa read kecil
/// (1 read per hingga 1000 dokumen yang cocok), berapa pun panjang
/// riwayatnya — lihat [FirestoreReportRepository.getLifetimeStats].
class ReportLifetimeStats {
  /// Jumlah SELURUH laporan santri ini, sepanjang riwayat.
  final int totalCount;

  /// Jumlah laporan berstatus "hadir secara fisik" (Hadir, atau salah satu
  /// dari 3 keterangan "sanksi tanpa setoran" — lihat
  /// `Keterangan.isSanksiTanpaSetoran`), sepanjang riwayat.
  final int hadirCount;

  /// Jumlah baris tahfizh tercapai, dijumlahkan dari SELURUH laporan
  /// (field `totalBaris`), sepanjang riwayat.
  final int totalBarisTercapai;

  const ReportLifetimeStats({
    required this.totalCount,
    required this.hadirCount,
    required this.totalBarisTercapai,
  });

  static const empty = ReportLifetimeStats(totalCount: 0, hadirCount: 0, totalBarisTercapai: 0);

  /// % laporan yang santrinya HADIR secara fisik, dari SELURUH laporan —
  /// 0 kalau belum ada laporan sama sekali (hindari pembagian oleh nol).
  double get kehadiranRatio => totalCount == 0 ? 0 : hadirCount / totalCount;
}
