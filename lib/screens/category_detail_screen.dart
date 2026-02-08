import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;
import 'package:provider/provider.dart';

import 'package:ELMAGNUS/models/category_view_model.dart';
import 'package:ELMAGNUS/utils/navigate_by_content_type.dart';
import '../controllers/category_detail_controller.dart';
import '../widgets/category_detail/category_app_bar.dart';
import '../widgets/category_detail/content_states.dart';
import '../widgets/category_detail/content_grid.dart';

class CategoryDetailScreen extends StatelessWidget {
  final CategoryViewModel category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CategoryDetailController(category),
      child: const _CategoryDetailView(),
    );
  }
}

class _CategoryDetailView extends StatefulWidget {
  const _CategoryDetailView();

  @override
  State<_CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<_CategoryDetailView> {
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryDetailController>(
      builder: (context, controller, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      CategoryAppBar(
                        title: controller.category.category.categoryName,
                        isSearching: controller.isSearching,
                        searchController: _searchController,
                        onSearchStart: controller.startSearch,
                        onSearchStop: () {
                          controller.stopSearch();
                          _searchController.clear();
                        },
                        onSearchChanged: controller.searchContent,
                        onSortPressed: () => _showSortOptions(controller),
                      ),
                    ],
                    body: _buildBody(controller),
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
      },
    );
  }

  Widget _buildBody(CategoryDetailController controller) {
    if (controller.isLoading) return const LoadingState();
    if (controller.errorMessage != null) {
      return ErrorState(
        message: controller.errorMessage!,
        onRetry: controller.loadContent,
      );
    }
    if (controller.isEmpty) return const EmptyState();

    return Column(
      children: [
        if (controller.genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: _buildGenreSelector(controller),
          ),
        Expanded(
          child: ContentGrid(
            items: controller.displayItems,
            onItemTap: (item) => navigateByContentType(context, item),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreSelector(CategoryDetailController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.loc.all),
            selected: controller.selectedGenre == null,
            onSelected: (_) => controller.filterByGenre(null),
          ),
          ...controller.genres.map(
                (g) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(_capitalizeGenre(g)),
                selected: controller.selectedGenre == g,
                onSelected: (_) => controller.filterByGenre(g),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(CategoryDetailController controller) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('A → Z'),
                onTap: () {
                  controller.sortItems("ascending");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Z → A'),
                onTap: () {
                  controller.sortItems("descending");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(context.loc.release_date),
                onTap: () {
                  controller.sortItems("release_date");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_rate),
                title: Text(context.loc.rating),
                onTap: () {
                  controller.sortItems("rating");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _capitalizeGenre(String genre) {
    if (genre.isEmpty) return genre;
    return genre
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      final first = word.characters.first.toUpperCase();
      final rest = word.characters.skip(1).join();
      return '$first$rest';
    })
        .join(' ');
  }
}
