import 'package:ELMAGNUS/models/m3u_item.dart';
import 'package:ELMAGNUS/models/playlist_model.dart';
import 'package:ELMAGNUS/repositories/iptv_repository.dart';
import 'package:ELMAGNUS/repositories/m3u_repository.dart';

abstract class AppState {
  static Playlist? currentPlaylist;
  static IptvRepository? xtreamCodeRepository;
  static M3uRepository? m3uRepository;
  static List<M3uItem>? m3uItems;
}
