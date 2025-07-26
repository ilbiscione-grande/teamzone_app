// lib/features/home/team_tab.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'event_details_page.dart';
import 'package:teamzone_app/ui/widgets/match_card.dart';
import 'package:teamzone_app/ui/widgets/event_card.dart';
import 'package:teamzone_app/ui/widgets/announcement_card.dart';
import 'package:teamzone_app/ui/widgets/player_tile.dart';
import 'package:teamzone_app/ui/widgets/team_image_uploader.dart';

class TeamTab extends ConsumerWidget {
  const TeamTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));

    final teamId = session.currentTeamId;
    final isAdmin = session.isAdmin;

    if (teamId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final teamsRef = db.collection('teams');
    final eventsRef = db.collection('events');
    final announcementsRef = db.collection('messages');
    final requestsRef = db.collection('invites');

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab-bar med två flikar
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [Tab(text: 'Info'), Tab(text: 'Spelare')],
            ),
          ),

          // Innehållet för varje flik
          Expanded(
            child: TabBarView(
              children: [
                // ── Flik 1: Info ─────────────────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1) Team-bild
                      TeamImageUploader(teamId: teamId, isAdmin: isAdmin),
                      const SizedBox(height: 24),

                      // … direkt efter SizedBox(height: 24) under TeamImageUploader …

                      // 2) Olästa announcements
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream:
                            announcementsRef
                                .where('teamId', isEqualTo: teamId)
                                .where('messageType', isEqualTo: 'announcement')
                                .orderBy('lastMessageTime', descending: true)
                                .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData) return const SizedBox();
                          final allDocs = snap.data!.docs;

                          // Filtrera fram de snapshot där session.uid inte finns i readBy-listan
                          final unreadSnaps =
                              allDocs.where((docSnap) {
                                final data = docSnap.data();
                                final readBy =
                                    (data['readBy'] as List<dynamic>?)
                                        ?.cast<String>() ??
                                    [];
                                return !readBy.contains(session.uid);
                              }).toList();

                          if (unreadSnaps.isEmpty) return const SizedBox();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nya anslag',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Loopa över alla olästa och bygg ett AnnouncementCard för var och en
                              for (final docSnap in unreadSnaps) ...[
                                AnnouncementCard.fromDoc(docSnap, session.uid),
                                const SizedBox(height: 12),
                              ],

                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),

                      // 2) Senaste matchen
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream:
                            eventsRef
                                .where('teamId', isEqualTo: teamId)
                                .where('eventDate', isLessThan: DateTime.now())
                                .where('eventType', isEqualTo: 'Match')
                                .orderBy('eventDate', descending: true)
                                .limit(1)
                                .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData || snap.data!.docs.isEmpty) {
                            return const SizedBox();
                          }
                          final doc = snap.data!.docs.first;
                          final matchData = doc.data();
                          final matchId = doc.id;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Senaste matchen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => EventDetailsPage(
                                            eventId: matchId,
                                          ),
                                    ),
                                  );
                                },
                                child: MatchCard.fromMap(matchData),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),

                      // 3) Kommande 3 events
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream:
                            eventsRef
                                .where('teamId', isEqualTo: teamId)
                                .where(
                                  'eventDate',
                                  isGreaterThan: DateTime.now(),
                                )
                                .orderBy('eventDate')
                                .limit(3)
                                .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData || snap.data!.docs.isEmpty) {
                            return const SizedBox();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Kommande händelser',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final doc in snap.data!.docs) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => EventDetailsPage(
                                                eventId: doc.id,
                                              ),
                                        ),
                                      );
                                    },
                                    child: EventCard.fromDoc(
                                      doc,
                                      auth.currentUser!.uid,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),

                      // 5) Pending join-requests (admin only)
                      if (isAdmin)
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream:
                              requestsRef
                                  .where('teamId', isEqualTo: teamId)
                                  .where('inviteType', isEqualTo: 'request')
                                  .where('status', isEqualTo: 'pending')
                                  .snapshots(),
                          builder: (ctx, snap) {
                            if (!snap.hasData || snap.data!.docs.isEmpty) {
                              return const SizedBox();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nya ansökningar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final doc in snap.data!.docs) ...[
                                  ListTile(
                                    leading: const Icon(Icons.person_add),
                                    title: Text(
                                      doc.data()['userName'] as String,
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          ),
                                          onPressed: () {
                                            /* TODO */
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            /* TODO */
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // ── Flik 2: Spelare ───────────────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: // 6) Lista på spelare
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: teamsRef.doc(teamId).snapshots(),
                    builder: (ctx, teamSnap) {
                      if (teamSnap.connectionState != ConnectionState.active) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final teamData = teamSnap.data?.data() ?? {};
                      final raw = teamData['members'] as List<dynamic>? ?? [];
                      final memberIds = raw.cast<String>();

                      if (memberIds.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Inga spelare har lagts till ännu'),
                        );
                      }

                      // Dela upp i bitar om max 10 IDs var
                      final chunks = <List<String>>[];
                      for (var i = 0; i < memberIds.length; i += 10) {
                        chunks.add(
                          memberIds.sublist(i, min(i + 10, memberIds.length)),
                        );
                      }

                      return FutureBuilder<
                        List<QuerySnapshot<Map<String, dynamic>>>
                      >(
                        future: Future.wait(
                          chunks.map((ids) {
                            return db
                                .collection('users')
                                .where(FieldPath.documentId, whereIn: ids)
                                .get();
                          }),
                        ),
                        builder: (ctx2, userSnap) {
                          if (userSnap.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (userSnap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Fel vid hämtning av spelare: ${userSnap.error}',
                              ),
                            );
                          }

                          // Slå ihop alla dokument
                          final allDocs =
                              userSnap.data!.expand((qs) => qs.docs).toList();

                          // Dela direkt efter userType
                          final playerDocs =
                              allDocs
                                  .where(
                                    (d) => d.data()['userType'] == 'Spelare',
                                  )
                                  .toList();
                          final leaderDocs =
                              allDocs
                                  .where(
                                    (d) => d.data()['userType'] == 'Ledare',
                                  )
                                  .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Spelare
                              for (final doc in playerDocs)
                                PlayerTile(
                                  userId: doc['uid'],
                                  teamName: session.teamName,
                                  player: doc.data(),
                                  currentUserId: session.uid,
                                  teamId: session.currentTeamId,
                                ),

                              // Ledare
                              if (leaderDocs.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Ledare',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final doc in leaderDocs)
                                  PlayerTile(
                                    userId: doc['uid'],
                                    teamName: session.teamName,
                                    currentUserId: session.uid,
                                    player: doc.data(),
                                    teamId: session.currentTeamId,
                                  ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
