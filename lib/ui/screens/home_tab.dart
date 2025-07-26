// lib/features/home/home_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:teamzone_app/auth/login_page.dart';
import 'package:teamzone_app/ui/widgets/event_card.dart';
import 'package:teamzone_app/ui/screens/event_details_page.dart';
import 'new_event_page.dart';

import '../../application/services/player_stats_service.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/event_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/core/providers/team_providers.dart';
import 'package:teamzone_app/domain/models/callup.dart';
import 'package:teamzone_app/domain/models/team.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final userId = auth.currentUser?.uid;
    final db = ref.read(firestoreProvider);
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final session = ref.watch(userSessionProvider(userId));
    final teamId = session.currentTeamId;
    if (teamId.isEmpty) {
      return Column(
        children: [
          const Center(child: Text('Ingen team eller användare vald.')),
          TextButton(
            onPressed: () async {
              await auth.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Logga ut'),
          ),
        ],
      );
    }

    // 1) Hämta team-modellen
    final teamAsync = ref.watch(teamProvider(teamId));
    // 2) Hämta din stats‑service
    final statsSvc = ref.read(playerStatsServiceProvider);

    // Hjälp‑timestamp
    final nowTs = Timestamp.fromDate(DateTime.now());

    // Streams för events + obesvarade callups
    final upcomingEventsStream =
        db
            .collection('events')
            .where('teamId', isEqualTo: teamId)
            .where('eventDate', isGreaterThanOrEqualTo: nowTs)
            .orderBy('eventDate')
            .limit(10)
            .snapshots();

    final pastEventsStream =
        db
            .collection('events')
            .where('teamId', isEqualTo: teamId)
            .where('eventDate', isLessThan: nowTs)
            .orderBy('eventDate', descending: true)
            .limit(10)
            .snapshots();

    final unreadMessagesStream =
        db
            .collection('messages')
            .where('teamId', isEqualTo: teamId)
            .where('participants', arrayContains: userId)
            .where('readBy', isEqualTo: false)
            .snapshots();

    final pendingRequestsStream =
        db
            .collection('join_requests')
            .where('teamId', isEqualTo: teamId)
            .where('status', isEqualTo: "pending")
            .snapshots();

    final unansweredCallupsStream =
        db
            .collection('callups')
            .where('memberId', isEqualTo: userId)
            .where('status', isEqualTo: "pending")
            .where('eventDate', isGreaterThanOrEqualTo: nowTs)
            .orderBy('eventDate', descending: true)
            .snapshots();

    // Vänta in team‑datan innan vi bygger resten
    return teamAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Kunde inte ladda lag: $e')),
      data: (team) {
        // För enkelhetens skull
        final crossYear = team.seasonCrossYear;
        final seasonStartMonth = team.seasonStartMonth;

        return DefaultTabController(
          length: 2,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    //   Kommande / Tidigare events
                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor:
                          Theme.of(context).textTheme.bodyMedium?.color,
                      tabs: const [
                        Tab(text: 'Kommande'),
                        Tab(text: 'Tidigare'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: TabBarView(
                        children: [
                          _buildEventList(
                            context,
                            userId: userId,
                            stream: upcomingEventsStream,
                            emptyText: 'Inga kommande events.',
                            onEmptyAction:
                                session.isAdmin
                                    ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const NewEventPage(),
                                      ),
                                    )
                                    : null,
                          ),
                          _buildEventList(
                            context,
                            userId: userId,
                            stream: pastEventsStream,
                            emptyText: 'Inga tidigare events.',
                            onEmptyAction:
                                session.isAdmin
                                    ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const NewEventPage(),
                                      ),
                                    )
                                    : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    //   Olästa meddelanden
                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: unreadMessagesStream,
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 32),
                            Text(
                              'Olästa meddelanden',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children:
                                  docs.map((doc) {
                                    final data = doc.data();
                                    final ts = data['sentAt'] as Timestamp?;
                                    final timeText =
                                        ts != null
                                            ? DateFormat.Hm(
                                              'sv_SE',
                                            ).format(ts.toDate())
                                            : '-';
                                    return ListTile(
                                      leading: const Icon(Icons.markunread),
                                      title: Text(
                                        data['subject'] ?? 'Inget ämne',
                                      ),
                                      subtitle: Text(data['from'] ?? 'Okänd'),
                                      trailing: Text(timeText),
                                    );
                                  }).toList(),
                            ),
                          ],
                        );
                      },
                    ),

                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    //   Förfrågningar
                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: pendingRequestsStream,
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 32),
                            Text(
                              'Förfrågningar',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children:
                                  docs.map((doc) {
                                    final data = doc.data();
                                    final ts =
                                        data['requestedAt'] as Timestamp?;
                                    final timeText =
                                        ts != null
                                            ? DateFormat.yMMMd(
                                              'sv_SE',
                                            ).format(ts.toDate())
                                            : '-';
                                    final namn = data['namn'] as String? ?? '–';
                                    final email =
                                        data['email'] as String? ?? '–';

                                    return ListTile(
                                      leading: const Icon(Icons.person_add),
                                      title: Text(namn),
                                      subtitle: Text('$email\n$timeText'),
                                      isThreeLine: true,
                                      trailing: _buildAcceptDeclineButtons(
                                        context: context,
                                        doc: doc,
                                        ref: ref,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        );
                      },
                    ),

                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    //   Obesvarade kallelser
                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    _buildCallupList(
                      unansweredCallupsStream,
                      ref,
                      team,
                      statsSvc,
                    ),

                    const SizedBox(height: 50),

                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    //   Logga ut
                    // ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
                    TextButton(
                      onPressed: () async {
                        await auth.signOut();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text('Logga ut'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAcceptDeclineButtons({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required WidgetRef ref,
  }) {
    final db = ref.read(firestoreProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle),
          color: Colors.green,
          onPressed: () async {
            final callable = FirebaseFunctions.instance.httpsCallable(
              'acceptPendingRequest',
            );
            try {
              final result = await callable.call(<String, dynamic>{
                'requestId': doc.id,
              });
              final newUid = result.data['uid'];
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ny användare skapad: $newUid')),
              );
            } on FirebaseFunctionsException catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fel: ${e.code} – ${e.message}')),
              );
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Okänt fel: $e')));
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.cancel),
          color: Colors.red,
          onPressed: () async {
            await db.collection('join_requests').doc(doc.id).delete();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Förfrågan nekad')));
          },
        ),
      ],
    );
  }

  Widget _buildEventList(
    BuildContext context, {
    required String userId,
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String emptyText,
    VoidCallback? onEmptyAction,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emptyText),
                const SizedBox(height: 15),
                if (onEmptyAction != null)
                  GestureDetector(
                    onTap: onEmptyAction,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lägg till event ',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                        Icon(
                          Icons.add_circle_outline,
                          size: 25,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children:
              docs.map((doc) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EventDetailsPage(eventId: doc.id),
                      ),
                    );
                  },
                  child: EventCard.fromDoc(doc, userId),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildCallupList(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    WidgetRef ref,
    Team team,
    PlayerStatsService statsSvc,
  ) {
    final eventRepo = ref.read(eventRepositoryProvider);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Obesvarade kallelser',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              children:
                  docs.map((doc) {
                    final callupData = doc.data();
                    final eventId = callupData['eventId'] as String?;
                    if (eventId == null) {
                      return ListTile(
                        leading: const Icon(Icons.notifications_active),
                        title: Text(callupData['eventTitle'] ?? 'Event'),
                        subtitle: const Text('-'),
                        trailing: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Svara'),
                        ),
                      );
                    }

                    return FutureBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      future:
                          ref
                              .read(firestoreProvider)
                              .collection('events')
                              .doc(eventId)
                              .get(),
                      builder: (ctx2, eventSnap) {
                        if (eventSnap.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            leading: const Icon(Icons.notifications_active),
                            title: const Text('Laddar...'),
                            subtitle: const Text('-'),
                            trailing: ElevatedButton(
                              onPressed: () {},
                              child: const Text('Svara'),
                            ),
                          );
                        }
                        final eventData = eventSnap.data?.data() ?? {};
                        final tsEvent = eventData['eventDate'] as Timestamp?;
                        final dateText =
                            tsEvent != null
                                ? DateFormat.yMMMd(
                                  'sv_SE',
                                ).format(tsEvent.toDate())
                                : '-';
                        final isMatch =
                            (eventData['eventType'] as String? ?? '')
                                .toLowerCase() ==
                            'match';
                        final title =
                            isMatch
                                ? (eventData['opponent'] ?? 'Match')
                                : (eventData['eventType'] ?? 'Event');

                        return ListTile(
                          leading: const Icon(Icons.notifications_active),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(dateText),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle),
                                color: Colors.green,
                                onPressed: () {
                                  eventRepo.updateCallupStatus(
                                    callupId: doc.id,
                                    newStatus: CallupStatus.accepted,
                                    statsSvc: statsSvc,
                                    crossYear: team.seasonCrossYear,
                                    seasonStartMonth: team.seasonStartMonth,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel),
                                color: Colors.red,
                                onPressed: () {
                                  eventRepo.updateCallupStatus(
                                    callupId: doc.id,
                                    newStatus: CallupStatus.declined,
                                    statsSvc: statsSvc,
                                    crossYear: team.seasonCrossYear,
                                    seasonStartMonth: team.seasonStartMonth,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
            ),
          ],
        );
      },
    );
  }
}
