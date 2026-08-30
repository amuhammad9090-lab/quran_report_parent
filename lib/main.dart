import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/santri_account_repository.dart';
import 'data/repositories/student_repository.dart';
import 'data/services/progress_calculation_service.dart';
import 'data/services/quran_engine_service.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sama seperti app guru — dibutuhkan supaya DateFormat(..., 'id_ID')
  // di seluruh UI (dashboard, riwayat) tidak crash di runtime.
  await initializeDateFormatting('id_ID', null);

  // Engine baris Qur'an — sama seperti app guru, di-load sekali di awal.
  // CATATAN: butuh assets/data/quran_line_dataset_*.json (belum ada di
  // scaffold ini — lihat README_STEP3.md). Sebelum file itu tersedia,
  // load() gagal secara diam-diam (try/catch di dalam engine) dan
  // fitur yang bergantung cakupan baris tidak akan akurat.
  await QuranEngineService.instance.load();

  final studentRepository = MockStudentRepository();
  final santriAccountRepository = MockSantriAccountRepository();
  final reportRepository = MockReportRepository();
  final progressService = ProgressCalculationService(engine: QuranEngineService.instance);

  runApp(
    MultiProvider(
      providers: [
        Provider<StudentRepository>.value(value: studentRepository),
        Provider<SantriAccountRepository>.value(value: santriAccountRepository),
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
