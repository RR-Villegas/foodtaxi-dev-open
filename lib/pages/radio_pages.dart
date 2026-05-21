import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../services/database_service.dart';
import '../services/radio_player.dart';
import '../buyer_profile_page.dart';
import '../seller_page.dart';
import '../rider_profile_page.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _radioPlayer = WebRadioPlayer();
  Timer? _metadataTimer;
  Timer? _songProgressTimer;
  String? _lastSongId;
  DateTime? _songProgressStartedAt;
  double _songPlayedAtSync = 0;
  double _songDurationAtSync = 0;

  RealtimeChannel? _radioChannel;

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _radioStatus;

  bool _sending = false;
  bool _chatLoading = true;
  bool _radioLoading = true;
  bool _audioLoading = false;
  bool _playing = false;

  static const String _volumePreferenceKey = 'gensokyo_radio_volume';

  double _volume = 0.5;

  static final Uri _radioUrl = Uri.parse(
    'https://gensokyoradio.net/playing/',
  );

  static const String _streamUrl = 'https://stream.gensokyoradio.net/1/';

  bool get _isLoggedIn => _supabase.auth.currentUser != null;

  @override
  void initState() {
    super.initState();

    _radioPlayer.init(
      streamUrl: _streamUrl,
      initialVolume: _volume,
      onPlay: () {
        if (!mounted) return;

        setState(() {
          _playing = true;
          _audioLoading = false;
        });
      },
      onPause: () {
        if (!mounted) return;

        setState(() {
          _playing = false;
          _audioLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Radio audio error: $error');

        if (!mounted) return;

        setState(() {
          _playing = false;
          _audioLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
          ),
        );
      },
    );

    if (_isLoggedIn) {
      _loadRadioStatus();
      _loadSavedVolume();
      _loadInitialMessages();
      _subscribeToRadioMessages();
    } else {
      _chatLoading = false;
      _radioLoading = false;
    }
  }

  Future<void> _toggleAudio() async {
    if (_audioLoading) return;

    try {
      if (_playing) {
        _radioPlayer.stop();

        if (mounted) {
          setState(() {
            _playing = false;
            _audioLoading = false;
          });
        }

        return;
      }

      setState(() => _audioLoading = true);
      _radioPlayer.play();
    } catch (e) {
      debugPrint('Radio audio error: $e');

      if (!mounted) return;

      setState(() {
        _playing = false;
        _audioLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not play stream here. $e'),
        ),
      );
    }
  }

  void _syncSongProgressFromStatus() {
    final duration = _radioNumber('duration')?.toDouble() ?? 0;
    final played = _radioNumber('played')?.toDouble() ?? 0;

    _songDurationAtSync = duration <= 0 ? 0 : duration;
    _songPlayedAtSync = played.clamp(0, _songDurationAtSync).toDouble();
    _songProgressStartedAt = DateTime.now();

    _startSongProgressTicker();
  }

  void _startSongProgressTicker() {
    _songProgressTimer?.cancel();

    if (_songDurationAtSync <= 0) return;

    _songProgressTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final played = _visualPlayedSeconds();

        if (played >= _songDurationAtSync) {
          _songProgressTimer?.cancel();
        }

        setState(() {});
      },
    );
  }

  void _scheduleNextMetadataUpdate() {
    _metadataTimer?.cancel();

    final remaining = _radioNumber('remaining');

    // Gensokyo gives remaining seconds. Add a small delay so the API has time
    // to swap to the next song before we ask again.
    final secondsUntilRefresh = remaining == null
        ? 20
        : (remaining + 3).clamp(8, 900).round();

    _metadataTimer = Timer(
      Duration(seconds: secondsUntilRefresh),
      () {
        if (!mounted) return;
        _loadRadioStatus(silent: true);
      },
    );
  }

  Future<void> _loadSavedVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_volumePreferenceKey);

    if (!mounted) return;

    final value = (saved ?? 0.5).clamp(0.0, 1.0).toDouble();

    setState(() => _volume = value);
    _radioPlayer.setVolume(value);
  }

  Future<void> _setVolume(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();

    setState(() => _volume = normalized);
    _radioPlayer.setVolume(normalized);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumePreferenceKey, normalized);
  }

  Future<void> _loadRadioStatus({bool silent = false}) async {
    if (mounted && !silent) {
      setState(() => _radioLoading = true);
    }

    final status = await DatabaseService.getGensokyoRadioStatus();

    if (!mounted) return;

    final newSongId = status?['songId']?.toString();
    final oldSongId = _lastSongId;

    setState(() {
      _radioStatus = status;
      _radioLoading = false;
      _lastSongId = newSongId;
    });

    if (silent &&
        oldSongId != null &&
        newSongId != null &&
        oldSongId != newSongId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Now playing: ${_statusText('title', 'New song')}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _scheduleNextMetadataUpdate();
    _syncSongProgressFromStatus();
  }

  Future<void> _openRadioExternal() async {
    final opened = await launchUrl(
      _radioUrl,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Gensokyo Radio.'),
        ),
      );
    }
  }

  Future<void> _loadInitialMessages() async {
    if (mounted) {
      setState(() => _chatLoading = true);
    }

    final messages = await DatabaseService.getRadioMessages();

    if (!mounted) return;

    setState(() {
      _messages = messages;
      _chatLoading = false;
    });
  }

  void _subscribeToRadioMessages() {
    _radioChannel = _supabase
        .channel('radio-room')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'radio_message',
          callback: (payload) async {
            await _loadInitialMessages();
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    if (!_isLoggedIn || _sending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    final success = await DatabaseService.sendRadioMessage(text);

    if (!mounted) return;

    setState(() => _sending = false);

    if (success) {
      _messageController.clear();
      await _loadInitialMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message could not be sent.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _radioPlayer.dispose();
    _messageController.dispose();

    final channel = _radioChannel;
    if (channel != null) {
      _supabase.removeChannel(channel);
    }
    _metadataTimer?.cancel();
    _songProgressTimer?.cancel();
    super.dispose();
  }

  Widget _lockedView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gensokyo Radio'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 72),
                  const SizedBox(height: 20),
                  const Text(
                    'Members Only',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Login required to access the Gensokyo Radio room.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  num? _radioNumber(String key) {
    final value = _radioStatus?[key];

    if (value is num) return value;

    return num.tryParse(value?.toString() ?? '');
  }

  String _formatSongTime(double seconds) {
    final safeSeconds = seconds.isFinite ? seconds.clamp(0, 86400).round() : 0;
    final minutes = safeSeconds ~/ 60;
    final remainder = safeSeconds % 60;

    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  double _visualPlayedSeconds() {
    final startedAt = _songProgressStartedAt;

    if (startedAt == null || _songDurationAtSync <= 0) {
      return _radioNumber('played')?.toDouble() ?? 0;
    }

    final elapsed = DateTime.now().difference(startedAt).inMilliseconds / 1000;
    return (_songPlayedAtSync + elapsed).clamp(0, _songDurationAtSync).toDouble();
  }

  String _statusText(String key, String fallback) {
    final value = _radioStatus?[key]?.toString().trim();

    if (value == null || value.isEmpty || value == 'null') {
      return fallback;
    }

    return value;
  }

  String? _statusNullable(String key) {
    final value = _radioStatus?[key]?.toString().trim();

    if (value == null || value.isEmpty || value == 'null') {
      return null;
    }

    return value;
  }

  Uint8List? _artBytes() {
    final artImage = _radioStatus?['artImage'];

    if (artImage is! Map) return null;

    final base64 = artImage['base64']?.toString();

    if (base64 == null || base64.isEmpty) return null;

    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  Widget _albumArt({
    required double size,
    required Color fallbackColor,
  }) {
    final bytes = _artBytes();

    return ClipRRect(
      borderRadius: BorderRadius.circular(size >= 180 ? 22 : 14),
      child: SizedBox(
        width: size,
        height: size,
        child: bytes == null
            ? ColoredBox(
                color: fallbackColor,
                child: Icon(
                  Icons.radio,
                  size: size * 0.42,
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) {
                  return ColoredBox(
                    color: fallbackColor,
                    child: Icon(
                      Icons.radio,
                      size: size * 0.42,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _playButton({required bool compact}) {
    if (_audioLoading) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(compact ? 'Loading' : 'Loading Stream'),
      );
    }

    return FilledButton.icon(
      onPressed: _toggleAudio,
      icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
      label: Text(_playing ? 'Stop' : 'Play'),
    );
  }

  Widget _volumeControl({required bool compact}) {
    final label = '${(_volume * 100).round()}%';
    final icon = _volume == 0
        ? Icons.volume_off
        : _volume < 0.5
            ? Icons.volume_down
            : Icons.volume_up;

    if (compact) {
      return Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: _volume,
              min: 0,
              max: 1,
              onChanged: _setVolume,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        SizedBox(
          width: 160,
          child: Slider(
            value: _volume,
            min: 0,
            max: 1,
            onChanged: _setVolume,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(label),
        ),
      ],
    );
  }

  Widget _songProgressBar({required bool compact}) {
    final duration = _songDurationAtSync;
    final played = _visualPlayedSeconds();

    if (duration <= 0) {
      return const SizedBox.shrink();
    }

    final value = (played / duration).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            disabledThumbColor: Theme.of(context).colorScheme.primary,
            disabledActiveTrackColor: Theme.of(context).colorScheme.primary,
            disabledInactiveTrackColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            onChanged: null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                _formatSongTime(played),
                style: const TextStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                _formatSongTime(duration),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radioPanel({
    required bool compact,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final title = _statusText('title', 'Gensokyo Radio');
    final artist = _statusText('artist', 'Touhou Music');
    final album = _statusNullable('album');
    final circle = _statusNullable('circle');

    return Card(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.tertiaryContainer,
            ],
          ),
        ),
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _albumArt(
                        size: 70,
                        fallbackColor: scheme.surface,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _radioLoading
                            ? const Text('Loading radio...')
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loadRadioStatus,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton.filled(
                        tooltip: _playing ? 'Stop' : 'Play',
                        onPressed: _audioLoading ? null : _toggleAudio,
                        icon: _audioLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_playing ? Icons.stop : Icons.play_arrow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _songProgressBar(compact: true),
                  const SizedBox(height: 8),
                  _volumeControl(compact: true),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final useColumn = constraints.maxWidth < 720;
                  final artSize = useColumn
                      ? constraints.maxWidth.clamp(180.0, 320.0)
                      : (constraints.maxWidth * 0.38).clamp(220.0, 340.0);

                  final details = _radioLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: useColumn
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: useColumn
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: TextStyle(
                                fontSize: useColumn ? 24 : 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              artist,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: useColumn
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: TextStyle(
                                fontSize: useColumn ? 18 : 22,
                              ),
                            ),
                            if (album != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                album,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: useColumn
                                    ? TextAlign.center
                                    : TextAlign.start,
                              ),
                            ],
                            if (circle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  circle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: useColumn
                                      ? TextAlign.center
                                      : TextAlign.start,
                                ),
                              ],
                              const SizedBox(height: 16),
                              _songProgressBar(compact: useColumn),
                              const SizedBox(height: 20),
                              Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: useColumn
                                  ? WrapAlignment.center
                                  : WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _playButton(compact: false),
                                _volumeControl(compact: false),
                                OutlinedButton.icon(
                                  onPressed: _loadRadioStatus,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _openRadioExternal,
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open Player'),
                                ),
                              ],
                            ),
                          ],
                        );

                  if (useColumn) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _albumArt(
                            size: artSize,
                            fallbackColor: scheme.surface,
                          ),
                          const SizedBox(height: 20),
                          details,
                        ],
                      ),
                    );
                  }

                  return Row(
                    children: [
                      _albumArt(
                        size: artSize,
                        fallbackColor: scheme.surface,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: details,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openAccountProfileFromChat(Map<String, dynamic> item) async {
    final account = item['account'];

    if (account is! Map) return;

    final accountId = account['account_id']?.toString().trim();
    final role = account['account_type']?.toString().trim();

    if (accountId == null || accountId.isEmpty) return;

    final normalizedRole = role?.toLowerCase();

    if (normalizedRole == null || normalizedRole.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not detect this user role. Refresh and try again.'),
        ),
      );
      return;
    }

    if (normalizedRole == 'admin') {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin profiles cannot be viewed.'),
        ),
      );
      return;
    }

    if (normalizedRole == 'rider') {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderProfilePage(
            riderAccountId: accountId,
          ),
        ),
      );
      return;
    }

    if (normalizedRole == 'seller') {
      final store = await DatabaseService.getStoreByOwnerAccountId(accountId);

      if (!mounted) return;

      final storeId = store?['store_id']?.toString();

      if (storeId == null || storeId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller storefront not found.'),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerPage(storeId: storeId),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerProfilePage(
          buyerAccountId: accountId,
          allowReport: false,
        ),
      ),
    );
  }

  Widget _chatBubble(BuildContext context, Map<String, dynamic> item) {
    final scheme = Theme.of(context).colorScheme;
    final account = item['account'] as Map<String, dynamic>?;

    final name = [
      account?['firstname'],
      account?['surname'],
    ].whereType<String>().join(' ').trim();

    final role = account?['account_type']?.toString().trim();
    final roleLabel = role == null || role.isEmpty ? 'Unknown' : role;

    final displayName = name.isEmpty
        ? 'Unknown User ($roleLabel)'
        : '$name ($roleLabel)';

    final avatar = account?['profile_image_url']?.toString();
    final accountId = account?['account_id']?.toString();
    final canOpenProfile = accountId != null && accountId.isNotEmpty;

    ImageProvider? avatarProvider;

    if (avatar != null && avatar.isNotEmpty) {
      avatarProvider = NetworkImage(
        avatar.startsWith('http')
            ? avatar
            : DatabaseService.getProfileImageUrl(avatar),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: canOpenProfile ? () => _openAccountProfileFromChat(item) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(name.isEmpty ? '?' : name[0])
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (canOpenProfile)
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item['message']?.toString() ?? ''),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatBody() {
    if (_chatLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages yet.'),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _chatBubble(context, _messages[index]);
      },
    );
  }

  Widget _chatHeader() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: scheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Members Listening Room',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter): () {
              _sendMessage();
            },
            const SingleActivator(
              LogicalKeyboardKey.enter,
              shift: true,
            ): () {
              final controller = _messageController;
              final text = controller.text;
              final selection = controller.selection;

              final start = selection.start < 0 ? text.length : selection.start;
              final end = selection.end < 0 ? text.length : selection.end;

              final newText = text.replaceRange(start, end, '\n');
              final offset = start + 1;

              controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: offset),
              );
            },
          },
          child: Focus(
            autofocus: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Send a message...',
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _sending ? null : _sendMessage,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout() {
    return Column(
      children: [
        _radioPanel(compact: true),
        _chatHeader(),
        Expanded(
          child: _chatBody(),
        ),
        _chatInput(),
      ],
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: _radioPanel(compact: false),
        ),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              const SizedBox(height: 4),
              _chatHeader(),
              Expanded(
                child: _chatBody(),
              ),
              _chatInput(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return _lockedView(context);
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gensokyo Radio'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadRadioStatus,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Open Player',
            onPressed: _openRadioExternal,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: isDesktop ? _desktopLayout() : _mobileLayout(),
    );
  }
}