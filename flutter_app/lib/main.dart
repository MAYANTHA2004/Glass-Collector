import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/trip_session.dart';
import 'screens/trip_sequence_screen.dart';

void main() {
  runApp(const GlassCollectorApp());
}

class GlassCollectorApp extends StatelessWidget {
  const GlassCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TripSession(),
      child: MaterialApp(
        title: 'Glass Collector',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D5B), // glass-green
          ),
        ),
        home: const TripSequenceScreen(),
      ),
    );
  }
}
