import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/epg_controller.dart';
import '../models/playlist_content_model.dart';
import '../models/epg_model.dart';


class EPGScreen extends StatelessWidget {
  final ContentItem channel;

  const EPGScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EPGController()..loadEPG(channel),
      child: Scaffold(
        appBar: AppBar(title: Text(channel.name)),
        body: Consumer<EPGController>(
          builder: (context, c, _) {
            if (c.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (c.programs.isEmpty) {
              return const Center(child: Text('No EPG available'));
            }

            return ListView.builder(
              itemCount: c.programs.length,
              itemBuilder: (_, i) {
                final p = c.programs[i];
                return ListTile(
                  title: Text(p.title),
                  subtitle: Text(
                    '${_fmt(p.startTime)} - ${_fmt(p.endTime)}',
                  ),
                  trailing: p.isCurrent
                      ? const Icon(Icons.circle, color: Colors.red, size: 10)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
