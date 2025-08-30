# 🎵 Music App

## Overview
`music_app` is a Flutter-based music player featuring:
- Play, pause, and track progress for local songs.
- Fetch and display lyrics from the `lyrics.ovh` API with caching.
- Dark/Light theme toggle with persistent user preference.
- Clean architecture using **BLoC** for state management.
- Smooth, responsive UI with custom app theming.

## Features
- 🎶 **Local Song Playback** – Play songs stored on the device using `on_audio_query` and `just_audio`.
- 📜 **Lyrics Display** – Fetch and cache lyrics for each song.
- ⏱️ **Progress Control** – Update and display playback progress.
- 🌙 **Dark/Light Mode** – Toggle themes and persist across app restarts using `shared_preferences`.
- 🔄 **BLoC Architecture** – Clean separation of UI and business logic with `flutter_bloc`.

## Tech Stack
- **Frontend:** Flutter, Dart
- **State Management:** BLoC (`bloc`, `flutter_bloc`)
- **Audio & Media:** `just_audio`, `on_audio_query`
- **UI & Fonts:** `google_fonts`, `smooth_page_indicator`
- **Local Storage:** `shared_preferences`
- **Permissions:** `permission_handler`
- **Testing & Lints:** `flutter_test`, `flutter_lints`

## Setup & Run

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd music_app
```
2. **Install dependencies**
```
flutter pub get
```
4. **Run the app**
```
flutter run 
```

