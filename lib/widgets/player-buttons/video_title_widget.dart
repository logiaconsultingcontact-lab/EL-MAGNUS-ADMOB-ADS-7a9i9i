import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/playlist_content_model.dart';
import '../../../services/event_bus.dart';
import '../../../services/player_state.dart';

class VideoTitleWidget extends StatefulWidget {
  const VideoTitleWidget({super.key});

  @override
  State<VideoTitleWidget> createState() => _VideoTitleWidgetState();
}

class _VideoTitleWidgetState extends State<VideoTitleWidget> {
  late StreamSubscription subscription;
  String videoTitle = PlayerState.title;

  @override
  void initState() {
    super.initState();
    subscription = EventBus().on<ContentItem>('player_content_item').listen((
      ContentItem data,
    ) {
      if (mounted) {
        setState(() {
          videoTitle = data.name;
        });
      }
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      videoTitle,
      style: TextStyle(
        color:  Colors.white,
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}
