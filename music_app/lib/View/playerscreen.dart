import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State {
  double currentSlider = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(19, 19, 19, 1),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 551,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/player.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  "Alone in the Abyss",
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: const Color.fromRGBO(230, 154, 21, 1),
                  ),
                ),
                Text(
                  "Youlakou",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color.fromRGBO(255, 255, 255, 1),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset("assets/upload.png"),
                    const SizedBox(
                      width: 20,
                    )
                  ],
                )
              ],
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(
                width: 10,
              ),
              Text(
                "Dynamic Warmup | ",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color.fromRGBO(255, 255, 255, 1),
                ),
              ),
              const Spacer(),
              Text(
                "4 min",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color.fromRGBO(255, 255, 255, 1),
                ),
              ),
              const SizedBox(
                width: 20,
              ),
            ],
          ),
          Slider(
            value: currentSlider,
            max: 100,
            min: 0,
            label: currentSlider.round().toString(),
            inactiveColor: const Color.fromRGBO(217, 217, 217, 0.19),
            activeColor: const Color.fromRGBO(230, 154, 21, 1),
            onChanged: (val) {
              currentSlider = val;
              setState(() {
                currentSlider = val;
              });
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            children: [
              const Spacer(),
              Image.asset("assets/loop.png"),
              const Spacer(),
              Image.asset("assets/previous.png"),
              const Spacer(),
              Image.asset("assets/play.png"),
              const Spacer(),
              Image.asset("assets/next.png"),
              const Spacer(),
              Image.asset("assets/volume.png"),
              const Spacer(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromRGBO(24, 24, 24, 1),
        selectedItemColor: const Color.fromRGBO(230, 154, 21, 1),
        unselectedItemColor: const Color.fromRGBO(157, 178, 206, 1),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Favourite",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Search",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: "Playlist",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
