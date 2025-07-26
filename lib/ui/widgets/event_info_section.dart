// lib/widgets/event_info_section.dart

import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/services/player_stats_service.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/event_providers.dart';
import '../../core/providers/firestore_providers.dart';
import '../../core/providers/team_providers.dart';
import '../../domain/models/callup.dart';
import '../../domain/models/member_callup.dart';
import '../../domain/models/my_event.dart';
import '../../domain/models/team.dart';
import '../screens/edit_event_page.dart';

/// Visar all info om ett event, inklusive “Acceptera/Tacka nej”-knappar
/// och laddar in relevant `Team` för statistik-uppdateringar.
class EventInfoSection extends ConsumerWidget {
  final Stream<MyEvent> eventStream;

  const EventInfoSection({Key? key, required this.eventStream})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Auth & session
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));

    // 2) TeamId från session
    final teamId = session.currentTeamId;
    final isAdmin = session.isAdmin;
    final clubName = session.clubName;
    final currentUserId = session.uid;

    // 3) Ladda in Team-objektet
    final teamAsync = ref.watch(teamProvider(teamId));

    return teamAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Kunde inte ladda lag: $e')),
      data: (team) {
        // När team är inläst, streama event
        return StreamBuilder<MyEvent>(
          stream: eventStream,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return const Center(
                child: Text('Kunde inte ladda eventinformation'),
              );
            }

            final event = snap.data!;
            final isMatch = event.type == EventType.match;
            final isTraining = event.type == EventType.training;
            final homeMatch = event.isHome ? 'H' : 'B';

            // Matchresultat i w/d/l
            String matchResult;
            if (event.ourGoals != null && event.opponentGoals != null) {
              matchResult =
                  event.ourGoals! > event.opponentGoals!
                      ? 'w'
                      : event.ourGoals! == event.opponentGoals!
                      ? 'd'
                      : 'l';
            } else {
              matchResult = '';
            }

            final title = isMatch ? event.opponent : event.rawType;
            final dateFmt = DateFormat('EEEE d MMMM yyyy', 'sv_SE');
            final timeFmt = DateFormat('HH:mm', 'sv_SE');
            final storageRef = FirebaseStorage.instance.ref().child(
              'events/${event.id}',
            );

            // Riverpod-stream för alla callups
            final callupsAsync = ref.watch(callupsProvider(event.id));

            // Bygg responsknappar om användaren själv har en pending-kallelse
            final responseRow = callupsAsync.when(
              data: (list) {
                final selfList = list.where(
                  (c) => c.member.uid == currentUserId,
                );
                final MemberCallup? self =
                    selfList.isNotEmpty ? selfList.first : null;
                if (self != null && self.status == CallupStatus.pending) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(eventRepositoryProvider)
                                  .updateCallupStatus(
                                    callupId: self.callupId!,
                                    newStatus: CallupStatus.accepted,
                                    statsSvc: ref.read(
                                      playerStatsServiceProvider,
                                    ),
                                    crossYear: team.seasonCrossYear,
                                    seasonStartMonth: team.seasonStartMonth,
                                  );
                            },
                            child: const Text('Acceptera kallelse'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(eventRepositoryProvider)
                                  .updateCallupStatus(
                                    callupId: self.callupId!,
                                    newStatus: CallupStatus.declined,
                                    statsSvc: ref.read(
                                      playerStatsServiceProvider,
                                    ),
                                    crossYear: team.seasonCrossYear,
                                    seasonStartMonth: team.seasonStartMonth,
                                  );
                            },
                            child: const Text('Tacka nej'),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Rubrik + edit-ikon ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isMatch ? '$title ($homeMatch)' : title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.edit_document),
                          onPressed:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EditEventPage(event: event),
                                ),
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- Datum & tid ---
                  InfoTile(
                    icon: Icons.calendar_today,
                    label:
                        '${dateFmt.format(event.start)} • ${timeFmt.format(event.start)}',
                  ),
                  const SizedBox(height: 8),
                  // --- Plats ---
                  InfoTile(
                    icon: Icons.location_on,
                    label: '${event.area}, ${event.pitch}, ${event.town}',
                  ),
                  const SizedBox(height: 8),
                  // --- Beskrivning ---
                  if (event.description.isNotEmpty) ...[
                    InfoTile(icon: Icons.description, label: event.description),
                    const SizedBox(height: 8),
                  ],
                  // --- Längd ---
                  InfoTile(
                    icon: Icons.timer,
                    label:
                        isMatch
                            ? (switch (event.duration.inMinutes) {
                              90 => '90 min (2×45)',
                              75 => '75 min (3×25)',
                              60 => '60 min (3×20)',
                              45 => '45 min',
                              30 => '30 min',
                              _ => '${event.duration.inMinutes} min',
                            })
                            : _formatDuration(event.duration),
                  ),
                  const SizedBox(height: 8),
                  // --- Träning/Match-info ---
                  if (isTraining || isMatch) ...[
                    if (event.gatheringTime != null)
                      InfoTile(
                        icon: Icons.group,
                        label:
                            'Samling: ${timeFmt.format(event.gatheringTime!)}',
                      ),
                    if (event.field != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: InfoTile(icon: Icons.map, label: event.field!),
                      ),
                    if (event.coachNote != null && event.coachNote!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: InfoTile(
                          icon: Icons.note,
                          label: event.coachNote!,
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  // --- Resultat om match ---
                  if (isMatch &&
                      event.ourGoals != null &&
                      event.opponentGoals != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color:
                            matchResult == 'w'
                                ? Colors.green
                                : matchResult == 'd'
                                ? Colors.grey
                                : Colors.red[700],
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            homeMatch == 'B'
                                ? '${event.opponent} - $clubName'
                                : '$clubName - ${event.opponent}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            homeMatch == 'B'
                                ? '${event.opponentGoals} - ${event.ourGoals}'
                                : '${event.ourGoals} - ${event.opponentGoals}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // --- Svarsknappar ---
                  responseRow,
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }
}

/// Enkel rad med ikon + text
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoTile({Key? key, required this.icon, required this.label})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
