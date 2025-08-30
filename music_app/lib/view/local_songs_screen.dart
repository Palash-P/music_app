import 'package:flutter/material.dart';
import 'package:music_app/view/player_screen.dart';
import 'package:music_app/models/songs.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalSongsScreen extends StatefulWidget {
  const LocalSongsScreen({super.key});

  @override
  State<LocalSongsScreen> createState() => _LocalSongsScreenState();
}

class _LocalSongsScreenState extends State<LocalSongsScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> songs = [];
  List<SongModel> filteredSongs = [];
  List<String> favouriteIds = [];
  bool loading = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    requestPermissionsAndFetchSongs();
    _loadFavourites();

    // Listen to search changes
    _searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFavourites() async {
    final favs = await FavouritesController.getFavourites();
    setState(() {
      favouriteIds = favs;
    });
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        filteredSongs = List.from(songs);
      } else {
        filteredSongs = songs.where((song) {
          final title = song.title.toLowerCase();
          final artist = (song.artist ?? "Unknown").toLowerCase();
          final album = (song.album ?? "Unknown").toLowerCase();
          final filename = song.displayNameWOExt.toLowerCase();

          return title.contains(query) ||
              artist.contains(query) ||
              album.contains(query) ||
              filename.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _toggleFavourite(SongModel song) async {
    final songId = song.id.toString();
    final isFav = favouriteIds.contains(songId);

    if (isFav) {
      await FavouritesController.removeFavourite(songId);
      setState(() {
        favouriteIds.remove(songId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from favourites"),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      await FavouritesController.addFavourite(songId);
      setState(() {
        favouriteIds.add(songId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Added to favourites"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> requestPermissionsAndFetchSongs() async {
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

    await fetchSongs();
  }

  Future<void> fetchSongs() async {
    try {
      final result = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      // Filter only .mp3 files
      final musicOnly = result.where((song) {
        final path = song.data.toLowerCase();
        return path.endsWith('.mp3');
      }).toList();

      setState(() {
        songs = musicOnly;
        filteredSongs = List.from(musicOnly);
        loading = false;
      });

      print("Found ${songs.length} mp3 songs");
    } catch (e) {
      print("Error fetching songs: $e");
      setState(() => loading = false);
    }
  }

  /// Extract artist name from filename patterns
  String _extractArtistFromFilename(String filename) {
    try {
      String cleanName = filename;

      // Remove file extension if present (though displayNameWOExt should already do this)
      cleanName = cleanName.replaceAll(
        RegExp(r'\.(mp3|m4a|flac|wav)$', caseSensitive: false),
        '',
      );

      // Pattern 1: "Artist - Song Title"
      if (cleanName.contains(' - ')) {
        List<String> parts = cleanName.split(' - ');
        if (parts.length >= 2) {
          String possibleArtist = parts[0].trim();

          // Validate: not empty, not just numbers, reasonable length
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
        // Recursively call with cleaned filename
        return _extractArtistFromFilename(withoutTrackNumber);
      }

      return "Unknown";
    } catch (e) {
      print("Error extracting artist from filename: $e");
      return "Unknown";
    }
  }

  /// Extract song title from filename patterns
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

          // Validate artist part before returning title
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
            // Join remaining parts as title
            return parts.sublist(1).join(' ').trim();
          }
        }
      }

      // Pattern 4: Handle track numbers like "01. Artist - Song"
      RegExp trackNumberPattern = RegExp(r'^\d+\.?\s*(.+)');
      Match? trackMatch = trackNumberPattern.firstMatch(cleanName);
      if (trackMatch != null) {
        String withoutTrackNumber = trackMatch.group(1)!.trim();
        // Recursively call with cleaned filename
        return _extractTitleFromFilename(withoutTrackNumber);
      }

      // Fallback: return original filename as title
      return cleanName;
    } catch (e) {
      print("Error extracting title from filename: $e");
      return filename; // Return original as fallback
    }
  }

  void openPlayer(SongModel song) {
    String artist = song.artist ?? "Unknown";
    String title = song.title;

    // Debug: Print original values
    print("=== Original Song Data ===");
    print("Original title: '$title'");
    print("Original artist: '$artist'");
    print("Filename (displayNameWOExt): '${song.displayNameWOExt}'");

    // If artist is unknown OR the title contains artist info, try to extract from filename
    if (artist == "Unknown" ||
        artist.isEmpty ||
        artist == "<unknown>" ||
        title.contains(' - ')) {
      String extractedArtist = _extractArtistFromFilename(
        song.displayNameWOExt,
      );
      String extractedTitle = _extractTitleFromFilename(song.displayNameWOExt);

      print("=== Extraction Results ===");
      print("Extracted artist: '$extractedArtist'");
      print("Extracted title: '$extractedTitle'");

      if (extractedArtist != "Unknown" && extractedArtist.isNotEmpty) {
        artist = extractedArtist;
        title = extractedTitle;

        print("✅ Successfully extracted - Artist: '$artist', Title: '$title'");
      } else {
        print("❌ Could not extract artist from filename");
      }
    }

    final songObj = Song(
      title: title, // Should be "Believer"
      artist: artist, // Should be "Imagine Dragons"
      // image:
      //     "https://upload.wikimedia.org/wikipedia/en/5/5c/Imagine-Dragons-Believer-art.jpg",
      audioPath: song.uri!,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewPlayerScreen(
          song: songObj,
          songList: songs.map((s) {
            String mappedArtist = s.artist ?? "Unknown";
            String mappedTitle = s.title;

            // Apply same extraction logic to all songs
            if (mappedArtist == "Unknown" ||
                mappedArtist.isEmpty ||
                mappedArtist == "<unknown>" ||
                mappedTitle.contains(' - ')) {
              String extractedArtist = _extractArtistFromFilename(
                s.displayNameWOExt,
              );
              String extractedTitle = _extractTitleFromFilename(
                s.displayNameWOExt,
              );

              if (extractedArtist != "Unknown" && extractedArtist.isNotEmpty) {
                mappedArtist = extractedArtist;
                mappedTitle = extractedTitle;
              }
            }

            return Song(
              title: mappedTitle,
              artist: mappedArtist,
              // image: "",
              audioPath: s.uri!,
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Local Songs"),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: "Search songs, artists, albums...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
          ? const Center(child: Text("No songs found on this device."))
          : Column(
              children: [
                // Results count
                if (_searchController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    width: double.infinity,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.grey.shade50,
                    child: Text(
                      "${filteredSongs.length} song${filteredSongs.length != 1 ? 's' : ''} found",
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                        fontSize: 14,
                      ),
                    ),
                  ),

                // Songs list
                Expanded(
                  child:
                      filteredSongs.isEmpty && _searchController.text.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No songs found",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Try searching with different keywords",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredSongs.length,
                          itemBuilder: (context, index) {
                            final song = filteredSongs[index];
                            final duration = song.duration ?? 0;
                            final minutes = duration ~/ 1000 ~/ 60;
                            final seconds = (duration ~/ 1000) % 60;
                            final songId = song.id.toString();
                            final isFavourite = favouriteIds.contains(songId);

                            // Extract artist and title for display
                            String displayArtist = song.artist ?? "Unknown";
                            String displayTitle = song.title;

                            if (displayArtist == "Unknown" ||
                                displayArtist.isEmpty ||
                                displayArtist == "<unknown>") {
                              displayArtist = _extractArtistFromFilename(
                                song.displayNameWOExt,
                              );
                              if (displayArtist != "Unknown") {
                                displayTitle = _extractTitleFromFilename(
                                  song.displayNameWOExt,
                                );
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              elevation: 0,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey.shade900.withOpacity(0.5)
                                  : Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(
                                      0xFFE69A15,
                                    ).withOpacity(0.2),
                                  ),
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Color(0xFFE69A15),
                                  ),
                                ),
                                title: Text(
                                  displayTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayArtist,
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (song.album != null &&
                                        song.album!.isNotEmpty)
                                      Text(
                                        song.album!,
                                        style: TextStyle(
                                          color: theme
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        isFavourite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFavourite
                                            ? Colors.red
                                            : theme.iconTheme.color,
                                      ),
                                      onPressed: () => _toggleFavourite(song),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => openPlayer(song),
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

// Favourites Controller (add this if you haven't already)
class FavouritesController {
  static const String favKey = "favourite_songs";

  // Save a favourite song
  static Future<void> addFavourite(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList(favKey) ?? [];
    if (!favs.contains(songId)) {
      favs.add(songId);
      await prefs.setStringList(favKey, favs);
    }
  }

  // Remove a favourite song
  static Future<void> removeFavourite(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList(favKey) ?? [];
    favs.remove(songId);
    await prefs.setStringList(favKey, favs);
  }

  // Load all favourite IDs
  static Future<List<String>> getFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(favKey) ?? [];
  }

  // Check if a song is favourite
  static Future<bool> isFavourite(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(favKey) ?? [];
    return favs.contains(songId);
  }
}
