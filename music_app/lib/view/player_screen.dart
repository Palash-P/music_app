import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_app/controller/player_controller.dart';
import 'package:music_app/models/songs.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;

class NewPlayerScreen extends StatefulWidget {
  final Song song;
  final List<Song> songList;

  const NewPlayerScreen({
    super.key,
    required this.song,
    required this.songList,
  });

  @override
  State<NewPlayerScreen> createState() => _NewPlayerScreenState();
}

enum RepeatMode { none, all, one }

class _NewPlayerScreenState extends State<NewPlayerScreen>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _rotationController;
  late AnimationController _scaleController;

  int currentIndex = 0;
  bool isShuffle = false;
  bool isRepeat = false;
  bool isPlaying = false;
  bool isLoading = false;
  final Random _random = Random();

  late Song currentSong;
  RepeatMode repeatMode = RepeatMode.none;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onTrackComplete();
      }
    });

    currentIndex = widget.songList.indexWhere(
      (s) => s.audioPath == widget.song.audioPath,
    );
    if (currentIndex == -1) currentIndex = 0;

    currentSong = widget.songList[currentIndex];
    _initializePlayer();
  }

  void _onTrackComplete() {
    // Repeat the same song
    if (repeatMode == RepeatMode.one) {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
      return;
    }

    // If we're at the end and repeat is OFF, stop (don't wrap)
    final lastIndex = widget.songList.length - 1;
    if (!isShuffle &&
        repeatMode == RepeatMode.none &&
        currentIndex >= lastIndex) {
      // Let playback stop naturally; no wrap.
      return;
    }

    // Otherwise go to next (wraps or shuffles)
    _playNext();
  }

  Future<void> _initializePlayer() async {
    _audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return; // prevent crash
      setState(() {
        isPlaying = playerState.playing;
        isLoading =
            playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering;
      });

      if (playerState.playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (isRepeat) {
          _playSong(currentSong.audioPath);
        } else {
          _playNext();
        }
      }
    });

    context.read<PlayerBloc>().add(SetSongEvent(currentSong));
    await _playSong(currentSong.audioPath);
  }

  Future<void> _playSong(String path) async {
    setState(() => isLoading = true);

    try {
      Uri uri;
      if (path.startsWith('http') || path.startsWith('content://')) {
        uri = Uri.parse(path);
      } else {
        uri = Uri.file(path);
      }
      await _audioPlayer.setAudioSource(AudioSource.uri(uri));
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error playing: ${currentSong.title}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _playNext() {
    if (widget.songList.isEmpty) return;
    if (isShuffle) {
      int nextIndex;
      do {
        nextIndex = _random.nextInt(widget.songList.length);
      } while (nextIndex == currentIndex && widget.songList.length > 1);
      currentIndex = nextIndex;
    } else {
      currentIndex = (currentIndex + 1) % widget.songList.length;
    }
    setState(() => currentSong = widget.songList[currentIndex]);
    _playSong(currentSong.audioPath);
    context.read<PlayerBloc>().add(SetSongEvent(currentSong));
  }

  void _playPrevious() {
    if (widget.songList.isEmpty) return;
    if (isShuffle) {
      int prevIndex;
      do {
        prevIndex = _random.nextInt(widget.songList.length);
      } while (prevIndex == currentIndex && widget.songList.length > 1);
      currentIndex = prevIndex;
    } else {
      currentIndex =
          (currentIndex - 1 + widget.songList.length) % widget.songList.length;
    }
    setState(() => currentSong = widget.songList[currentIndex]);
    _playSong(currentSong.audioPath);
    context.read<PlayerBloc>().add(SetSongEvent(currentSong));
  }

  void _togglePlayPause() {
    _scaleController.forward().then((_) => _scaleController.reverse());
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
    context.read<PlayerBloc>().add(TogglePlayPauseEvent());
  }

  void _toggleShuffle() => setState(() => isShuffle = !isShuffle);
  void _toggleRepeat() {
    setState(() {
      switch (repeatMode) {
        case RepeatMode.none:
          repeatMode =
              RepeatMode.all; // 🔁 playlist repeat (we handle manually)
          _audioPlayer.setLoopMode(LoopMode.off);
          break;
        case RepeatMode.all:
          repeatMode = RepeatMode.one; // 🔂 repeat current song
          _audioPlayer.setLoopMode(LoopMode.one);
          break;
        case RepeatMode.one:
          repeatMode = RepeatMode.none; // ⏹️ no repeat
          _audioPlayer.setLoopMode(LoopMode.off);
          break;
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Widget _buildAlbumArt(double size, bool isDark) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * pi,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black54 : Colors.grey.shade300,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(child: _buildDefaultAlbumArt(isDark)),
          ),
        );
      },
    );
  }

  Widget _buildQueueSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            "Up Next",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),

          // Song List
          Expanded(
            child: ListView.builder(
              itemCount: widget.songList.length,
              itemBuilder: (context, index) {
                final song = widget.songList[index];
                final isCurrentSong = index == currentIndex;

                return ListTile(
                  leading: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isCurrentSong
                          ? const Color(0xFFE69A15).withOpacity(0.2)
                          : (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200),
                    ),
                    child: Icon(
                      isCurrentSong ? Icons.equalizer : Icons.music_note,
                      color: isCurrentSong
                          ? const Color(0xFFE69A15)
                          : theme.iconTheme.color?.withOpacity(0.6),
                    ),
                  ),
                  title: Text(
                    song.title,
                    style: GoogleFonts.inter(
                      fontWeight: isCurrentSong
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isCurrentSong
                          ? const Color(0xFFE69A15)
                          : theme.textTheme.bodyMedium?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.6,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    setState(() {
                      currentIndex = index;
                      currentSong = widget.songList[currentIndex];
                    });

                    _playSong(currentSong.audioPath);
                    context.read<PlayerBloc>().add(SetSongEvent(currentSong));

                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAlbumArt(bool isDark) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFE69A15), Color(0xFFFFA738)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Icon(
      Icons.music_note,
      size: 80,
      color: isDark ? Colors.white : Colors.white,
    ),
  );

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    double size = 24,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(
        icon,
        color: isActive
            ? (activeColor ?? const Color(0xFFE69A15))
            : theme.iconTheme.color?.withOpacity(0.7),
      ),
      iconSize: size,
      onPressed: onPressed,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final albumSize = math.min(screenWidth * 0.65, screenHeight * 0.35);

        final titleFontSize = screenWidth * 0.055;
        final artistFontSize = screenWidth * 0.04;
        final lyricFontSize = screenWidth * 0.04;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
              onPressed: () {
                _audioPlayer.stop();
                Navigator.pop(context);
              },
            ),
            title: Text(
              "Now Playing",
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: screenWidth * 0.05,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenHeight * 0.02,
                ),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.02),
                    _buildAlbumArt(albumSize, isDark),

                    SizedBox(height: screenHeight * 0.04),

                    // Song Info
                    Text(
                      currentSong.title,
                      style: GoogleFonts.inter(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      currentSong.artist,
                      style: GoogleFonts.inter(
                        fontSize: artistFontSize,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: screenHeight * 0.02),

                    // Progress & Slider
                    StreamBuilder<Duration>(
                      stream: _audioPlayer.positionStream,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? Duration.zero;
                        final dur = _audioPlayer.duration ?? Duration.zero;
                        return Column(
                          children: [
                            Slider(
                              min: 0,
                              max: dur.inMilliseconds.toDouble(),
                              value: pos.inMilliseconds
                                  .clamp(0, dur.inMilliseconds)
                                  .toDouble(),
                              activeColor: const Color(0xFFE69A15),
                              onChanged: (v) => _audioPlayer.seek(
                                Duration(milliseconds: v.toInt()),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(pos),
                                  style: GoogleFonts.inter(
                                    fontSize: screenWidth * 0.03,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                Text(
                                  _formatDuration(dur),
                                  style: GoogleFonts.inter(
                                    fontSize: screenWidth * 0.03,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    SizedBox(height: screenHeight * 0.02),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: Icons.skip_previous_rounded,
                          onPressed: _playPrevious,
                          isActive: false,
                          size: screenWidth * 0.1,
                        ),
                        ScaleTransition(
                          scale: Tween(
                            begin: 1.0,
                            end: 0.95,
                          ).animate(_scaleController),
                          child: Container(
                            width: screenWidth * 0.18,
                            height: screenWidth * 0.18,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFE69A15), Color(0xFFFFA738)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: IconButton(
                              icon: isLoading
                                  ? CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark ? Colors.black : Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      size: screenWidth * 0.1,
                                    ),
                              onPressed: isLoading ? null : _togglePlayPause,
                            ),
                          ),
                        ),
                        _buildControlButton(
                          icon: Icons.skip_next_rounded,
                          onPressed: _playNext,
                          isActive: false,
                          size: screenWidth * 0.1,
                        ),
                      ],
                    ),

                    // Secondary Controls (Shuffle, Queue, Repeat)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _buildControlButton(
                                icon: Icons.shuffle,
                                onPressed: _toggleShuffle,
                                isActive: isShuffle,
                                size:
                                    MediaQuery.of(context).size.width *
                                    0.06, // responsive size
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: _buildControlButton(
                                icon: Icons.queue_music_rounded,
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: isDark
                                        ? Colors.grey.shade900
                                        : Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (context) => _buildQueueSheet(),
                                  );
                                },
                                isActive: false,
                                size: MediaQuery.of(context).size.width * 0.06,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildControlButton(
                                icon: repeatMode == RepeatMode.one
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                                onPressed: _toggleRepeat,
                                isActive: repeatMode != RepeatMode.none,
                                size: MediaQuery.of(context).size.width * 0.06,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.02),

                    // Lyrics
                    BlocBuilder<PlayerBloc, PlayerState>(
                      builder: (context, state) {
                        String lyrics = "Lyrics not available";
                        if (state is PlayerPlaying) lyrics = state.lyrics;
                        if (state is PlayerPaused) lyrics = state.lyrics;

                        final lines = lyrics.split('\n');
                        return Container(
                          height: screenHeight * 0.3,
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            itemCount: lines.length,
                            itemBuilder: (c, i) => Text(
                              lines[i],
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: lyricFontSize,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
