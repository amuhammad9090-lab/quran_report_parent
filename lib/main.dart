import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/utils/app_config.dart';
import 'data/repositories/firestore/firestore_parent_note_repository.dart';
import 'data/repositories/firestore/firestore_report_repository.dart';
import 'data/repositories/firestore/firestore_santri_account_repository.dart';
import 'data/repositories/firestore/firestore_student_repository.dart';
import 'data/repositories/parent_note_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/student_repository.dart';
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

  final studentRepository = FirestoreStudentRepository(schoolId: kSchoolId);
  final santriAccountRepository = FirestoreSantriAccountRepository(schoolId: kSchoolId);
  final reportRepository = FirestoreReportRepository(schoolId: kSchoolId);
  final parentNoteRepository = FirestoreParentNoteRepository(schoolId: kSchoolId);
  final progressService = ProgressCalculationService(engine: QuranEngineService.instance);

  runApp(
    MultiProvider(
      providers: [
        Provider<StudentRepository>.value(value: studentRepository),
        Provider<ReportRepository>.value(value: reportRepository),
        Provider<ParentNoteRepository>.value(value: parentNoteRepository),
        Provider<ProgressCalculationService>.value(value: progressService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            accountRepository: santriAccountRepository,
            studentRepository: studentRepository,
          ),
        ),
        // Preferensi tampilan (Terang/Gelap/Sistem) — di-load di atas
        // _AuthGate supaya berlaku juga di LoginScreen (sebelum login),
        // bukan cuma setelah masuk MainShell.
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ParentWebApp(),
    ),
  );
}
