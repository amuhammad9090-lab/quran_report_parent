import 'package:flutter/material.dart';

class FieldIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const FieldIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Dekorasi input seragam untuk semua kolom form (TextFormField &
/// DropdownButtonFormField): ikon dalam kotak warna sebagai prefix, isian
/// rounded-16 tanpa border, dengan aksen warna saat fokus/error.
InputDecoration fieldDecoration(
    BuildContext context, {
      required IconData icon,
      required String label,
      String? hint,
      String? errorText,
      Color? accent,
    }) {
  final cs = Theme.of(context).colorScheme;
  final color = accent ?? cs.primary;
  final fill = Theme.of(context).inputDecorationTheme.fillColor;
  return InputDecoration(
    // Nggak pakai labelText (itu yang bikin teks "terbang" ke atas pas
    // kolom di-tap) — pakai hintText aja, tetap kelihatan selama kosong,
    // baru ilang begitu user isi.
    hintText: hint != null ? '$label ($hint)' : label,
    errorText: errorText,
    filled: true,
    fillColor: fill,
    prefixIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: FieldIcon(icon: icon, color: color, size: 34),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 34),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.6),
    ),
  );
}

/// Versi [InputDecorationTheme] dari [fieldDecoration] — dipakai widget yang
/// minta tema, bukan instance dekorasi langsung (mis. [DropdownMenu]).
InputDecorationTheme fieldDecorationTheme(
    BuildContext context, {
      required Color accent,
    }) {
  final cs = Theme.of(context).colorScheme;
  final fill = Theme.of(context).inputDecorationTheme.fillColor;
  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    ),
  );
}

/// [value] dipakai sebagai `initialValue` — [DropdownButtonFormField]
/// modern nggak otomatis re-render pas [value] berubah dari luar (mis.
/// direset programatis karena kelas/halaqoh ganti). Makanya widget ini
/// SELALU dikasih `key: ValueKey(value)` oleh pemanggil (lihat
/// `record_form_sheet.dart`) biar widget-nya dibikin ulang & nilainya
/// ikut ke-refresh tiap kali value berubah dari luar.
class SelectField extends StatelessWidget {
  final String? value;
  final String label;
  final String? hint;
  final IconData icon;
  final List<String> options;
  final String? errorText;
  final Color? accent;
  final bool enabled;
  final ValueChanged<String?>? onChanged;

  const SelectField({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.options,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.accent,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accent ?? cs.primary;
    final safeValue = (value != null && options.contains(value)) ? value : null;
    final isUsable = enabled && options.isNotEmpty;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.expand_more_rounded,
          color: isUsable ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.4)),
      decoration: fieldDecoration(
        context,
        icon: icon,
        label: label,
        hint: hint,
        errorText: errorText,
        accent: color,
      ),
      disabledHint: hint != null
          ? Text(hint!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
              overflow: TextOverflow.ellipsis)
          : null,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: cs.onSurface),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: isUsable ? onChanged : null,
    );
  }
}

/// Kartu section form (Tanggal, Identitas Santri, Status Capaian,
/// Keterangan, dst) — judul kecil + ikon di atas, konten di bawah, dibungkus
/// card senada dengan card lain di aplikasi (bukan cuma label polos).
class FormSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const FormSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 7),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Kartu sambutan hijau tua di puncak Home — identitas utama halaman.
/// Opsional menampung baris aksi cepat (mis. Tambah Laporan/Ekspor Data)
/// dipisah garis tipis, meniru layout referensi desain.
