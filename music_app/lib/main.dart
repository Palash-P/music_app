import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/view/bottom_nav.dart';
import 'package:music_app/controller/player_controller.dart';
import 'package:music_app/controller/theme_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme before running the app
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString("theme") ?? "light";
  final initialTheme =
      savedTheme == "dark" ? ThemeMode.dark : ThemeMode.light;

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeBloc(initialTheme)), // pass initial theme
        BlocProvider(create: (context) => PlayerBloc()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.orange,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.orange,
            scaffoldBackgroundColor: const Color(0xFF191919),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF191919),
              foregroundColor: Colors.white,
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white),
            ),
          ),
          home: HomeScreen(),
        );
      },
    );
  }
}
