# ---------------------------------------------------------------------
# ProGuard/R8 rules — Portal Orang Tua (quran_report_parent)
#
# Sengaja dibuat konservatif (banyak `-keep`/`-dontwarn`) daripada agresif:
# tujuan minify di sini cuma buat ngecilin ukuran APK + obfuscate nama
# kelas, BUKAN buat maksimalin shrinking habis-habisan. Logic aplikasi
# 99% ada di Dart (Flutter engine), jadi R8 cuma "menyentuh" sedikit host
# Android + SDK Firebase — rules di bawah nge-cover yang biasanya bikin
# app crash di release kalau di-skip (reflection-based (de)serialization
# di Firestore, referensi opsional Play Core dari Flutter engine, dst).
# ---------------------------------------------------------------------

# --- Flutter engine & generated plugin registrant ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Firebase (Auth, Firestore, Core) & Google Play Services ---
# SDK-nya sendiri sudah bawa consumer proguard rules lewat AAR, tapi
# di-keep juga di sini biar aman kalau ada versi yang belum lengkap.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Cloud Firestore mapping objek Dart<->native lewat reflection untuk
# custom class/annotation — kalau di-obfuscate tanpa rule ini, field
# bisa ke-strip dan data jadi null/salah map di release.
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}

# --- Transitive deps dari gRPC/OkHttp yang dipakai Firestore ---
# Referensi ke kelas platform Java opsional yang tidak ada di Android;
# aman untuk di-diamkan (bukan crash, cuma warning build R8).
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# --- Google Play Core (deferred components) ---
# Flutter engine punya referensi opsional ke Play Core untuk fitur
# split-install/deferred-component. Project ini TIDAK pakai fitur itu,
# jadi cukup di-silence daripada nambah dependency play-core yang tidak
# perlu.
-dontwarn com.google.android.play.core.**
