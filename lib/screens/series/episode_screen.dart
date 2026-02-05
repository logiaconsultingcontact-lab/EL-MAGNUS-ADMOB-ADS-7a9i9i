import 'dart:async';
import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:ELMAGNUS/database/database.dart';
import 'package:ELMAGNUS/models/playlist_content_model.dart';
import 'package:ELMAGNUS/models/watch_history.dart';
import '../../../models/content_type.dart';
import '../../../services/event_bus.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/player_widget.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;


class EpisodeScreen extends StatefulWidget {
  final SeriesInfosData? seriesInfo;
  final List<SeasonsData> seasons;
  final List<EpisodesData> episodes;
  final ContentItem contentItem;
  final WatchHistory? watchHistory;

  const EpisodeScreen({
    super.key,
    required this.seriesInfo,
    required this.seasons,
    required this.episodes,
    required this.contentItem,
    this.watchHistory,
  });

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  late ContentItem contentItem;
  List<ContentItem> allContents = [];
  bool allContentsLoaded = false;
  int selectedContentItemIndex = 0;
  late StreamSubscription contentItemIndexChangedSubscription;
  final ScrollController _scrollController = ScrollController();

  // ===== AdMob Banner =====
  admob.BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    contentItem = widget.contentItem;
    _initializeQueue();
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
    contentItemIndexChangedSubscription.cancel();
    _scrollController.dispose();
    _bannerAd?.dispose(); // dispose AdMob
    super.dispose();
  }

  Future<void> _initializeQueue() async {
    allContents = widget.episodes
        .where((x) => x.season == widget.contentItem.season)
        .map((x) {
      return ContentItem(
        x.episodeId,
        x.title,
        x.movieImage ?? "",
        ContentType.series,
        containerExtension: x.containerExtension,
        season: x.season,
      );
    }).toList();

    setState(() {
      selectedContentItemIndex = allContents.indexWhere(
            (element) => element.id == widget.contentItem.id,
      );
      allContentsLoaded = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    });

    contentItemIndexChangedSubscription = EventBus()
        .on<int>('player_content_item_index')
        .listen((int index) {
      if (!mounted) return;

      setState(() {
        selectedContentItemIndex = index;
        contentItem = allContents[selectedContentItemIndex];
      });
    });
  }

  void _scrollToSelectedItem() {
    if (_scrollController.hasClients && selectedContentItemIndex >= 0) {
      final double itemHeight = 110.0;
      final double scrollOffset = selectedContentItemIndex * itemHeight;

      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onContentTap(ContentItem contentItem) {
    setState(() {
      if (!mounted) return;

      selectedContentItemIndex = allContents.indexOf(contentItem);
    });
    EventBus().emit(
      'player_content_item_index_changed',
      selectedContentItemIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!allContentsLoaded) {
      return buildFullScreenLoadingWidget();
    } else {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Player
              PlayerWidget(contentItem: widget.contentItem, queue: allContents),

              // محتوى الحلقة
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Header & List
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        contentItem.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      context.loc.episode_count(allContents.length.toString()),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: allContents.isEmpty
                                    ? Center(
                                  child: Text(context.loc.not_found_in_category),
                                )
                                    : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: allContents.length,
                                  itemBuilder: (context, index) {
                                    final episode = widget.episodes.firstWhere(
                                          (x) => x.episodeId == allContents[index].id,
                                    );
                                    return _buildEpisodeCard(episode, index);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
  }

  Widget _buildEpisodeCard(EpisodesData episode, int index) {
    bool isRecent = false;
    if (episode.releasedate != null && episode.releasedate!.isNotEmpty) {
      try {
        final releaseDate = DateTime.parse(episode.releasedate!);
        final diff = DateTime.now().difference(releaseDate).inDays;
        isRecent = diff <= 15;
      } catch (e) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selectedContentItemIndex == index
            ? Theme.of(context).colorScheme.primaryContainer
            : isRecent
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _onContentTap(allContents[index]);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: episode.movieImage != null && episode.movieImage!.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    episode.movieImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          '${episode.episodeNum}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                )
                    : Center(
                  child: Text(
                    '${episode.episodeNum}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            episode.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isRecent)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.loc.new_ep,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (episode.duration != null && episode.duration!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.loc.duration(episode.duration!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],

                    if (episode.plot != null && episode.plot!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        episode.plot!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (episode.rating != null && episode.rating! > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            episode.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Icon(
                    Icons.play_circle_outline,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}