// lib/core/widgets/custom_end_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:teamzone_app/auth/login_page.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/ui/screens/player_profile_page.dart';
import 'package:teamzone_app/ui/screens/settings_page.dart';
import '../ui/screens/home_tab.dart';
import '../ui/screens/team_tab.dart';
import '../ui/screens/events_tab.dart';
import '../ui/screens/messages_tab.dart';
import '../ui/screens/stats_tab.dart';
import '../ui/screens/create_new_team.dart';
import 'package:teamzone_app/core/providers/team_providers.dart';
import 'package:teamzone_app/domain/models/team.dart';
import 'package:teamzone_app/core/providers/user_session.dart';

class CustomEndDrawer extends ConsumerWidget {
  final int currentIndex;
  final void Function(int tabIndex) selectTab;
  final void Function(Widget page) pushInTab;

  const CustomEndDrawer({
    Key? key,
    required this.currentIndex,
    required this.selectTab,
    required this.pushInTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(firestoreProvider);

    // Funktionen anropar Firestore & Auth och använder 'ref'
    Future<void> signOut() async {
      final token = await FirebaseMessaging.instance.getToken();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && currentUid != null) {
        try {
          await db.collection('users').doc(currentUid).update({
            'fcmToken': FieldValue.delete(),
          });
        } catch (e, st) {
          debugPrint('Misslyckades ta bort fcmToken: $e\n$st');
        }
      }
      await FirebaseAuth.instance.signOut();
    }

    // Läs auth och session via Riverpod
    final auth = ref.read(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final userName = session.userName;
    final userRole = session.userRole;
    final userPhotoUrl = session.userPhotoUrl;

    // Hämta lag‐lista och valt lag‐id
    final teamsAsync = ref.watch(userTeamsProvider);
    final currentTeamId = ref.watch(currentTeamProvider);

    print('teamRoles map: ${session.teamRoles}');
    print(
      'currentTeamId: $currentTeamId, roles: ${session.teamRoles[currentTeamId]}',
    );

    return teamsAsync.when(
      loading:
          () => const Drawer(child: Center(child: CircularProgressIndicator())),
      error:
          (e, _) =>
              Drawer(child: Center(child: Text('Kunde inte ladda lag: $e'))),
      data: (teams) {
        // Hitta det aktiva Team‐objektet
        final activeTeam = teams.firstWhere(
          (t) => t.id == currentTeamId,
          orElse: () => teams.first,
        );
        // Här plockar vi ut rätt roll‐lista från session.teamRoles
        // (lägg in teamRoles i din session‐modell som Map<String,List<String>>)
        final rolesMap = session.teamRoles;
        final roleList = rolesMap[currentTeamId] ?? [];
        final roleStr = roleList.isNotEmpty ? roleList.first : '';

        // Definiera strängar för klubb- och lagnamn
        final clubName = activeTeam.clubName;
        final teamName = activeTeam.teamName;

        return Drawer(
          child: SafeArea(
            child: Stack(
              children: [
                // 1) Gradient‐bakgrund
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        stops: [0, 1],
                        radius: 1.5,
                        center: const Alignment(-0.7, -0.7),
                        // begin: Alignment.bottomRight,
                        // end: Alignment.topLeft,
                        colors: [
                          Colors.grey.shade700,
                          const Color.fromARGB(255, 18, 18, 18),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2) Profilbild som semi‐transparent bakgrund
                if (userPhotoUrl.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1, // Justera för önskad synlighet
                      child: Image.network(userPhotoUrl, fit: BoxFit.cover),
                    ),
                  ),

                // 3) Mörk overlay för kontrast
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),

                // 5) Meny‐innehållet överst
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Profilsektion ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 60.0,
                        left: 16,
                        right: 16,
                      ),
                      child: SizedBox(
                        height:
                            100, // ge tillräcklig höjd för både avatar och knapp
                        child: Stack(
                          children: [
                            // 1) Själva raden med avatar + text
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey.shade800,
                                  backgroundImage:
                                      userPhotoUrl.isNotEmpty
                                          ? NetworkImage(userPhotoUrl)
                                          : null,
                                  child:
                                      userPhotoUrl.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            size: 45,
                                            color: Colors.white54,
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName.isNotEmpty
                                            ? userName
                                            : 'Användare',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.cyan[200],
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 2,
                                              color: Colors.black38,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        clubName.isNotEmpty
                                            ? clubName
                                            : 'Ingen klubb',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white70,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 2,
                                              color: Colors.black38,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        roleStr.isNotEmpty
                                            ? '$teamName • $roleStr'
                                            : teamName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white70,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 2,
                                              color: Colors.black38,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── Inställningar & Logga ut ─────────────────────────────
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Inställningar
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsPage(),
                                  ),
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      color: Colors.transparent,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.settings,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Inställningar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Logga ut
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(50),
                              onTap: () async {
                                debugPrint('✋ Logga ut-tapp registrerad');

                                try {
                                  // 1. Logga ut och rensa token
                                  await signOut();
                                  debugPrint('✅ signOut körd utan undantag');

                                  // 2. Stäng menyn
                                  Navigator.pop(context);

                                  // 3. Navigera till login och rensa historiken
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginPage(),
                                    ),
                                    (route) => false,
                                  );
                                } catch (e, st) {
                                  debugPrint('❌ signOut kastade fel: $e\n$st');
                                  // Visa gärna en snackBar om du vill meddela användaren
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Kunde inte logga ut: $e'),
                                    ),
                                  );
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.logout,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Logga ut',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Byt lag
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.grey.shade900,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  builder: (_) {
                                    return teamsAsync.when(
                                      loading:
                                          () => const Padding(
                                            padding: EdgeInsets.all(24.0),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      error:
                                          (e, _) => Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Center(
                                              child: Text(
                                                'Kunde inte ladda lag: $e',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      data: (teams) {
                                        return SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Välj lag',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const Divider(
                                                color: Colors.white54,
                                              ),
                                              ...teams.map((team) {
                                                final isActive =
                                                    team.id == currentTeamId;
                                                return ListTile(
                                                  leading:
                                                      isActive
                                                          ? const Icon(
                                                            Icons.check,
                                                            color: Colors.green,
                                                          )
                                                          : const SizedBox(
                                                            width: 24,
                                                          ),
                                                  title: Text(
                                                    team.teamName,
                                                    style: TextStyle(
                                                      color:
                                                          isActive
                                                              ? Colors
                                                                  .greenAccent
                                                              : Colors.white,
                                                      fontWeight:
                                                          isActive
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                    ),
                                                  ),
                                                  onTap: () async {
                                                    final uid =
                                                        ref
                                                            .read(
                                                              authNotifierProvider,
                                                            )
                                                            .currentUser
                                                            ?.uid;
                                                    if (uid != null) {
                                                      // Skriv nya currentTeamId till Firestore så UserSession plockar upp det
                                                      await db
                                                          .collection('users')
                                                          .doc(uid)
                                                          .update({
                                                            'currentTeamId':
                                                                team.id,
                                                          });
                                                    }
                                                    // Uppdatera även den lokala providern (för snabb UI-ändring i drawer)
                                                    ref
                                                        .read(
                                                          currentTeamProvider
                                                              .notifier,
                                                        )
                                                        .state = team.id;
                                                    Navigator.pop(context);
                                                    Navigator.pop(context);
                                                    selectTab(
                                                      2,
                                                    ); // HomeTab har index 2
                                                  },
                                                );
                                              }).toList(),
                                              const SizedBox(height: 8),
                                              const Divider(
                                                color: Colors.white54,
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8.0,
                                                    ),
                                                child: TextButton.icon(
                                                  icon: const Icon(
                                                    Icons.add,
                                                    color: Colors.white,
                                                  ),
                                                  label: const Text(
                                                    'Skapa nytt lag',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    // Stäng modalen först
                                                    Navigator.pop(context);
                                                    // Navigera till din sida för att skapa nytt lag
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (_) =>
                                                                const NewTeamPage(), // Byt ut mot din sida
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      color: Colors.transparent,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.swap_horiz,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Byt lag',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Navigationslänkar ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -2),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(width: 2, color: Colors.white),
                          ),
                          child: const Icon(Icons.home, color: Colors.white),
                        ),
                        title: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Hem',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          selectTab(2); // HomeTab har index 2
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -2),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(width: 2, color: Colors.white),
                          ),
                          child: const Icon(Icons.group, color: Colors.white),
                        ),
                        title: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Team',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          selectTab(0); // TeamTab har index 0
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -2),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(width: 2, color: Colors.white),
                          ),
                          child: const Icon(Icons.event, color: Colors.white),
                        ),
                        title: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Events',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          selectTab(1); // EventsTab har index 1
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -3),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(width: 2, color: Colors.white),
                          ),
                          child: const Icon(Icons.message, color: Colors.white),
                        ),
                        title: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Messages',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          selectTab(3); // MessagesTab har index 3
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -3),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(width: 2, color: Colors.white),
                          ),
                          child: const Icon(
                            Icons.bar_chart,
                            color: Colors.white,
                          ),
                        ),
                        title: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Statistics',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          selectTab(4); // StatsTab har index 4
                        },
                      ),
                    ),

                    const SizedBox(height: 25),
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -2),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(width: 2, color: Colors.white),
                          ),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Min profil',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context); // Stäng drawern
                          // 2) Hämta UID
                          final uid =
                              ref.read(authNotifierProvider).currentUser?.uid;
                          if (uid == null)
                            return; // Om du vill byta till Home-tab (eller behåll currentIndex om det är rätt)
                          pushInTab(
                            // Pusha inuti den aktiva tabben
                            PlayerProfilePage(userId: uid),
                          );
                        },
                      ),
                    ),

                    const Spacer(),

                    // ─── Knapp längst ner för att stänga ─────────────────────────
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      color: Colors.transparent,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: const Icon(
                                      Icons.close,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Stäng',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
