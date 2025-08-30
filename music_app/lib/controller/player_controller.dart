import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:music_app/models/songs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------- Events ----------------------
abstract class PlayerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SetSongEvent extends PlayerEvent {
  final Song song;
  SetSongEvent(this.song);

  @override
  List<Object?> get props => [song];
}

class UpdateProgressEvent extends PlayerEvent {
  final double progress;
  UpdateProgressEvent({required this.progress});

  @override
  List<Object?> get props => [progress];
}

class TogglePlayPauseEvent extends PlayerEvent {}

// ---------------------- States ----------------------
abstract class PlayerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PlayerInitial extends PlayerState {}

class PlayerLoading extends PlayerState {
  final Song song;
  PlayerLoading({required this.song});

  @override
  List<Object?> get props => [song];
}

class PlayerPlaying extends PlayerState {
  final Song song;
  final double progress;
  final String lyrics;

  PlayerPlaying({required this.song, required this.progress, this.lyrics = ""});

  @override
  List<Object?> get props => [song, progress, lyrics];

  PlayerPlaying copyWith({double? progress, String? lyrics}) {
    return PlayerPlaying(
      song: song,
      progress: progress ?? this.progress,
      lyrics: lyrics ?? this.lyrics,
    );
  }

  PlayerPaused toPaused() =>
      PlayerPaused(song: song, progress: progress, lyrics: lyrics);
}

class PlayerPaused extends PlayerState {
  final Song song;
  final double progress;
  final String lyrics;

  PlayerPaused({required this.song, required this.progress, this.lyrics = ""});

  @override
  List<Object?> get props => [song, progress, lyrics];

  PlayerPlaying toPlaying() =>
      PlayerPlaying(song: song, progress: progress, lyrics: lyrics);

  PlayerPaused copyWith({double? progress, String? lyrics}) {
    return PlayerPaused(
      song: song,
      progress: progress ?? this.progress,
      lyrics: lyrics ?? this.lyrics,
    );
  }
}

class PlayerError extends PlayerState {
  final String message;
  PlayerError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ---------------------- BLoC ----------------------
class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final Map<String, String> _lyricsCache = {}; // In-memory cache

  PlayerBloc() : super(PlayerInitial()) {
    // Handle set song
    on<SetSongEvent>((event, emit) async {
      final song = event.song;
      final cacheKey =
          "${song.artist.toLowerCase()}_${song.title.toLowerCase()}";

      // If lyrics already cached in memory, skip loading
      if (_lyricsCache.containsKey(cacheKey)) {
        emit(
          PlayerPlaying(
            song: song,
            progress: 0,
            lyrics: _lyricsCache[cacheKey]!,
          ),
        );
        return;
      }

      emit(PlayerLoading(song: song));

      try {
        final lyrics = await _getLyrics(song.title, song.artist);
        emit(PlayerPlaying(song: song, progress: 0, lyrics: lyrics));
      } catch (e) {
        emit(PlayerError(message: "Failed to load lyrics: $e"));
        emit(
          PlayerPlaying(song: song, progress: 0, lyrics: "Lyrics not found"),
        );
      }
    });

    // Handle progress updates
    on<UpdateProgressEvent>((event, emit) {
      final currentState = state;
      if (currentState is PlayerPlaying) {
        emit(currentState.copyWith(progress: event.progress));
      } else if (currentState is PlayerPaused) {
        emit(currentState.copyWith(progress: event.progress));
      }
    });

    // Handle play/pause toggle
    on<TogglePlayPauseEvent>((event, emit) {
      final currentState = state;
      if (currentState is PlayerPlaying) {
        emit(currentState.toPaused());
      } else if (currentState is PlayerPaused) {
        emit(currentState.toPlaying());
      }
    });
  }

  ///Get lyrics from memory, storage, or API
  Future<String> _getLyrics(String title, String artist) async {
    final key = "${artist.toLowerCase()}_${title.toLowerCase()}";

    // 1️⃣ Check in-memory cache
    if (_lyricsCache.containsKey(key)) return _lyricsCache[key]!;

    // 2️⃣ Check persistent storage
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key)) {
      final lyrics = prefs.getString(key)!;
      _lyricsCache[key] = lyrics; // Save in memory
      return lyrics;
    }

    // 3️⃣ Fetch from API
    final lyrics = await fetchLyrics(title, artist);

    // Only cache valid lyrics, not error messages
    if (lyrics != "Request timed out. Please check your internet." &&
        lyrics != "Lyrics not found") {
      _lyricsCache[key] = lyrics;
      await prefs.setString(key, lyrics);
    }

    return lyrics;
  }

  /// Fetch lyrics from lyrics.ovh API
  Future<String> fetchLyrics(String title, String artist) async {
    try {
      final queryArtist = artist.isEmpty ? "Unknown" : artist;
      final url = Uri.parse(
        "https://api.lyrics.ovh/v1/${Uri.encodeComponent(queryArtist)}/${Uri.encodeComponent(title)}",
      );
      print("Fetching lyrics: $url");

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['lyrics']?.toString().trim() ?? "No lyrics found.";
      } else if (response.statusCode == 404) {
        return "Lyrics not available for this song.";
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } on TimeoutException {
      return "Request timed out. Please check your internet.";
    } catch (e) {
      print("Lyrics fetch error: $e");
      return "Lyrics not found";
    }
  }
}
