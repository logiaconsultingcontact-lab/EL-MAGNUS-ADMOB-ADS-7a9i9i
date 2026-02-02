import 'dart:convert';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/models/epg_model.dart';

class EPGService {

  static final String epgUrl = 'http://xyltraxx.com/xmltv.php?username=67F14FA&password=PJ8L7XY';

  // Simple memory cache only
  static Map<String, List<EPGProgram>> _memoryCache = {};
  static String? _lastEPGData;

  static Future<List<EPGProgram>> getEPGForChannel(ContentItem contentItem) async {
    print('=== 🎯 EPG Service - Simple ===');
    print('Channel: ${contentItem.name}');
    print('tvgId: ${contentItem.m3uItem?.tvgId}');

    try {
      // Direct search without complications
      //await Future.delayed(Duration(seconds: 2)); hada n9dar nzido
      final programs = await _findEPGPrograms(contentItem);
      return programs.isNotEmpty ? programs : _getFallbackEPG(contentItem);

    } catch (e) {
      print('❌ EPG Error: $e');
      return _getFallbackEPG(contentItem);
    }
  }

  static Future<List<EPGProgram>> _findEPGPrograms(ContentItem contentItem) async {
    // Try to search from memory first
    final cacheKey = '${contentItem.m3uItem?.tvgId}_${contentItem.name}';
    if (_memoryCache.containsKey(cacheKey)) {
      print('✅ Found in memory: ${_memoryCache[cacheKey]!.length} programs');
      return _memoryCache[cacheKey]!;
    }

    // Load EPG data
    final epgData = await _loadEPGData();
    if (epgData == null) return [];

    // Search for channel
    final channelId = _findChannelId(epgData, contentItem);
    if (channelId == null) return [];

    // Parse programs
    final programs = _parsePrograms(epgData, channelId);

    // Simple memory save
    if (programs.isNotEmpty) {
      _memoryCache[cacheKey] = programs;
    }

    return programs;
  }

  static Future<String?> _loadEPGData() async {
    try {
      if (_lastEPGData != null) {
        print('🔄 Using EPG data from memory');
        return _lastEPGData;
      }

      print('🌐 Loading EPG data from server...');
      final response = await http.get(Uri.parse(epgUrl));

      if (response.statusCode == 200) {
        _lastEPGData = response.body;
        print('✅ Successfully loaded EPG data');
        return _lastEPGData;
      } else {
        print('❌ Failed to load EPG: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Connection error: $e');
      return null;
    }
  }

  static String? _findChannelId(String epgData, ContentItem contentItem) {
    try {
      final document = xml.XmlDocument.parse(epgData);
      final channels = document.findAllElements('channel');

      // List of keys to search
      final searchKeys = [
        contentItem.m3uItem?.tvgId,
        contentItem.liveStream?.epgChannelId,
        contentItem.name,
        _simplifyName(contentItem.name)
      ];

      for (final channel in channels) {
        final id = channel.getAttribute('id');
        final name = channel.findElements('display-name').firstOrNull?.text;

        for (final key in searchKeys) {
          if (key != null && key.isNotEmpty && _matchesChannel(id, name, key)) {
            print('✅ Channel matched: $id -> $name');
            return id;
          }
        }
      }

      print('❌ No matching channel found');
      return null;
    } catch (e) {
      print('❌ Error searching for channel: $e');
      return null;
    }
  }

  static List<EPGProgram> _parsePrograms(String epgData, String channelId) {
    final programs = <EPGProgram>[];

    try {
      final document = xml.XmlDocument.parse(epgData);
      final programmes = document.findAllElements('programme');
      int count = 0;

      for (final programme in programmes) {
        if (programme.getAttribute('channel') == channelId) {
          final title = programme.findElements('title').firstOrNull?.text ?? 'No Title';
          final desc = programme.findElements('desc').firstOrNull?.text ?? 'No Description';
          final start = programme.getAttribute('start');
          final stop = programme.getAttribute('stop');

          final startTime = _parseTime(start);
          final endTime = _parseTime(stop);

          if (startTime != null && endTime != null) {
            programs.add(EPGProgram(
              title: title,
              startTime: startTime.millisecondsSinceEpoch,
              endTime: endTime.millisecondsSinceEpoch,
              description: desc,
              isCurrent: DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime),
            ));
            count++;

            // Show first 2 programs for debugging
            if (count <= 2) {
              print('📺 $title - ${startTime.hour}:${startTime.minute}');
            }
          }
        }
      }

      print('✅ Parsed $count programs');
      return programs;
    } catch (e) {
      print('❌ Error parsing programs: $e');
      return [];
    }
  }

  static bool _matchesChannel(String? id, String? name, String searchKey) {
    if (id == null && name == null) return false;

    final cleanSearch = _simplifyName(searchKey);

    if (id != null && _simplifyName(id).contains(cleanSearch)) return true;
    if (name != null && _simplifyName(name).contains(cleanSearch)) return true;

    return false;
  }

  static String _simplifyName(String text) {
    return text
        .toLowerCase()
        .replaceAll('hd', '')
        .replaceAll('fhd', '')
        .replaceAll('sd', '')
        .replaceAll(RegExp(r'[0-9]'), '')
        .replaceAll(RegExp(r'[^\w]'), '')
        .trim();
  }

  static DateTime? _parseTime(String? timeString) {
    if (timeString == null || timeString.length < 14) return null;

    try {
      final year = int.parse(timeString.substring(0, 4));
      final month = int.parse(timeString.substring(4, 6));
      final day = int.parse(timeString.substring(6, 8));
      final hour = int.parse(timeString.substring(8, 10));
      final minute = int.parse(timeString.substring(10, 12));
      final second = int.parse(timeString.substring(12, 14));

      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (e) {
      return null;
    }
  }

  static List<EPGProgram> _getFallbackEPG(ContentItem contentItem) {
    final now = DateTime.now();
    return [
      EPGProgram(
        title: 'Live Stream - ${contentItem.name}',
        startTime: now.subtract(Duration(hours: 1)).millisecondsSinceEpoch,
        endTime: now.add(Duration(hours: 2)).millisecondsSinceEpoch,
        description: 'Program data is not currently available',
        isCurrent: true,
      ),
    ];
  }

  // To clear memory if needed
  static void clearMemory() {
    _memoryCache.clear();
    _lastEPGData = null;
    print('🧹 Memory cleared');
  }
}

