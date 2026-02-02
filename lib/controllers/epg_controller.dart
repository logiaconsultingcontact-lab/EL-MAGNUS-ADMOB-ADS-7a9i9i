import 'package:flutter/material.dart';
import '../services/epg_service.dart';
import '../models/epg_model.dart';
import '../models/playlist_content_model.dart';

class EPGController extends ChangeNotifier {
  List<EPGProgram> programs = [];
  bool loading = false;
  String? error;

  Future<void> loadEPG(ContentItem channel) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      programs = await EPGService.getEPGForChannel(channel);
    } catch (e) {
      error = 'EPG load failed';
    }

    loading = false;
    notifyListeners();
  }
}
