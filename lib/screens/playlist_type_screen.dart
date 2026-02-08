import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:ELMAGNUS/screens/m3u/new_m3u_playlist_screen.dart';
import 'package:flutter/material.dart';
import 'xtream-codes/new_xtream_code_playlist_screen.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;

class PlaylistTypeScreen extends StatefulWidget {
  const PlaylistTypeScreen({super.key});

  @override
  State<PlaylistTypeScreen> createState() => _PlaylistTypeScreenState();
}

class _PlaylistTypeScreenState extends State<PlaylistTypeScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.loc.create_new_playlist,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ===== MAIN CONTENT =====
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                context.loc.select_playlist_type,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.loc.select_playlist_message,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 40),
                              _buildPlaylistTypeCard(
                                context,
                                title: 'Xtream Codes',
                                subtitle: context.loc.xtream_code_title,
                                description:
                                context.loc.xtream_code_description,
                                icon: Icons.stream,
                                color: Colors.blue,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                      const NewXtreamCodePlaylistScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildPlaylistTypeCard(
                                context,
                                title: 'M3U Playlist',
                                subtitle: context.loc.m3u_playlist_title,
                                description:
                                context.loc.m3u_playlist_description,
                                icon: Icons.playlist_play,
                                color: Colors.green,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                      const NewM3uPlaylistScreen(),
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.blue),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        context
                                            .loc.select_playlist_type_footer,
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
    );
  }

  // ===== CARD =====
  Widget _buildPlaylistTypeCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required String description,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(icon, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
