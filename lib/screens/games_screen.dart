import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../models/game_item.dart';
import '../services/game_repository.dart';
import '../services/overlay_controller.dart';
import '../theme/app_colors.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({
    super.key,
    required this.gameRepository,
    required this.overlayController,
  });

  final GameRepository gameRepository;
  final OverlayController overlayController;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  List<GameItem> _games = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final games = await widget.gameRepository.getGames();
    if (!mounted) return;
    setState(() {
      _games = games;
      _loading = false;
    });
  }

  Future<void> _openAddSheet() async {
    // QUERY_ALL_PACKAGES perlu di-declare di AndroidManifest - lihat README.
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;
    final existing = _games.map((g) => g.packageName).toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(4))),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Tambah dari aplikasi terinstal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: apps.length,
                      itemBuilder: (ctx, i) {
                        final app = apps[i];
                        final already = existing.contains(app.packageName);
                        return ListTile(
                          leading: app.icon != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.memory(app.icon!, width: 36, height: 36))
                              : const Icon(Icons.apps_rounded),
                          title: Text(app.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(app.packageName, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          trailing: already
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.blue)
                              : const Icon(Icons.add_circle_outline_rounded, color: AppColors.muted),
                          onTap: already
                              ? null
                              : () async {
                                  await widget.gameRepository.addGame(app.packageName);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  await _reload();
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daftar Game', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: _openAddSheet,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _games.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: _games.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _GameCard(
                          game: _games[i],
                          onPlay: () => widget.overlayController.launchGame(_games[i].packageName),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_esports_outlined, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          const Text('Belum ada game ditambahkan', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextButton(onPressed: _openAddSheet, child: const Text('+ Tambah dari aplikasi terinstal')),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onPlay});

  final GameItem game;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppInfo?>(
      future: InstalledApps.getAppInfo(game.packageName),
      builder: (context, snapshot) {
        final app = snapshot.data;
        final name = app?.name ?? game.packageName;
        final icon = app?.icon;

        return Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: icon != null
                    ? Image.memory(icon, width: 42, height: 42)
                    : Container(width: 42, height: 42, color: AppColors.blueSoft, child: const Icon(Icons.sports_esports_rounded)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    Text(
                      game.lastPlayed != null ? 'Terakhir dimainkan · ${_relativeTime(game.lastPlayed!)}' : 'Belum pernah dimainkan lewat Pulse',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onPlay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Main', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
