import 'package:shared_preferences/shared_preferences.dart';

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
