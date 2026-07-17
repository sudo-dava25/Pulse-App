import 'package:flutter/material.dart';

import '../models/overlay_theme.dart';
import '../services/game_repository.dart';
import '../services/metrics_service.dart';
import '../services/overlay_controller.dart';
import '../services/theme_repository.dart';
import '../widgets/floating_nav_bar.dart';
import 'dashboard_screen.dart';
import 'games_screen.dart';
import 'theme_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _gameRepository = GameRepository();
  final _themeRepository = ThemeRepository();
  final _metricsService = MetricsService();
  late final OverlayController _overlayController;

  int _index = 0;
  OverlayThemeData _selectedTheme = kOverlayThemes.first;

  @override
  void initState() {
    super.initState();
    _overlayController = OverlayController(
      metricsService: _metricsService,
      gameRepository: _gameRepository,
    );
    _loadTheme();
    // Mulai polling sistem-wide (tanpa target package) supaya Dashboard
    // tetap punya data CPU/suhu/baterai walau belum ada sesi game.
    _metricsService.start();
  }

  Future<void> _loadTheme() async {
    final theme = await _themeRepository.getSelectedTheme();
    _overlayController.setTheme(theme);
    if (mounted) setState(() => _selectedTheme = theme);
  }

  Future<void> _onThemeSelected(OverlayThemeData theme) async {
    setState(() => _selectedTheme = theme);
    _overlayController.setTheme(theme);
    await _themeRepository.setSelectedTheme(theme.id);
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(metricsService: _metricsService, overlayController: _overlayController),
      GamesScreen(gameRepository: _gameRepository, overlayController: _overlayController),
      ThemeScreen(
        selectedTheme: _selectedTheme,
        onSelected: _onThemeSelected,
        metricsService: _metricsService,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: _index, children: screens),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: FloatingNavBar(
                  items: const [
                    NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
                    NavItem(icon: Icons.videogame_asset_rounded, label: 'Game'),
                    NavItem(icon: Icons.layers_rounded, label: 'Tema'),
                  ],
                  selectedIndex: _index,
                  onSelected: (i) => setState(() => _index = i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
