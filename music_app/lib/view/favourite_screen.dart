import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_app/view/player_screen.dart';
import 'package:music_app/controller/favourite_controller.dart';
import 'package:music_app/models/songs.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<Song> favouriteSongs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFavourites();
  }

  Future<void> loadFavourites() async {
    try {
      // Get favorite song IDs
      final favIds = await FavouritesController.getFavourites();

      if (favIds.isEmpty) {
        setState(() {
          favouriteSongs = [];
          loading = false;
        });
        return;
      }

      // Check permissions
      bool permissionGranted = false;
      if (await Permission.storage.isGranted ||
          await Permission.audio.isGranted) {
        permissionGranted = true;
      } else {
        if (await Permission.audio.request().isGranted ||
            await Permission.storage.request().isGranted) {
          permissionGranted = true;
        }
      }

      if (!permissionGranted) {
        setState(() => loading = false);
        return;
      }

      // Query all songs from device
      final allLocalSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter only .mp3 files and match with favorites
      final musicOnly = allLocalSongs.where((song) {
        final path = song.data.toLowerCase();
        return path.endsWith('.mp3');
      }).toList();

      // Convert favorite SongModels to Song objects
      List<Song> favSongs = [];
      for (final songModel in musicOnly) {
        if (favIds.contains(songModel.id.toString())) {
          String artist = songModel.artist ?? "Unknown";
          String title = songModel.title;

          // Apply same extraction logic as in LocalSongsScreen
          if (artist == "Unknown" ||
              artist.isEmpty ||
              artist == "<unknown>" ||
              title.contains(' - ')) {
            String extractedArtist = _extractArtistFromFilename(
              songModel.displayNameWOExt,
            );
            String extractedTitle = _extractTitleFromFilename(
              songModel.displayNameWOExt,
            );

            if (extractedArtist != "Unknown" && extractedArtist.isNotEmpty) {
              artist = extractedArtist;
              title = extractedTitle;
            }
          }

          favSongs.add(
            Song(
              id: songModel.id.toString(),
              title: title,
              artist: artist,
              audioPath: songModel.uri!,
            ),
          );
        }
      }

      setState(() {
        favouriteSongs = favSongs;
        loading = false;
      });
    } catch (e) {
      print("Error loading favourites: $e");
      setState(() => loading = false);
    }
  }

  /// Extract artist name from filename patterns (same as LocalSongsScreen)
  String _extractArtistFromFilename(String filename) {
    try {
      String cleanName = filename;

      // Remove file extension if present
      cleanName = cleanName.replaceAll(
        RegExp(r'\.(mp3|m4a|flac|wav)$', caseSensitive: false),
        '',
      );

      // Pattern 1: "Artist - Song Title"
      if (cleanName.contains(' - ')) {
        List<String> parts = cleanName.split(' - ');
        if (parts.length >= 2) {
          String possibleArtist = parts[0].trim();

          if (possibleArtist.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(possibleArtist) &&
              possibleArtist.length > 1) {
            return possibleArtist;
          }
        }
      }

      // Pattern 2: "Song Title (Artist)" or "Song Title [Artist]"
      RegExp artistInBrackets = RegExp(r'\(([^)]+)\)$|\[([^\]]+)\]$');
      Match? match = artistInBrackets.firstMatch(cleanName);
      if (match != null) {
        String possibleArtist = (match.group(1) ?? match.group(2) ?? '').trim();
        if (possibleArtist.isNotEmpty && possibleArtist.length > 1) {
          return possibleArtist;
        }
      }

      // Pattern 3: "Artist_Song_Title" (underscore separated)
      if (cleanName.contains('_')) {
        List<String> parts = cleanName.split('_');
        if (parts.length >= 2) {
          String possibleArtist = parts[0].trim();
          if (possibleArtist.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(possibleArtist) &&
              possibleArtist.length > 1) {
            return possibleArtist;
          }
        }
      }

      // Pattern 4: Handle track numbers like "01. Artist - Song"
      RegExp trackNumberPattern = RegExp(r'^\d+\.?\s*(.+)');
      Match? trackMatch = trackNumberPattern.firstMatch(cleanName);
      if (trackMatch != null) {
        String withoutTrackNumber = trackMatch.group(1)!.trim();
        return _extractArtistFromFilename(withoutTrackNumber);
      }

      return "Unknown";
    } catch (e) {
      print("Error extracting artist from filename: $e");
      return "Unknown";
    }
  }

  /// Extract song title from filename patterns (same as LocalSongsScreen)
  String _extractTitleFromFilename(String filename) {
    try {
      String cleanName = filename;

      // Remove file extension if present
      cleanName = cleanName.replaceAll(
        RegExp(r'\.(mp3|m4a|flac|wav)$', caseSensitive: false),
        '',
      );

      // Pattern 1: "Artist - Song Title"
      if (cleanName.contains(' - ')) {
        List<String> parts = cleanName.split(' - ');
        if (parts.length >= 2) {
          String possibleArtist = parts[0].trim();
          String possibleTitle = parts[1].trim();

          if (possibleArtist.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(possibleArtist) &&
              possibleArtist.length > 1 &&
              possibleTitle.isNotEmpty) {
            return possibleTitle;
          }
        }
      }

      // Pattern 2: "Song Title (Artist)" or "Song Title [Artist]"
      RegExp artistInBrackets = RegExp(r'^(.+?)\s*[\(\[]([^\)\]]+)[\)\]]$');
      Match? match = artistInBrackets.firstMatch(cleanName);
      if (match != null) {
        String possibleTitle = match.group(1)!.trim();
        String possibleArtist = match.group(2)!.trim();

        if (possibleTitle.isNotEmpty && possibleArtist.isNotEmpty) {
          return possibleTitle;
        }
      }

      // Pattern 3: "Artist_Song_Title" (underscore separated)
      if (cleanName.contains('_')) {
        List<String> parts = cleanName.split('_');
        if (parts.length >= 2) {
          String possibleArtist = parts[0].trim();
          if (possibleArtist.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(possibleArtist) &&
              possibleArtist.length > 1) {
            return parts.sublist(1).join(' ').trim();
          }
        }
      }

      // Pattern 4: Handle track numbers like "01. Artist - Song"
      RegExp trackNumberPattern = RegExp(r'^\d+\.?\s*(.+)');
      Match? trackMatch = trackNumberPattern.firstMatch(cleanName);
      if (trackMatch != null) {
        String withoutTrackNumber = trackMatch.group(1)!.trim();
        return _extractTitleFromFilename(withoutTrackNumber);
      }

      return cleanName;
    } catch (e) {
      print("Error extracting title from filename: $e");
      return filename;
    }
  }

  Future<void> _removeFavourite(Song song) async {
    await FavouritesController.removeFavourite(song.id!);
    await loadFavourites(); // Reload the list

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from favourites"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          "Favorites",
          style: GoogleFonts.inter(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : favouriteSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No favorites yet",
                    style: GoogleFonts.inter(
                      color: theme.hintColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add songs to favorites from the local songs screen",
                    style: GoogleFonts.inter(
                      color: theme.hintColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header with count
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  child: Text(
                    "${favouriteSongs.length} favorite song${favouriteSongs.length != 1 ? 's' : ''}",
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.7,
                      ),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Songs list
                Expanded(
                  child: ListView.builder(
                    itemCount: favouriteSongs.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final song = favouriteSongs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        elevation: 0,
                        color: isDark
                            ? Colors.grey.shade900.withOpacity(0.5)
                            : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE69A15).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                   const Icon(
                                      Icons.music_note,
                                      color: Color(0xFFE69A15),
                                    ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song.artist,
                            style: GoogleFonts.inter(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Remove from favorites button
                              IconButton(
                                icon: const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeFavourite(song),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Play button
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFE69A15),
                                      Color(0xFFFFA738),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.play_arrow,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                  onPressed: () {
                                    // Use the correct player screen navigation
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NewPlayerScreen(
                                          song: song,
                                          songList: favouriteSongs,
                                        ),
                                      ),
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewPlayerScreen(
                                  song: song,
                                  songList: favouriteSongs,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
