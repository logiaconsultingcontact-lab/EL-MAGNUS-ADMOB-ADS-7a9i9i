import 'dart:async';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import '../../../models/content_type.dart';
import '../../../services/event_bus.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widgets/content_item_card_widget.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/player_widget.dart';
import '../../../controllers/favorites_controller.dart';
import '../../../models/favorite.dart';
// EPG imports
import 'package:another_iptv_player/models/epg_model.dart';
import 'package:another_iptv_player/services/epg_service.dart';

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

  // EPG variables
  List<EPGProgram> allEPGPrograms = [];
  List<EPGProgram> displayedEPGPrograms = [];
  bool isLoadingEPG = false;
  bool showEPG = false;
  Timer? _epgUpdateTimer;

  // Optimization variables
  bool _isEPGLoadingDebounced = false;
  DateTime? _lastEPGLoadTime;
  static const int _minEPGLoadInterval = 3000; // 3 seconds minimum between loads

  @override
  void initState() {
    super.initState();
    contentItem = widget.content;
    _favoritesController = FavoritesController();
    _initializeQueue();
    _checkFavoriteStatus();
    // لا تحمل EPG تلقائياً عند البدء
    _startEPGUpdateTimer();
  }

  @override
  void dispose() {
    contentItemIndexChangedSubscription.cancel();
    _favoritesController.dispose();
    _epgUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeQueue() async {
    allContents = isXtreamCode
        ? (await AppState.xtreamCodeRepository!.getLiveChannelsByCategoryId(
      categoryId: widget.content.liveStream!.categoryId,
    ))!.map((x) {
      return ContentItem(
        x.streamId,
        x.name,
        x.streamIcon,
        ContentType.liveStream,
        liveStream: x,
      );
    }).toList()
        : (await AppState.m3uRepository!.getM3uItemsByCategoryId(
      categoryId: widget.content.m3uItem!.categoryId!,
    ))!.map((x) {
      return ContentItem(
        x.url,
        x.name ?? 'NO NAME',
        x.tvgLogo ?? '',
        ContentType.liveStream,
        m3uItem: x,
      );
    }).toList();

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
      // تحميل EPG فقط إذا كان مفتوحاً
      if (showEPG) {
        _debouncedLoadEPGData();
      }
    });
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await _favoritesController.isFavorite(
      contentItem.id,
      contentItem.contentType,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final result = await _favoritesController.toggleFavorite(contentItem);
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

  // ========== OPTIMIZED EPG FUNCTIONS ==========
  Future<void> _loadEPGData() async {
    if (!mounted || _isEPGLoadingDebounced) return;

    // Check if we should load EPG (time-based debounce)
    final now = DateTime.now();
    if (_lastEPGLoadTime != null) {
      final diff = now.difference(_lastEPGLoadTime!).inMilliseconds;
      if (diff < _minEPGLoadInterval) {
        return; // Skip, too soon
      }
    }

    _isEPGLoadingDebounced = true;
    _lastEPGLoadTime = now;

    if (mounted) {
      setState(() {
        isLoadingEPG = true;
      });
    }

    try {
      // Load EPG with timeout to prevent hanging
      final programs = await _loadEPGWithTimeout();

      if (mounted) {
        setState(() {
          allEPGPrograms = programs;
          // Use optimized filter function
          displayedEPGPrograms = _getCurrentAndNextTwoOptimized(programs);
          isLoadingEPG = false;
          _isEPGLoadingDebounced = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingEPG = false;
          _isEPGLoadingDebounced = false;
          allEPGPrograms = [];
          displayedEPGPrograms = [];
        });
      }
      print('EPG Load Error: $e');
    }
  }

  Future<List<EPGProgram>> _loadEPGWithTimeout() async {
    // Use Completer with timeout
    final completer = Completer<List<EPGProgram>>();
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete([]); // Return empty list on timeout
      }
    });

    try {
      final programs = await EPGService.getEPGForChannel(contentItem);
      timeoutTimer.cancel();
      completer.complete(programs);
    } catch (e) {
      timeoutTimer.cancel();
      completer.complete([]); // Return empty list on error
    }

    return completer.future;
  }

  void _debouncedLoadEPGData() {
    // Cancel any pending load
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _loadEPGData();
      }
    });
  }

  // OPTIMIZED version of getCurrentAndNextTwo
  List<EPGProgram> _getCurrentAndNextTwoOptimized(List<EPGProgram> allPrograms) {
    if (allPrograms.isEmpty) return [];

    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <EPGProgram>[];

    // Only sort if needed (when more than 1 program)
    List<EPGProgram> sortedPrograms = allPrograms;
    if (allPrograms.length > 1) {
      sortedPrograms = List<EPGProgram>.from(allPrograms)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    // Find current program
    int currentIndex = -1;
    for (int i = 0; i < sortedPrograms.length; i++) {
      final program = sortedPrograms[i];
      if (now >= program.startTime && now <= program.endTime) {
        currentIndex = i;
        break;
      }
    }

    // If no current, find first upcoming
    if (currentIndex == -1) {
      for (int i = 0; i < sortedPrograms.length; i++) {
        if (sortedPrograms[i].startTime > now) {
          currentIndex = i;
          break;
        }
      }
    }

    if (currentIndex == -1 || currentIndex >= sortedPrograms.length) {
      return result;
    }

    // Add max 3 programs
    final endIndex = (currentIndex + 3).clamp(0, sortedPrograms.length);
    for (int i = currentIndex; i < endIndex; i++) {
      final program = sortedPrograms[i];
      final isCurrent = now >= program.startTime && now <= program.endTime;

      if (i == currentIndex && isCurrent) {
        result.add(program.copyWith(isCurrent: true, isNext: false, isUpcoming: false));
      } else if (i == currentIndex + 1) {
        result.add(program.copyWith(isCurrent: false, isNext: true, isUpcoming: false));
      } else if (i == currentIndex + 2) {
        result.add(program.copyWith(isCurrent: false, isNext: false, isUpcoming: true));
      } else {
        result.add(program.copyWith(isCurrent: false, isNext: false, isUpcoming: false));
      }
    }

    return result;
  }

  // Keep original for compatibility
  List<EPGProgram> _getCurrentAndNextTwo(List<EPGProgram> allPrograms) {
    return _getCurrentAndNextTwoOptimized(allPrograms);
  }

  EPGProgram _updateProgramStatus(EPGProgram program, int position, int currentIndex) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isCurrentProgram = now >= program.startTime && now <= program.endTime;

    if (position == 0 && isCurrentProgram) {
      return program.copyWith(isCurrent: true, isNext: false, isUpcoming: false);
    } else if (position == 1) {
      return program.copyWith(isCurrent: false, isNext: true, isUpcoming: false);
    } else if (position == 2) {
      return program.copyWith(isCurrent: false, isNext: false, isUpcoming: true);
    }

    return program.copyWith(isCurrent: false, isNext: false, isUpcoming: false);
  }

  void _startEPGUpdateTimer() {
    // Update less frequently - every 2 minutes instead of 1
    _epgUpdateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted && showEPG && allEPGPrograms.isNotEmpty) {
        // Only update if EPG is visible and we have data
        setState(() {
          displayedEPGPrograms = _getCurrentAndNextTwoOptimized(allEPGPrograms);
        });
      }
    });
  }

  void _toggleEPG() {
    setState(() {
      showEPG = !showEPG;
      // Load EPG data when opening for the first time
      if (showEPG && allEPGPrograms.isEmpty && !isLoadingEPG && !_isEPGLoadingDebounced) {
        _loadEPGData();
      }
    });
  }

  Widget _buildEPGSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // EPG section title with toggle button
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                'Program Guide',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const Spacer(),
              // Show loading indicator on icon when loading
              if (isLoadingEPG)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: IconButton(
                    onPressed: _toggleEPG,
                    icon: Icon(
                      showEPG ? Icons.expand_less : Icons.expand_more,
                      color: Colors.red,
                      size: 28,
                    ),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // EPG content (show/hide)
        if (showEPG) ...[
          if (isLoadingEPG)
            _buildEPGLoading()
          else if (displayedEPGPrograms.isEmpty)
            _buildNoEPGMessage(context)
          else
            _buildEPGList(context),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildEPGLoading() {
    return Center(
      child: Column(
        children: [
          CircularProgressIndicator(color: Colors.red),
          const SizedBox(height: 12),
          Text(
            'Loading program guide...',
            style: TextStyle(
              color: _getTextColor(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEPGMessage(BuildContext context) {
    final textColor = _getTextColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No program data available for this channel',
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEPGList(BuildContext context) {
    return Column(
      children: [
        // Use builder for better performance
        ...List.generate(displayedEPGPrograms.length, (index) {
          return _buildEPGItem(displayedEPGPrograms[index], context);
        }),
      ],
    );
  }

  Widget _buildEPGItem(EPGProgram program, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _getTextColor(context);
    final secondaryTextColor = _getSecondaryTextColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: program.isCurrent
            ? Colors.red.withOpacity(0.1)
            : isDarkMode
            ? Colors.grey[900]!.withOpacity(0.2)
            : Colors.grey[50]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: program.isCurrent
              ? Colors.red
              : isDarkMode
              ? Colors.grey[700]!
              : Colors.grey[300]!,
          width: program.isCurrent ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(program.startTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: program.isCurrent
                        ? Colors.red
                        : textColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(program.endTime),
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Red separator line
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.red,
          ),

          // Program details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Program title with status indicator
                Row(
                  children: [
                    if (program.isCurrent)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),

                    Expanded(
                      child: Text(
                        program.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: program.isCurrent
                              ? Colors.red
                              : textColor,
                          fontSize: program.isCurrent ? 16 : 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(program),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(program),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Program description (lazy loaded)
                if (program.description.isNotEmpty)
                  Text(
                    program.description,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 8),

                // Duration and remaining time
                Row(
                  children: [
                    // Duration
                    Text(
                      'Duration: ${_getDuration(program)}',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),

                    const Spacer(),

                    // Remaining time for current program
                    if (program.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTimeRemaining(program),
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                // Progress bar for current program
                if (program.isCurrent)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: 3,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey[700]!
                          : Colors.grey[300]!,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _getProgress(program),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Color _getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[300]!
        : Colors.grey[700]!;
  }

  Color _getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[900]!.withOpacity(0.3)
        : Colors.grey[100]!.withOpacity(0.3);
  }

  String _formatTime(int timestamp) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getDuration(EPGProgram program) {
    final duration = Duration(milliseconds: program.endTime - program.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  double _getProgress(EPGProgram program) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (program.isCurrent) {
      final totalDuration = program.endTime - program.startTime;
      final elapsed = now - program.startTime;
      return (elapsed / totalDuration).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String _getTimeRemaining(EPGProgram program) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (program.isCurrent) {
      final remaining = Duration(milliseconds: program.endTime - now);
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);

      if (hours > 0) {
        return 'Ends in ${hours}h ${minutes}m';
      } else {
        return 'Ends in ${minutes}m';
      }
    }
    return '';
  }

  Color _getStatusColor(EPGProgram program) {
    if (program.isCurrent) {
      return Colors.red;
    } else if (program.isNext) {
      return Colors.blue;
    } else if (program.isUpcoming) {
      return Colors.grey[700]!;
    }
    return Colors.grey;
  }

  String _getStatusText(EPGProgram program) {
    if (program.isCurrent) return 'LIVE';
    if (program.isNext) return 'NEXT';
    if (program.isUpcoming) return 'UPCOMING';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (!allContentsLoaded) {
      return Scaffold(body: SafeArea(child: buildFullScreenLoadingWidget()));
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
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SelectableText(
                                  context.loc.live.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SelectableText(
                              contentItem.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
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
                      const SizedBox(height: 24),
                      SelectableText(
                        context.loc.other_channels,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                      const SizedBox(height: 24),

                      // EPG section
                      _buildEPGSection(),
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

  _onContentTap(ContentItem contentItem) {
    setState(() {
      if (!mounted) return;

      selectedContentItemIndex = allContents.indexOf(contentItem);
    });
    EventBus().emit(
      'player_content_item_index_changed',
      selectedContentItemIndex,
    );
  }
}