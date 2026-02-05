import 'package:ELMAGNUS/models/content_type.dart';
import 'package:ELMAGNUS/models/live_stream.dart';
import 'package:ELMAGNUS/models/m3u_item.dart';
import 'package:ELMAGNUS/models/series.dart';
import 'package:ELMAGNUS/models/vod_streams.dart';
import 'package:ELMAGNUS/utils/build_media_url.dart';
import 'package:ELMAGNUS/utils/get_playlist_type.dart';

class ContentItem {
  final String id;
  late String url;
  final String name;
  final String imagePath;
  final String? description;
  final Duration? duration;
  final String? coverPath;
  final String? containerExtension;
  final ContentType contentType;
  final LiveStream? liveStream;
  final VodStream? vodStream;
  final SeriesStream? seriesStream;
  final int? season;
  final M3uItem? m3uItem;
  final String? serverUrl;
  final String? username;
  final String? password;

  ContentItem(
      this.id,
      this.name,
      this.imagePath,
      this.contentType, {
        this.description,
        this.duration,
        this.coverPath,
        this.containerExtension,
        this.liveStream,
        this.vodStream,
        this.seriesStream,
        this.season,
        this.m3uItem,
        this.serverUrl,
        this.username,
        this.password,
      }) {
    url = isXtreamCode ? buildMediaUrl(this) : m3uItem?.url ?? id;
  }

  // ✅ أضف هذه الخصائص فقط (3 خصائص جديدة)

  // 1. جلب tvgId مباشرة من m3uItem إذا كان موجوداً
  String? get tvgId => m3uItem?.tvgId;

  // 2. اسم نظيف للبحث (إزالة الجودة)
  String get cleanName {
    return name
        .replaceAll(' HD', '')
        .replaceAll(' FHD', '')
        .replaceAll(' SD', '')
        .replaceAll(' 4K', '')
        .replaceAll(' UHD', '')
        .trim();
  }

  // 3. أفضل معرف للـ EPG (tvgId أولاً، ثم الاسم النظيف)
  String get bestEpgIdentifier {
    return tvgId ?? cleanName;
  }
}