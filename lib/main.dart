import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/utils/app_config.dart';
import 'data/repositories/firestore/firestore_report_repository.dart';
import 'data/repositories/firestore/firestore_santri_account_repository.dart';
import 'data/repositories/firestore/firestore_student_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/student_repository.dart';
import 'data/services/progress_calculation_service.dart';
import 'data/services/quran_engine_service.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sama seperti app guru — dibutuhkan supaya DateFormat(..., 'id_ID')
  // di seluruh UI (dashboard, riwayat) tidak crash di runtime.
  await initializeDateFormatting('id_ID', null);

  // Engine baris Qur'an — sama seperti app guru, di-load sekali di awal
  // (murni dari assets lokal, tidak terkait Firestore sama sekali).
  await QuranEngineService.instance.load();

  // STEP 10 (final): backend production = Firestore, project
  // "quran-reportweb". Mock*Repository (lib/data/repositories/*.dart,
  // BUKAN yang di folder firestore/) masih ada di project ini untuk
  // referensi/testing offline, tapi TIDAK dipakai di sini lagi.
  final studentRepository = FirestoreStudentRepository(schoolId: kSchoolId);
  final santriAccountRepository = FirestoreSantriAccountRepository(schoolId: kSchoolId);
  final reportRepository = FirestoreReportRepository(schoolId: kSchoolId);
  final progressService = ProgressCalculationService(engine: QuranEngineService.instance);

  runApp(
    MultiProvider(
      providers: [
        Provider<StudentRepository>.value(value: studentRepository),
        Provider<ReportRepository>.value(value: reportRepository),
        Provider<ProgressCalculationService>.value(value: progressService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            accountRepository: santriAccountRepository,
            studentRepository: studentRepository,
          ),
        ),
      ],
      child: const ParentWebApp(),
    ),
  );
}
