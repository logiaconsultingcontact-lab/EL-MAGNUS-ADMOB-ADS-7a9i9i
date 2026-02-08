import 'package:ELMAGNUS/l10n/localization_extension.dart';
import 'package:ELMAGNUS/screens/xtream-codes/xtream_code_data_loader_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../controllers/playlist_controller.dart';
import '../../../../models/api_configuration_model.dart';
import '../../../../models/playlist_model.dart';
import '../../../../repositories/iptv_repository.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;


class NewXtreamCodePlaylistScreen extends StatefulWidget {
  const NewXtreamCodePlaylistScreen({super.key});

  @override
  NewXtreamCodePlaylistScreenState createState() =>
      NewXtreamCodePlaylistScreenState();
}

class NewXtreamCodePlaylistScreenState
    extends State<NewXtreamCodePlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Playlist-1');
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isFormValid = false;

  // ===== AdMob =====
  admob.BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();

    _nameController.addListener(_validateForm);
    _urlController.addListener(_validateForm);
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);

    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid =
          _nameController.text.trim().isNotEmpty &&
              _urlController.text.trim().isNotEmpty &&
              _usernameController.text.trim().isNotEmpty &&
              _passwordController.text.trim().isNotEmpty;
    });
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('XStream Playlist')),
      body: SafeArea(
        child: Column(
          children: [
            // ===== MAIN CONTENT =====
            Expanded(
              child: Consumer<PlaylistController>(
                builder: (context, controller, child) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(colorScheme),
                          const SizedBox(height: 32),
                          _buildPlaylistNameField(colorScheme),
                          const SizedBox(height: 20),
                          _buildUrlField(colorScheme),
                          const SizedBox(height: 20),
                          _buildUsernameField(colorScheme),
                          const SizedBox(height: 20),
                          _buildPasswordField(colorScheme),
                          const SizedBox(height: 32),
                          _buildSaveButton(controller, colorScheme),
                          if (controller.error != null) ...[
                            const SizedBox(height: 20),
                            _buildErrorCard(controller.error!, colorScheme),
                          ],
                          const SizedBox(height: 20),
                          _buildInfoCard(colorScheme),
                        ],
                      ),
                    ),
                  );
                },
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

  // ================= UI =================

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(Icons.stream, size: 30, color: colorScheme.onPrimary),
        ),
        const SizedBox(height: 16),
        Text(
          'XStream Code Playlist',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.loc.xtream_code_description,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistNameField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: context.loc.playlist_name,
        prefixIcon: Icon(Icons.playlist_add, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.loc.playlist_name_required;
        }
        if (value.trim().length < 2) {
          return context.loc.playlist_name_min_2;
        }
        return null;
      },
    );
  }

  Widget _buildUrlField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _urlController,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: context.loc.api_url,
        prefixIcon: Icon(Icons.link, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.loc.api_url_required;
        }
        final uri = Uri.tryParse(value.trim());
        if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
          return context.loc.url_format_validate_error;
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: context.loc.username,
        prefixIcon: Icon(Icons.person, color: colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.loc.username_required;
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: context.loc.password,
        prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.loc.password_required;
        }
        return null;
      },
    );
  }

  Widget _buildSaveButton(
      PlaylistController controller,
      ColorScheme colorScheme,
      ) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: controller.isLoading
            ? null
            : (_isFormValid ? _savePlaylist : null),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: controller.isLoading ? 0 : 2,
        ),
        child: controller.isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.onPrimary,
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              context.loc.submitting,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save, size: 20),
            SizedBox(width: 8),
            Text(
              context.loc.submit_create_playlist,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error, ColorScheme colorScheme) {
    return Text(
      error,
      style: TextStyle(color: colorScheme.error),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Text(
      context.loc.all_datas_are_stored_in_device,
      style: TextStyle(color: colorScheme.primary),
    );
  }

  Future<void> _savePlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    final controller =
    Provider.of<PlaylistController>(context, listen: false);

    controller.clearError();

    final repository = IptvRepository(
      ApiConfig(
        baseUrl: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      ),
      _nameController.text.trim(),
    );

    final playerInfo = await repository.getPlayerInfo(forceRefresh: true);

    if (playerInfo == null) {
      controller.setError(context.loc.invalid_credentials);
      return;
    }

    final playlist = await controller.createPlaylist(
      name: _nameController.text.trim(),
      type: PlaylistType.xtream,
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (playlist != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              XtreamCodeDataLoaderScreen(playlist: playlist),
        ),
      );
    }
  }
}
