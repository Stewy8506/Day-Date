/// Day-Date — Dynamic Scheduling Engine
///
/// Bootstrap: initializes Hive CE, registers adapters, seeds data
/// on first launch, and launches the app with Riverpod.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/data/datasources/local_schedule_datasource.dart';
import 'package:day_date/features/schedule/data/models/schedule_deviation_model.dart';
import 'package:day_date/features/schedule/data/models/task_target_model.dart';
import 'package:day_date/features/schedule/data/models/time_block_model.dart';
import 'package:day_date/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:day_date/features/schedule/presentation/screens/weekly_overview_screen.dart';
import 'package:day_date/hive_registrar.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive.
  await Hive.initFlutter();

  // Register all generated type adapters.
  Hive.registerAdapters();

  // Open required boxes.
  await Future.wait([
    Hive.openBox<TimeBlockModel>(kFixedBlocksBox),
    Hive.openBox<TaskTargetModel>(kTaskTargetsBox),
    Hive.openBox<ScheduleDeviationModel>(kDeviationsBox),
    Hive.openBox(kMetaBox),
  ]);

  // Seed data on first launch.
  final datasource = LocalScheduleDatasource();
  final repository = ScheduleRepositoryImpl(datasource);
  await repository.seedIfEmpty();

  runApp(const ProviderScope(child: DayDateApp()));
}

class DayDateApp extends StatelessWidget {
  const DayDateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Day-Date',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const WeeklyOverviewScreen(),
    );
  }
}
