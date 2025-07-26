// lib/widgets/main_scaffold.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/ui/screens/create_info_page.dart';

import '../core/providers/auth_providers.dart';
import 'custom_app_bar.dart';
import 'custom_end_drawer.dart';
import 'custom_bottom_nav_bar.dart';
import '../ui/screens/new_member_page.dart';
import '../ui/screens/new_event_page.dart';
import '../ui/screens/home_tab.dart';
import '../ui/screens/team_tab.dart';
import '../ui/screens/events_tab.dart';
import '../ui/screens/messages_tab.dart';
import '../ui/screens/stats_tab.dart';
import 'tools/tactics_board/tactics_board_page.dart';
import 'tools/tactics_video_player/tactics_video_player_page.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 2;
  final List<int> _history = [2];
  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  static final _pageBuilders = <Widget Function()>[
    TeamTab.new,
    EventsTab.new,
    HomeTab.new,
    () => const MessagesTab(),
    StatsTab.new,
  ];

  Future<bool> _onWillPop() async {
    final navState = _navigatorKeys[_currentIndex].currentState;
    if (navState != null && navState.canPop()) {
      navState.pop();
      return false;
    }
    if (_history.length > 1) {
      _history.removeLast();
      setState(() => _currentIndex = _history.last);
      return false;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Avsluta appen?'),
            content: const Text('Är du säker att du vill avsluta appen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Avbryt'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ja'),
              ),
            ],
          ),
    );
    if (exit == true) SystemNavigator.pop();
    return false;
  }

  void _onTapBottomNav(int idx) {
    if (idx == _currentIndex) {
      // Om du redan är i samma flik: poppa till första sidan
      _navigatorKeys[idx].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    // 1) Töm idx-flikens stack
    _navigatorKeys[idx].currentState?.popUntil((r) => r.isFirst);

    // 2) Byt flik
    setState(() {
      _history.remove(idx);
      _history.add(idx);
      _currentIndex = idx;
    });
  }

  // En “allmän” funktion som drawer kan kalla för att byta flik
  void _selectTab(int tabIndex) {
    if (tabIndex == _currentIndex) {
      // Om användaren trycker på samma knapp igen, poppa stacken till root
      _navigatorKeys[tabIndex].currentState?.popUntil((r) => r.isFirst);
    } else {
      // 1) Poppa den nya flikens Navigator till första sidan (root)
      _navigatorKeys[tabIndex].currentState?.popUntil((r) => r.isFirst);

      // 2) Uppdatera index och historik
      setState(() {
        _history.remove(tabIndex);
        _history.add(tabIndex);
        _currentIndex = tabIndex;
      });
    }
  }

  // Om du vill push:a en sida inuti nuvarande flik:
  void _pushInCurrentTab(Widget page) {
    _navigatorKeys[_currentIndex].currentState?.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final navState = _navigatorKeys[_currentIndex].currentState;

    // Om vi kan poppa i inner‐navigatorn så är vi på en sub‐sida (t.ex. ViewMessagePage)
    final onRootPage = !(navState?.canPop() ?? false);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: CustomAppBar(),
        endDrawer: SizedBox(
          width: MediaQuery.of(context).size.width,
          // Skicka in callbacks till CustomEndDrawer:
          child: CustomEndDrawer(
            currentIndex: _currentIndex,
            selectTab: _selectTab,
            pushInTab: _pushInCurrentTab,
          ),
        ),
        // Själva “kroppen” med en IndexedStack av navigators:
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            _pageBuilders.length,
            (i) => Navigator(
              key: _navigatorKeys[i],
              onGenerateRoute:
                  (_) => MaterialPageRoute(builder: (_) => _pageBuilders[i]()),
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTapPage: _onTapBottomNav,
        ),
        floatingActionButton:
            session.isAdmin
                ? SpeedDial(
                  icon: Icons.add,
                  activeIcon: Icons.close,
                  children: [
                    SpeedDialChild(
                      child: const Icon(Icons.message),
                      label: 'Videotaktiken',
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => TacticsVideoPlayerPage(),
                          ),
                        );
                      },
                    ),

                    SpeedDialChild(
                      child: const Icon(Icons.message),
                      label: 'Taktiktavlan',
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => TacticsBoardPage(),
                          ),
                        );
                      },
                    ),

                    SpeedDialChild(
                      child: const Icon(Icons.message),
                      label: 'Nytt meddelande',
                      onTap: () {
                        _navigatorKeys[_currentIndex].currentState?.push(
                          MaterialPageRoute(
                            builder: (_) => const CreateInfoPage(),
                          ),
                        );
                      },
                    ),

                    SpeedDialChild(
                      child: const Icon(Icons.event),
                      label: 'Ny händelse',
                      onTap: () {
                        _navigatorKeys[_currentIndex].currentState?.push(
                          MaterialPageRoute(
                            builder: (_) => const NewEventPage(),
                          ),
                        );
                      },
                    ),

                    SpeedDialChild(
                      child: const Icon(Icons.person_add),
                      label: 'Ny medlem',
                      onTap: () {
                        _navigatorKeys[_currentIndex].currentState?.push(
                          MaterialPageRoute(
                            builder: (_) => const NewMemberPage(),
                          ),
                        );
                      },
                    ),
                  ],
                )
                : null,
      ),
    );
  }
}
