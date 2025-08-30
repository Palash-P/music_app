import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/controller/theme_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: GoogleFonts.inter(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          shadowColor: Colors.black54,
          color: isDark ? const Color(0xFF292929) : Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // 🌞 / 🌙 Icon
                BlocBuilder<ThemeBloc, ThemeState>(
                  builder: (context, state) {
                    return Icon(
                      state.themeMode == ThemeMode.dark
                          ? Icons.nights_stay
                          : Icons.wb_sunny,
                      color: state.themeMode == ThemeMode.dark
                          ? Colors.yellow[600]
                          : Colors.orangeAccent,
                      size: 30,
                    );
                  },
                ),
                const SizedBox(width: 16),

                // Title
                Expanded(
                  child: Text(
                    "Dark Mode",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),

                // Switch
                BlocBuilder<ThemeBloc, ThemeState>(
                  builder: (context, state) {
                    return Transform.scale(
                      scale: 1.3,
                      child: Switch(
                        value: state.themeMode == ThemeMode.dark,
                        onChanged: (_) {
                          context.read<ThemeBloc>().add(ToggleThemeEvent());
                        },
                        activeColor: Colors.greenAccent,
                        inactiveThumbColor: Colors.grey.shade200,
                        inactiveTrackColor:
                            isDark ? Colors.grey[700] : Colors.grey[400],
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
  }
}
