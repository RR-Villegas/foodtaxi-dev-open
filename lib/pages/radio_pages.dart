import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/database_service.dart';
import '../services/web_radio_player.dart';

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
  String? _lastSongId;

  RealtimeChannel? _radioChannel;

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _radioStatus;

  bool _sending = false;
  bool _chatLoading = true;
  bool _radioLoading = true;
  bool _audioLoading = false;
  bool _playing = false;

  double _volume = 0.8;

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
      _startMetadataUpdates();
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

  void _startMetadataUpdates() {
    _metadataTimer?.cancel();

    _metadataTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadRadioStatus(silent: true),
    );
  }

  void _setVolume(double value) {
    setState(() => _volume = value);
    _radioPlayer.setVolume(value);
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

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _volume == 0
                ? Icons.volume_off
                : _volume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
            size: 18,
          ),
          SizedBox(
            width: 90,
            child: Slider(
              value: _volume,
              min: 0,
              max: 1,
              onChanged: _setVolume,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _volume == 0
              ? Icons.volume_off
              : _volume < 0.5
                  ? Icons.volume_down
                  : Icons.volume_up,
        ),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: _volumeControl(compact: true),
                  ),
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

  Widget _chatBubble(BuildContext context, Map<String, dynamic> item) {
    final scheme = Theme.of(context).colorScheme;
    final account = item['account'] as Map<String, dynamic>?;

    final name = [
      account?['firstname'],
      account?['surname'],
    ].whereType<String>().join(' ').trim();

    final avatar = account?['profile_image_url']?.toString();

    return Container(
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
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(
                    avatar.startsWith('http')
                        ? avatar
                        : DatabaseService.getProfileImageUrl(avatar),
                  )
                : null,
            child: avatar == null || avatar.isEmpty
                ? Text(name.isEmpty ? '?' : name[0])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Unknown User' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(item['message']?.toString() ?? ''),
              ],
            ),
          ),
        ],
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
                onSubmitted: (_) => _sendMessage(),
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