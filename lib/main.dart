import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/utils/app_config.dart';
import 'data/repositories/firestore/firestore_parent_note_repository.dart';
import 'data/repositories/firestore/firestore_report_repository.dart';
import 'data/repositories/firestore/firestore_santri_account_repository.dart';
import 'data/repositories/firestore/firestore_student_repository.dart';
import 'data/repositories/firestore/firestore_weekly_recap_repository.dart';
import 'data/repositories/parent_note_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/student_repository.dart';
import 'data/repositories/weekly_recap_repository.dart';
import 'data/services/progress_calculation_service.dart';
import 'data/services/quran_engine_service.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);
  await QuranEngineService.instance.load();

  // Paksa font Plus Jakarta Sans SELESAI di-fetch dulu sebelum frame
  // pertama digambar. Tanpa ini, di web font-nya di-load async di
  // background — kalau proses fetch itu selesai PAS lagi ada widget yang
  // animasi text style (mis. hover/press di FilledButton), ukuran teks
  // pas layout vs pas paint jadi beda dan Flutter melempar assertion
  // "debugSize == size" (cuma di mode debug, tapi tetap mengganggu waktu
  // testing). `GoogleFonts.plusJakartaSans()` di sini cuma mendaftarkan
  // request fetch-nya (dipanggil lagi nanti di app_theme.dart, request
  // yang sama tidak di-fetch dua kali), lalu `pendingFonts()` nunggu
  // sampai semua request font yang terdaftar itu kelar.
  GoogleFonts.plusJakartaSans();
  await GoogleFonts.pendingFonts();

  final studentRepository = FirestoreStudentRepository(schoolId: kSchoolId);
  final santriAccountRepository = FirestoreSantriAccountRepository(schoolId: kSchoolId);
  final reportRepository = FirestoreReportRepository(schoolId: kSchoolId);
  final parentNoteRepository = FirestoreParentNoteRepository(schoolId: kSchoolId);
  final weeklyRecapRepository = FirestoreWeeklyRecapRepository(schoolId: kSchoolId);
  final progressService = ProgressCalculationService(engine: QuranEngineService.instance);

  runApp(
    MultiProvider(
      providers: [
        Provider<StudentRepository>.value(value: studentRepository),
        Provider<ReportRepository>.value(value: reportRepository),
        Provider<ParentNoteRepository>.value(value: parentNoteRepository),
        Provider<WeeklyRecapRepository>.value(value: weeklyRecapRepository),
        Provider<ProgressCalculationService>.value(value: progressService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            accountRepository: santriAccountRepository,
            studentRepository: studentRepository,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ParentWebApp(),
    ),
  );
}
