import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Events
abstract class ThemeEvent {}

class ToggleThemeEvent extends ThemeEvent {}

// States
class ThemeState {
  final ThemeMode themeMode;
  ThemeState(this.themeMode);
}

// Bloc
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc(ThemeMode initialTheme) : super(ThemeState(initialTheme)) {
    on<ToggleThemeEvent>(_onToggleTheme);
  }

  Future<void> _onToggleTheme(
    ToggleThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    final newTheme = state.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;

    emit(ThemeState(newTheme));

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "theme",
      newTheme == ThemeMode.dark ? "dark" : "light",
    );
  }
}
