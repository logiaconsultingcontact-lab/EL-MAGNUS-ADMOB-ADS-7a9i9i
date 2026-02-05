import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;

import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:ELMAGNUS/utils/get_playlist_type.dart';
import 'package:ELMAGNUS/models/playlist_content_model.dart';
import 'package:ELMAGNUS/services/app_state.dart';

import '../../../models/content_type.dart';
import '../../../services/event_bus.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widgets/content_item_card_widget.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/player_widget.dart';
import '../../../controllers/favorites_controller.dart';
import '../../../models/favorite.dart';

class LiveStreamScreen extends StatefulWidget {
  final ContentItem content;

  const LiveStreamScreen({super.key, required this.content});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late ContentItem contentItem;
  List<ContentItem> allContents = [];
  bool allContentsLoaded = false;
  int selectedContentItemIndex = 0;
  late StreamSubscription contentItemIndexChangedSubscription;
  late FavoritesController _favoritesController;
  bool _isFavorite = false;

  // ===== AdMob =====
  admob.BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    contentItem = widget.content;
    _favoritesController = FavoritesController();
    _initializeQueue();
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

  Future<void> _initializeQueue() async {
    allContents = isXtreamCode
        ? (await AppState.xtreamCodeRepository!.getLiveChannelsByCategoryId(
      categoryId: widget.content.liveStream!.categoryId,
    ))!
        .map((x) => ContentItem(
      x.streamId,
      x.name,
      x.streamIcon,
      ContentType.liveStream,
      liveStream: x,
    ))
        .toList()
        : (await AppState.m3uRepository!.getM3uItemsByCategoryId(
      categoryId: widget.content.m3uItem!.categoryId!,
    ))!
        .map((x) => ContentItem(
      x.url,
      x.name ?? 'NO NAME',
      x.tvgLogo ?? '',
      ContentType.liveStream,
      m3uItem: x,
    ))
        .toList();

    setState(() {
      selectedContentItemIndex = allContents.indexWhere(
            (element) => element.id == widget.content.id,
      );
      allContentsLoaded = true;
    });

    contentItemIndexChangedSubscription = EventBus()
        .on<int>('player_content_item_index')
        .listen((int index) {
      if (!mounted) return;

      setState(() {
        selectedContentItemIndex = index;
        contentItem = allContents[selectedContentItemIndex];
      });
      _checkFavoriteStatus();
    });
  }

  @override
  void dispose() {
    contentItemIndexChangedSubscription.cancel();
    _favoritesController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await _favoritesController.isFavorite(
      contentItem.id,
      contentItem.contentType,
    );
    if (mounted) {
      setState(() => _isFavorite = isFavorite);
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesController.toggleFavorite(contentItem);
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
    if (!allContentsLoaded) {
      return Scaffold(
        body: SafeArea(child: buildFullScreenLoadingWidget()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlayerWidget(contentItem: widget.content, queue: allContents),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildOtherChannels(context),
                      const SizedBox(height: 24),
                      _buildChannelInfo(context),
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

  // ===== UI HELPERS =====

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            context.loc.live.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SelectableText(
            contentItem.name,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: _toggleFavorite,
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildOtherChannels(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          context.loc.other_channels,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ContentItemCardWidget(
          cardHeight: ResponsiveHelper.getCardHeight(context),
          cardWidth: ResponsiveHelper.getCardWidth(context),
          contentItems: allContents,
          onContentTap: _onContentTap,
          initialSelectedIndex: selectedContentItemIndex,
          isSelectionModeEnabled: true,
        ),
      ],
    );
  }

  Widget _buildChannelInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          context.loc.channel_information,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        _buildInfoCard(
          icon: Icons.signal_cellular_alt,
          title: context.loc.stream_type,
          value:
          contentItem.containerExtension?.toUpperCase() ??
              context.loc.live,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onContentTap(ContentItem contentItem) {
    setState(() {
      selectedContentItemIndex = allContents.indexOf(contentItem);
    });

    EventBus().emit(
      'player_content_item_index_changed',
      selectedContentItemIndex,
    );
  }
}
