import 'package:flutter/material.dart';
import 'package:music_app/view/favourite_screen.dart';
import 'package:music_app/view/local_songs_screen.dart';
import 'package:music_app/view/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const FavoritesScreen(),
      LocalSongsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFE69A15),
        unselectedItemColor: isDark
            ? const Color(0xFF9DB2CE)
            : Colors.grey[600],
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.favorite,
              color: _currentIndex == 0 ? const Color(0xFFE69A15) : null,
            ),
            label: "Favourite",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              color: _currentIndex == 1 ? const Color(0xFFE69A15) : null,
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: _currentIndex == 2 ? const Color(0xFFE69A15) : null,
            ),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
