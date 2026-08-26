import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/organizer/organizer-splash.dart';
import 'screens/organizer/app_colors.dart';
import 'screens/user/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  unawaited(
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairTix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F9FC),
      ),
      // Web build = organizer/admin portal (OrganizerSplashScreen has
      // buttons for both "Organizer Log In" and "Admin Portal", so both
      // roles are reachable for testing from this one entry point).
      // Mobile build = the attendee-facing app.
      home: kIsWeb ? const OrganizerSplashScreen() : const SplashScreen(),
    );
  }
}
