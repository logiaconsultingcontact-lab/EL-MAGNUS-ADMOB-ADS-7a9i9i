import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;
import 'package:provider/provider.dart';

import '../../controllers/playlist_controller.dart';
import '../../models/playlist_model.dart';
import '../../widgets/playlist_card.dart';
import '../../widgets/playlist_states.dart';
import 'playlist_type_screen.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  PlaylistScreenState createState() => PlaylistScreenState();
}

class PlaylistScreenState extends State<PlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlaylistController(),
      child: const _PlaylistScreenBody(),
    );
  }
}

class _PlaylistScreenBody extends StatefulWidget {
  const _PlaylistScreenBody();

  @override
  State<_PlaylistScreenBody> createState() => _PlaylistScreenBodyState();
}

class _PlaylistScreenBodyState extends State<_PlaylistScreenBody> {
  // ===== AdMob =====
  admob.BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (kIsWeb) return;

    _bannerAd = admob.BannerAd(
      adUnitId: 'ca-app-pub-9611779218616712/8387979950', // Test ID
      size: admob.AdSize.banner,
      request: const admob.AdRequest(),
      listener: admob.BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlaylistsIfNeeded(context);
    });

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<PlaylistController>(
                builder: (context, controller, child) =>
                    _buildBodyFromState(context, controller),
              ),
            ),

            // ===== Banner Ad =====
            if (_isBannerLoaded && _bannerAd != null)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: admob.AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  void _initializePlaylistsIfNeeded(BuildContext context) {
    final controller = context.read<PlaylistController>();
    if (!controller.isLoading &&
        controller.playlists.isEmpty &&
        controller.error == null) {
      controller.loadPlaylists(context);
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        context.loc.my_playlists,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBodyFromState(
      BuildContext context,
      PlaylistController controller,
      ) {
    if (controller.isLoading) {
      return const PlaylistLoadingState();
    }

    if (controller.error != null) {
      return PlaylistErrorState(
        error: controller.error!,
        onRetry: () => controller.loadPlaylists(context),
      );
    }

    if (controller.playlists.isEmpty) {
      return PlaylistEmptyState(
        onCreatePlaylist: () => _navigateToCreatePlaylist(context),
      );
    }

    return _buildPlaylistList(context, controller);
  }

  Widget _buildPlaylistList(
      BuildContext context,
      PlaylistController controller,
      ) {
    return RefreshIndicator(
      onRefresh: () => controller.loadPlaylists(context),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.playlists.length,
        itemBuilder: (context, index) {
          return PlaylistCard(
            playlist: controller.playlists[index],
            onTap: () =>
                controller.openPlaylist(context, controller.playlists[index]),
            onDelete: () => _showDeleteDialog(
              context,
              controller,
              controller.playlists[index],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _navigateToCreatePlaylist(context),
      tooltip: context.loc.create_new_playlist,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _navigateToCreatePlaylist(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlaylistTypeScreen()),
    );
  }

  void _showDeleteDialog(
      BuildContext context,
      PlaylistController controller,
      Playlist playlist,
      ) {
    showDialog(
      context: context,
      builder: (context) => _DeletePlaylistDialog(
        playlist: playlist,
        onDelete: () async {
          final success = await controller.deletePlaylist(playlist.id);
          if (success && context.mounted) {
            _showSuccessSnackBar(context, playlist.name);
          }
        },
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String playlistName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.loc.playlist_deleted(playlistName)),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _DeletePlaylistDialog extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onDelete;

  const _DeletePlaylistDialog({required this.playlist, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.loc.playlist_delete_confirmation_title),
      content: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              text: context.loc.playlist_delete_confirmation_message(
                playlist.name,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(context.loc.delete),
        ),
      ],
    );
  }
}
