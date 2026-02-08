import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:ELMAGNUS/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ELMAGNUS/controllers/xtream_code_home_controller.dart';
import 'package:ELMAGNUS/models/api_configuration_model.dart';
import 'package:ELMAGNUS/models/category_view_model.dart';
import 'package:ELMAGNUS/models/playlist_model.dart';
import 'package:ELMAGNUS/repositories/iptv_repository.dart';
import 'package:ELMAGNUS/screens/category_detail_screen.dart';
import 'package:ELMAGNUS/screens/xtream-codes/xtream_code_playlist_settings_screen.dart';
import 'package:ELMAGNUS/screens/watch_history_screen.dart';
import 'package:ELMAGNUS/services/app_state.dart';
import 'package:ELMAGNUS/utils/navigate_by_content_type.dart';
import 'package:ELMAGNUS/utils/responsive_helper.dart';
import 'package:ELMAGNUS/widgets/category_section.dart';
import '../../models/content_type.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;

class XtreamCodeHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const XtreamCodeHomeScreen({super.key, required this.playlist});

  @override
  State<XtreamCodeHomeScreen> createState() => _XtreamCodeHomeScreenState();
}

class _XtreamCodeHomeScreenState extends State<XtreamCodeHomeScreen> {
  late XtreamCodeHomeController _controller;

  static const double _desktopBreakpoint = 900.0;
  static const double _largeScreenBreakpoint = 1200.0;
  static const double _defaultNavWidth = 80.0;
  static const double _largeNavWidth = 100.0;
  static const double _defaultItemHeight = 60.0;
  static const double _largeItemHeight = 70.0;
  static const double _defaultIconSize = 24.0;
  static const double _largeIconSize = 28.0;
  static const double _defaultFontSize = 10.0;
  static const double _largeFontSize = 11.0;

  int? _hoveredIndex;

  // ===== AdMob =====
  admob.BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _controller.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _initializeController() {
    final repository = IptvRepository(
      ApiConfig(
        baseUrl: widget.playlist.url!,
        username: widget.playlist.username!,
        password: widget.playlist.password!,
      ),
      widget.playlist.id,
    );
    AppState.xtreamCodeRepository = repository;
    _controller = XtreamCodeHomeController(false);
  }

  void _loadBannerAd() {
    if (kIsWeb) return;

    _bannerAd = admob.BannerAd(
      adUnitId: 'ca-app-pub-9611779218616712/8387979950', // TEST ID
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

  Widget _buildBannerAd() {
    if (!_isBannerLoaded || _bannerAd == null) return const SizedBox();

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: admob.AdWidget(ad: _bannerAd!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<XtreamCodeHomeController>(
        builder: (context, controller, child) =>
            _buildMainContent(context, controller),
      ),
    );
  }

  Widget _buildMainContent(
      BuildContext context,
      XtreamCodeHomeController controller,
      ) {
    if (controller.isLoading) {
      return _buildLoadingScreen(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktopLayout(context, controller, constraints);
        }
        return _buildMobileLayout(context, controller);
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.loc.loading_playlists),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
      BuildContext context,
      XtreamCodeHomeController controller,
      ) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _buildPageView(controller)),
          _buildBannerAd(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, controller),
    );
  }

  Widget _buildDesktopLayout(
      BuildContext context,
      XtreamCodeHomeController controller,
      BoxConstraints constraints,
      ) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildDesktopNavigationBar(context, controller, constraints),
                Expanded(child: _buildPageView(controller)),
              ],
            ),
          ),
          _buildBannerAd(),
        ],
      ),
    );
  }

  Widget _buildPageView(XtreamCodeHomeController controller) {
    return IndexedStack(
      index: controller.currentIndex,
      children: _buildPages(controller),
    );
  }

  List<Widget> _buildPages(XtreamCodeHomeController controller) {
    return [
      WatchHistoryScreen(
        key: ValueKey('watch_history_${controller.currentIndex}'),
        playlistId: widget.playlist.id,
      ),
      _buildContentPage(controller.liveCategories!, ContentType.liveStream),
      _buildContentPage(controller.movieCategories, ContentType.vod),
      _buildContentPage(controller.seriesCategories, ContentType.series),
      XtreamCodePlaylistSettingsScreen(playlist: widget.playlist),
    ];
  }

  Widget _buildContentPage(
      List<CategoryViewModel> categories,
      ContentType contentType,
      ) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          title: SelectableText(
            _getTitle(context, contentType),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          floating: true,
          snap: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _navigateToSearch(context, contentType),
            ),
          ],
        ),
      ],
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) => CategorySection(
          category: categories[index],
          cardWidth: ResponsiveHelper.getCardWidth(context),
          cardHeight: ResponsiveHelper.getCardHeight(context),
          onSeeAllTap: () => _navigateToCategoryDetail(categories[index]),
          onContentTap: (content) => navigateByContentType(context, content),
        ),
      ),
    );
  }

  String _getTitle(BuildContext context, ContentType contentType) {
    switch (contentType) {
      case ContentType.liveStream:
        return context.loc.live_streams;
      case ContentType.vod:
        return context.loc.movies;
      case ContentType.series:
        return context.loc.series_plural;
    }
  }

  void _navigateToSearch(BuildContext context, ContentType contentType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(contentType: contentType),
      ),
    );
  }

  void _navigateToCategoryDetail(CategoryViewModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(category: category),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar(
      BuildContext context,
      XtreamCodeHomeController controller,
      ) {
    return BottomNavigationBar(
      currentIndex: controller.currentIndex,
      onTap: controller.onNavigationTap,
      type: BottomNavigationBarType.fixed,
      items: _getNavigationItems(context)
          .map((item) =>
          BottomNavigationBarItem(icon: Icon(item.icon), label: item.label))
          .toList(),
    );
  }

  Widget _buildDesktopNavigationBar(
      BuildContext context,
      XtreamCodeHomeController controller,
      BoxConstraints constraints,
      ) {
    final navWidth = constraints.maxWidth >= _largeScreenBreakpoint
        ? _largeNavWidth
        : _defaultNavWidth;

    return Container(
      width: navWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _getNavigationItems(context).map((item) {
          final isSelected = controller.currentIndex == item.index;
          return GestureDetector(
            onTap: () => controller.onNavigationTap(item.index),
            child: Container(
              height: _defaultItemHeight,
              width: double.infinity,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon),
                  Text(item.label, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<NavigationItem> _getNavigationItems(BuildContext context) {
    return [
      NavigationItem(icon: Icons.history, label: context.loc.history, index: 0),
      NavigationItem(icon: Icons.live_tv, label: context.loc.live, index: 1),
      NavigationItem(
          icon: Icons.movie_outlined, label: context.loc.movie, index: 2),
      NavigationItem(
          icon: Icons.tv, label: context.loc.series_plural, index: 3),
      NavigationItem(
          icon: Icons.settings, label: context.loc.settings, index: 4),
    ];
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final int index;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}