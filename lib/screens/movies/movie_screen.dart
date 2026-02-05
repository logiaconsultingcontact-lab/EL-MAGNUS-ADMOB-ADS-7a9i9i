import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:ELMAGNUS/utils/get_playlist_type.dart';
import 'package:flutter/material.dart';
import 'package:ELMAGNUS/models/playlist_content_model.dart';
import '../../../controllers/favorites_controller.dart';
import '../../../models/favorite.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/player_widget.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;


class MovieScreen extends StatefulWidget {
  final ContentItem contentItem;

  const MovieScreen({super.key, required this.contentItem});

  @override
  _MovieScreenState createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  late FavoritesController _favoritesController;
  bool _isFavorite = false;

  // ===== AdMob =====
  admob.BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _favoritesController = FavoritesController();
    _checkFavoriteStatus();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (kIsWeb) return;

    _bannerAd = admob.BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ID
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
    _favoritesController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await _favoritesController.isFavorite(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );
    if (mounted) {
      setState(() => _isFavorite = isFavorite);
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesController.toggleFavorite(widget.contentItem);
    if (mounted) {
      setState(() => _isFavorite = result);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? context.loc.added_to_favorites
                : context.loc.removed_from_favorites,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Player =====
            PlayerWidget(contentItem: widget.contentItem),

            // ===== Content =====
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.contentItem.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                              _isFavorite ? Colors.red : Colors.grey,
                              size: 28,
                            ),
                          ),
                        ],
                      ),

                      if (isXtreamCode &&
                          widget.contentItem.vodStream != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              ...List.generate(5, (index) {
                                final rating = widget
                                    .contentItem
                                    .vodStream!
                                    .rating5based;
                                return Padding(
                                  padding:
                                  const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    index <
                                        (rating?.round() ?? 0)
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                  Colors.amber.withOpacity(0.1),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(widget.contentItem.vodStream!.rating5based ?? 0).toStringAsFixed(1)}/5',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                      _buildTrailerCard(),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        icon: Icons.calendar_today,
                        title: context.loc.creation_date,
                        value: _formatDate('1746225795'),
                      ),
                    ],
                  ),
                ),
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

  // ===== Helpers =====

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp) * 1000,
      );
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return 'Bilinmiyor';
    }
  }

  Widget _buildTrailerCard() {
    final trailerKey =
        widget.contentItem.vodStream?.youtubeTrailer;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        String urlString;
        if (trailerKey != null && trailerKey.isNotEmpty) {
          urlString =
          "https://www.youtube.com/watch?v=$trailerKey";
        } else {
          final trailerText = context.loc.trailer;
          final languageCode =
              Localizations.localeOf(context).languageCode;
          final query = Uri.encodeQueryComponent(
              "${widget.contentItem.name} $trailerText $languageCode");
          urlString =
          "https://www.youtube.com/results?search_query=$query";
        }

        final url = Uri.parse(urlString);
        try {
          await launchUrl(url,
              mode: LaunchMode.externalApplication);
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                Text(context.loc.error_occurred_title)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border:
          Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.ondemand_video,
                  size: 20, color: Colors.red),
            ),
            const SizedBox(width: 16),
            Text(
              context.loc.trailer,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
