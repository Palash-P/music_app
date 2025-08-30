// lib/models/songs.dart
class Song {
  final String? id;
  final String title;
  final String artist;
  double? duration; 
  final String audioPath;

  Song({
    this.id,
    required this.title,
    required this.artist,
    this.duration,
    required this.audioPath,
  });

  // From JSON (API response)
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      duration: (json['duration'] as num).toDouble(),
      audioPath: '',
    );
  }
}
