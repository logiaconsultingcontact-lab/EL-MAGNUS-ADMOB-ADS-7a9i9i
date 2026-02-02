import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import '../../../controllers/favorites_controller.dart';
import '../../../models/favorite.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/player_widget.dart';

class MovieScreen extends StatefulWidget {
  final ContentItem contentItem;

  const MovieScreen({super.key, required this.contentItem});

  @override
  _MovieScreenState createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  late FavoritesController _favoritesController;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _favoritesController = FavoritesController();
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _favoritesController.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await _favoritesController.isFavorite(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesController.toggleFavorite(widget.contentItem);
    if (mounted) {
      setState(() {
        _isFavorite = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? context.loc.added_to_favorites : context.loc.removed_from_favorites,
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
            PlayerWidget(contentItem: widget.contentItem),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔥 العنوان مع النجوم والمفضلة - حجم خط أصغر
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.contentItem.name,
                              style: Theme.of(context).textTheme.titleLarge // 🔥 حجم أصغر
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? Colors.red : Colors.grey,
                              size: 28,
                            ),
                          ),
                        ],
                      ),

                      // 🔥 النجوم والتقييم (في سطر منفصل)
                      if (isXtreamCode && widget.contentItem.vodStream != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              // النجوم
                              ...List.generate(5, (index) {
                                final rating = widget.contentItem.vodStream!.rating5based;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    index < (rating?.round() ?? 0)
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 20, // 🔥 حجم أصغر
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),
                              // التقييم الرقمي
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(widget.contentItem.vodStream!.rating5based ?? 0).toStringAsFixed(1)}/5',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12, // 🔥 حجم أصغر
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 🔥 التريلر
                      _buildTrailerCard(),

                      const SizedBox(height: 12),

                      // 🔥 تاريخ الإضافة فقط (تم إزالة الباقي)
                      _buildDetailCard(
                        icon: Icons.calendar_today,
                        title: context.loc.creation_date,
                        value: _formatDate('1746225795'),
                      ),
                      // 🔥 تم إزالة: Category ID, Stream ID, Format
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
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
      DateTime date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp) * 1000,
      );
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  Widget _buildTrailerCard() {
    final String? _trailerKey = widget.contentItem.vodStream?.youtubeTrailer;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        String urlString;
        if (_trailerKey != null && _trailerKey.isNotEmpty) {
          urlString = "https://www.youtube.com/watch?v=$_trailerKey";
        } else {
          final trailerText = context.loc.trailer;
          final languageCode = Localizations.localeOf(context).languageCode;
          final query = Uri.encodeQueryComponent("${widget.contentItem.name} $trailerText $languageCode");
          urlString = "https://www.youtube.com/results?search_query=$query";
        }

        final Uri url = Uri.parse(urlString);
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.error_occurred_title)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.ondemand_video, size: 20, color: Colors.red),
            ),
            const SizedBox(width: 16),
            Text(
              context.loc.trailer,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}