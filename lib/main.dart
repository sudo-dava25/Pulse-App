import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_colors.dart';

// Import ini WAJIB ada di sini (walau tidak dipanggil langsung) supaya
// fungsi overlayMain() ikut ter-bundle dan tidak di-tree-shake saat
// `flutter build apk --release`. Lihat catatan di overlay_entry.dart.
// ignore: unused_import
import 'overlay_entry.dart';

void main() {
  runApp(const PulseApp());
}

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}
