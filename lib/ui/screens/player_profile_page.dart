// lib/features/home/presentation/pages/player_profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import '../../../../domain/models/user.dart';
import '../../../core/providers/user_repository_provider.dart';
import '../../../core/providers/firestore_providers.dart';
import 'edit_profile_page.dart';

class PlayerProfilePage extends ConsumerWidget {
  final String userId;
  const PlayerProfilePage({Key? key, required this.userId}) : super(key: key);

  Future<User> _loadUser(WidgetRef ref) {
    final userRepo = ref.read(userRepositoryProvider);
    return userRepo.getUserById(userId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const headerHeight = 200.0;
    const avatarRadius = 55.0;

    return Scaffold(
      body: FutureBuilder<User>(
        future: _loadUser(ref),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Kunde inte ladda profil: ${snap.error}'),
            );
          }
          final user = snap.data!;
          final me = fbAuth.FirebaseAuth.instance.currentUser;
          final isOwner = me != null && me.uid == user.id;

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // HEADER + AVATAR
                SizedBox(
                  height: headerHeight + avatarRadius,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background
                      SizedBox(
                        height: headerHeight,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.black87),
                            if (user.avatarUrl.isNotEmpty)
                              Opacity(
                                opacity: 0.1,
                                child: Image.network(
                                  user.avatarUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            Container(color: Colors.black87.withOpacity(0.5)),
                            if (isOwner)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white24,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => const EditProfilePage(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Avatar
                      Positioned(
                        top: headerHeight - avatarRadius,
                        left: 16,
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: avatarRadius - 5,
                            backgroundImage:
                                user.avatarUrl.isNotEmpty
                                    ? NetworkImage(user.avatarUrl)
                                    : null,
                            child:
                                user.avatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                          ),
                        ),
                      ),
                      // Name & role
                      Positioned(
                        top: headerHeight - avatarRadius + 5,
                        left: avatarRadius * 2 + 24,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName
                                  : 'Namnlös användare',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user.mainRole.isNotEmpty ? user.mainRole : '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions row
                Transform.translate(
                  offset: const Offset(0, -avatarRadius + 10),
                  child: Padding(
                    padding: EdgeInsets.only(left: avatarRadius + 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ProfileAction(
                          icon: Icons.message,
                          label: 'Dm',
                          onTap: () {},
                        ),
                        _ProfileAction(
                          icon: Icons.call,
                          label: 'Ring',
                          onTap: () {},
                        ),
                        _ProfileAction(
                          icon: Icons.star_border,
                          label: 'Favorit',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                // Tabs
                Material(
                  color: Colors.white,
                  child: TabBar(
                    indicatorColor: theme.primaryColor,
                    labelColor: theme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Info'),
                      Tab(text: 'Statistik'),
                      Tab(text: 'Favoriter'),
                    ],
                  ),
                ),
                // Tab views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Info tab
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.email),
                            title: Text(user.email),
                          ),
                          ListTile(
                            leading: const Icon(Icons.phone),
                            title: Text(user.phoneNumber ?? ''),
                          ),

                          ListTile(
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: Text(user.yob),
                          ),
                          ListTile(
                            leading: const Icon(Icons.favorite),
                            title: Text(user.favouritePosition ?? ''),
                          ),
                        ],
                      ),
                      // ─── Statistik ────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          // Beräkna dokument‐ID: "{userId}_{currentYear}"
                          future:
                              ref
                                  .read(firestoreProvider)
                                  .collection('playerStats')
                                  .doc('${user.id}_${DateTime.now().year}')
                                  .get(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snap.hasError) {
                              return Center(
                                child: Text(
                                  'Fel vid hämtning av statistik: ${snap.error}',
                                ),
                              );
                            }
                            final doc = snap.data;
                            if (doc == null || !doc.exists) {
                              return const Center(
                                child: Text('Ingen statistik för i år.'),
                              );
                            }
                            final data = doc.data()!;

                            // Hämta fälten (fallback till 0 om de saknas)
                            final matchesParticipated =
                                (data['attendedMatches'] ?? 0) as int;
                            final totalNrOfMatches =
                                (data['totalMatches'] ?? 0) as int;
                            final matchesCalled =
                                (data['callupsForMatches'] ?? 0) as int;
                            final matchesAccepted =
                                (data['acceptedCallupsForMatches'] ?? 0) as int;
                            final matchesRejected =
                                (data['rejectedCallupsForMatches'] ?? 0) as int;
                            final matchesNotAnswered =
                                data['callupsForMatches'] -
                                (data['rejectedCallupsForMatches'] +
                                    data['acceptedCallupsForMatches']);
                            final trainingsParticipated =
                                (data['attendedTrainings'] ?? 0) as int;
                            final totalNrOfTrainings =
                                (data['totalTrainings'] ?? 0) as int;
                            final trainingsCalled =
                                (data['callupsForTrainings'] ?? 0) as int;
                            final trainingsAccepted =
                                (data['acceptedCallupsForTrainings'] ?? 0)
                                    as int;
                            final trainingsRejected =
                                (data['rejectedCallupsForTrainings'] ?? 0)
                                    as int;
                            final trainingsNotAnswered =
                                data['callupsForTrainings'] -
                                (data['rejectedCallupsForTrainings'] +
                                    data['acceptedCallupsForTrainings']);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // --- ersätt dina ListTile-segment med detta Table-widget ---
                                Table(
                                  // justera kolumn­bredder efter behov
                                  columnWidths: const {
                                    0: FlexColumnWidth(
                                      2,
                                    ), // kolumn 0 (etikett) får mer utrymme
                                    1: FixedColumnWidth(
                                      30,
                                    ), // kolumn 1–5 för ikoner/siffror
                                    2: FixedColumnWidth(30),
                                    3: FixedColumnWidth(30),
                                    4: FixedColumnWidth(30),
                                    5: FixedColumnWidth(30),
                                    6: FixedColumnWidth(30),
                                  },
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    // 1) Header‐rad med ikoner
                                    TableRow(
                                      children: [
                                        const SizedBox(), // tom cell för “etikett-kolumnen”
                                        Tooltip(
                                          message:
                                              'Antal Träningar/Matcher spelaren deltagit i',
                                          triggerMode: TooltipTriggerMode.tap,
                                          child: Icon(
                                            Icons.sports_soccer,
                                            size: 20,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Tooltip(
                                          message:
                                              'Antal kallelser spelaren fått',
                                          triggerMode: TooltipTriggerMode.tap,
                                          child: Icon(
                                            Icons.circle_notifications,
                                            size: 20,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Tooltip(
                                          message:
                                              'Antal kallelser spelaren accepterat',
                                          triggerMode: TooltipTriggerMode.tap,
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 20,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Tooltip(
                                          message:
                                              'Antal kallelser spelaren avböjt',
                                          triggerMode: TooltipTriggerMode.tap,
                                          child: Icon(
                                            Icons.cancel,
                                            size: 20,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Tooltip(
                                          message:
                                              'Antal kallelser spelaren inte svarat på',
                                          triggerMode: TooltipTriggerMode.tap,
                                          child: Icon(
                                            Icons.notifications_off_sharp,
                                            size: 20,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Tooltip(
                                          message:
                                              'Totalt antal träningar/matcher laget har gjort',
                                          triggerMode: TooltipTriggerMode.tap,

                                          child: Icon(
                                            Icons.event,
                                            size: 20,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // 2) Matcher
                                    TableRow(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'Matcher',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$matchesParticipated',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$matchesCalled',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$matchesAccepted',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$matchesRejected',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$matchesNotAnswered',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$totalNrOfMatches',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                    // 3) Träningar
                                    TableRow(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            'Träningar',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$trainingsParticipated',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$trainingsCalled',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$trainingsAccepted',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$trainingsRejected',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$trainingsNotAnswered',
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$totalNrOfTrainings',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                const Divider(),
                                // TODO: Mål, assist, minuter…
                              ],
                            );
                          },
                        ),
                      ),

                      // Favoriter tab
                      Center(
                        child: Text(
                          'Inga favoriter tillagda',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileAction({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            radius: 20,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
