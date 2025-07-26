// lib/ui/widgets/callups_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teamzone_app/core/providers/team_providers.dart';
import '../../domain/models/member_callup.dart';
import '../../domain/models/member.dart';
import '../../domain/models/team.dart';
import '../../domain/models/callup.dart';
import '../../core/providers/event_providers.dart';
import '../../core/providers/firestore_providers.dart';
import '../../infrastructure/repositories/event_repository.dart';
import '../../core/providers/auth_providers.dart'; // authNotifierProvider, userSessionProvider
import '../../application/services/player_stats_service.dart';
import '../../core/providers/player_stats_repository_provider.dart';

/// Streamar alla medlemmar som har den angivna clubId i sin clubIds-array
final clubMembersProvider = StreamProvider.family<List<Member>, String>((
  ref,
  clubId,
) {
  final db = ref.watch(firestoreProvider);

  return db
      .collection('users')
      .where('clubIds', arrayContains: clubId) // <-- ändrat här
      .snapshots()
      .map((snap) => snap.docs.map((doc) => Member.fromSnapshot(doc)).toList());
});

/// Streamar alla medlemmar vars currentTeamId == teamId
final teamMembersProvider = StreamProvider.family<List<Member>, String>((
  ref,
  teamId,
) {
  final db = ref.watch(firestoreProvider);

  return db
      .collection('users')
      .where('teamIds', arrayContains: teamId)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Member.fromSnapshot(d)).toList());
});

/// Söklinje
final _searchQueryProvider = StateProvider<String>((_) => '');

/// Vilka callups som är markerade
final _selectedCallupsProvider = StateProvider<Set<String>>((_) => {});

class CallupsSection extends ConsumerWidget {
  final String eventId;
  CallupsSection({Key? key, required this.eventId}) : super(key: key);
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Hämta eventet för att kunna avgöra isPast
    final eventAsync = ref.watch(eventProvider(eventId));
    // 2) Hämta valt teamId från ert CurrentTeamProvider
    final teamId = ref.watch(currentTeamProvider);
    // Om inget lag är valt ännu
    if (teamId == null) {
      return const Center(child: Text('Inget lag valt'));
    }
    // 3) Hämta lag-modellen för att komma åt clubId
    final teamAsync = ref.watch(teamProvider(teamId));

    return eventAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Kunde inte ladda event: $e')),
      data: (event) {
        final isPast = DateTime.now().isAfter(event.start);
        return teamAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Kunde inte ladda lag: $e')),
          data: (team) {
            print('DEBUG: team.clubId = ${team.clubId}');
            // Nu har du både isPast och team.clubId
            return _buildContent(
              context,
              ref,
              isPast,
              eventId,
              team.clubId,
              teamId,
              event.matchType,
              team.seasonCrossYear,
              team.seasonStartMonth,
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    bool isPast,
    String eventId,
    String clubId,
    String teamId,
    String? matchType,
    bool seasonCrossYear,
    int seasonStartMonth,
  ) {
    final searchQuery = ref.watch(_searchQueryProvider).toLowerCase();
    final callupsAsync = ref.watch(callupsProvider(eventId));
    final clubMembersAsync = ref.watch(clubMembersProvider(clubId));
    final teamMembersAsync = ref.watch(teamMembersProvider(teamId));
    final selected = ref.watch(_selectedCallupsProvider);
    final repo = ref.read(eventRepositoryProvider);
    final statsSvc = ref.read(playerStatsServiceProvider);

    final authState = ref.watch(authNotifierProvider);
    final session = ref.watch(
      userSessionProvider(authState.currentUser?.uid ?? ''),
    );
    final isAdmin = session.isAdmin;
    final currentUserId = session.uid;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Tar bort allt fokus, dvs. sökfältet tappar fokus → kollaps
        FocusScope.of(context).unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // — Sökrad —
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                isAdmin
                    ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 48,
                        // Stack så att sökrutan kan ligga ovanpå knappen
                        child: Stack(
                          children: [
                            // 1) Filter‐knappen underst, högerjusterad
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.filter_list),
                                onPressed: () {
                                  // Din filter‐logik
                                },
                              ),
                            ),

                            // 2) Skicka‐ikonen centrerat, underst
                            Align(
                              alignment: Alignment.center,
                              child: IconButton(
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.send),
                                    if (selected.isNotEmpty)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: CircleAvatar(
                                          radius: 8,
                                          backgroundColor: Colors.red,
                                          child: Text(
                                            '${selected.length}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // aktivera bara om pre‐event, admin och minst en vald
                                color:
                                    (!isPast && isAdmin && selected.isNotEmpty)
                                        ? Colors.blue
                                        : Colors.grey,
                                onPressed:
                                    (!isPast && isAdmin && selected.isNotEmpty)
                                        ? () async {
                                          // Hämta lista ur AsyncValue
                                          final allCallups =
                                              callupsAsync.asData?.value ?? [];

                                          // Filtrera på de markerade
                                          final toSend =
                                              allCallups
                                                  .where(
                                                    (mc) => selected.contains(
                                                      mc.member.uid,
                                                    ),
                                                  )
                                                  .toList();

                                          try {
                                            await repo.sendCallups(
                                              eventId,
                                              toSend,
                                              statsSvc,
                                              crossYear: seasonCrossYear,
                                              seasonStartMonth:
                                                  seasonStartMonth,
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Kallelser skickade!',
                                                ),
                                              ),
                                            );
                                            // Rensa kryssrutorna
                                            ref
                                                .read(
                                                  _selectedCallupsProvider
                                                      .notifier,
                                                )
                                                .state = {};
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Kunde inte skicka kallelser: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        : null,
                              ),
                            ),
                            // 3) Sökfältet överst, vänsterjusterat
                            Align(
                              alignment: Alignment.centerLeft,
                              child: CollapsibleSearchBar(
                                controller: _searchController,
                                onChanged:
                                    (text) =>
                                        ref
                                            .read(_searchQueryProvider.notifier)
                                            .state = text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : Container(),
          ), // — Klubbsökresultat —
          if (searchQuery.isNotEmpty)
            // 1) Hämta klubbens alla medlemmar
            clubMembersAsync.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Fel vid sökning av klubbmedlemmar: $e'),
                  ),
              data: (allMembers) {
                print(
                  '🔵 allMembers (${allMembers.length}): '
                  '${allMembers.map((m) => m.uid).toList()}',
                );

                // 2) Hämta lagets medlemmar för att utesluta dem
                return teamMembersAsync.when(
                  loading:
                      () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  error:
                      (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Fel vid hämtning av lagmedlemmar: $e'),
                      ),
                  data: (teamMembers) {
                    final teamIds = teamMembers.map((m) => m.uid).toSet();

                    // plocka ut redan kallade
                    final calledUids =
                        callupsAsync.asData?.value
                            .map((c) => c.member.uid)
                            .toSet() ??
                        {};

                    // 3) Filter: de som är i klubben, matchar sökningen
                    //    och inte redan i laget
                    final matches =
                        allMembers.where((m) {
                          final byName = m.name.toLowerCase().contains(
                            searchQuery,
                          );
                          final notInTeam = !teamIds.contains(m.uid);
                          final notCalled = !calledUids.contains(m.uid);
                          return byName && notInTeam && notCalled;
                        }).toList();
                    print(
                      '🟡 matches (${matches.length}): '
                      '${matches.map((m) => m.uid).toList()}',
                    );

                    if (matches.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Inga nya träffar i klubben.'),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Sökresultat',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...matches.map(
                            (member) => ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    member.profilePicture != null
                                        ? NetworkImage(member.profilePicture!)
                                        : null,
                                child:
                                    member.profilePicture == null
                                        ? Text(member.name[0])
                                        : null,
                              ),
                              title: Text(member.name),
                              subtitle: Text(member.position),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add),
                                onPressed: () async {
                                  final callup = MemberCallup(
                                    callupId: null,
                                    member: member,
                                    status: CallupStatus.pending,
                                    participated: false,
                                  );
                                  try {
                                    await repo.sendCallups(
                                      eventId,
                                      [callup],
                                      statsSvc,
                                      crossYear: seasonCrossYear,
                                      seasonStartMonth: seasonStartMonth,
                                    );

                                    // 1) Rensa söksträngen
                                    ref
                                        .read(_searchQueryProvider.notifier)
                                        .state = '';
                                    // 2) Rensa TextField
                                    _searchController.clear();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${member.name} har kallats!',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Kunde inte kalla ${member.name}: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

          // — Befintlig callups-lista —
          Expanded(
            child: callupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Center(
                    child: Text(
                      'Fel vid hämtning av kallelser: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              data: (callups) {
                if (callups.isEmpty) {
                  return const Center(child: Text('Inga medlemmar'));
                }

                // 1) Dela upp på spelare vs ledare
                final players =
                    callups
                        .where((c) => c.member.userType == MemberType.player)
                        .toList()
                      ..sort((a, b) => a.member.name.compareTo(b.member.name));
                final leaders =
                    callups
                        .where((c) => c.member.userType == MemberType.leader)
                        .toList()
                      ..sort((a, b) => a.member.name.compareTo(b.member.name));

                // 2) Dela upp kallade vs ej kallade
                final calledPlayers =
                    players
                        .where((c) => c.status != CallupStatus.notCalled)
                        .toList();
                final uncalledPlayers =
                    players
                        .where((c) => c.status == CallupStatus.notCalled)
                        .toList();
                final calledLeaders =
                    leaders
                        .where((c) => c.status != CallupStatus.notCalled)
                        .toList();
                final uncalledLeaders =
                    leaders
                        .where((c) => c.status == CallupStatus.notCalled)
                        .toList();

                // 3) Bygg listan i önskad ordning
                final children = <Widget>[];

                if (calledPlayers.isNotEmpty) {
                  children.add(_buildSectionHeader('Kallade spelare', isPast));
                  children.addAll(
                    calledPlayers.map(
                      (c) => _buildTile(
                        context,
                        ref,
                        c,
                        isPast,
                        isAdmin,
                        eventId,
                        matchType!,
                        teamId,
                        seasonCrossYear,
                        seasonStartMonth,
                      ),
                    ),
                  );
                }

                if (calledLeaders.isNotEmpty) {
                  children.add(_buildSectionHeader('Kallade ledare', isPast));
                  children.addAll(
                    calledLeaders.map(
                      (c) => _buildTile(
                        context,
                        ref,
                        c,
                        isPast,
                        isAdmin,
                        eventId,
                        matchType!,
                        teamId,
                        seasonCrossYear,
                        seasonStartMonth,
                      ),
                    ),
                  );
                }

                if (uncalledPlayers.isNotEmpty) {
                  children.add(_buildSectionHeader('Spelare', isPast));
                  children.addAll(
                    uncalledPlayers.map(
                      (c) => _buildTile(
                        context,
                        ref,
                        c,
                        isPast,
                        isAdmin,
                        eventId,
                        matchType!,
                        teamId,
                        seasonCrossYear,
                        seasonStartMonth,
                      ),
                    ),
                  );
                }

                if (uncalledLeaders.isNotEmpty) {
                  children.add(_buildSectionHeader('Ledare', isPast));
                  children.addAll(
                    uncalledLeaders.map(
                      (c) => _buildTile(
                        context,
                        ref,
                        c,
                        isPast,
                        isAdmin,
                        eventId,
                        matchType!,
                        teamId,
                        seasonCrossYear,
                        seasonStartMonth,
                      ),
                    ),
                  );
                }

                // 4) Slutligen returnera detta i en ListView
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: children,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isPast) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          title == 'Kallade spelare'
              ? Text(
                isPast ? 'Deltog' : '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
              : title == 'Kallade ledare'
              ? Text(
                isPast ? 'Deltog' : '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
              : Container(),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    MemberCallup mc,
    bool isPast,
    bool isAdmin,
    String eventId,
    String matchType,
    String teamId,
    bool seasonCrossYear,
    int seasonStartMonth,
  ) {
    final repo = ref.read(eventRepositoryProvider);
    final isNotCalled = mc.status == CallupStatus.notCalled;
    final selected = ref.watch(_selectedCallupsProvider);
    final isSelected = selected.contains(mc.member.id);

    // 1) Bygg avataren med fallback
    final picUrl = mc.member.profilePicture;
    final hasImage = picUrl?.isNotEmpty == true;
    final avatar = CircleAvatar(
      radius: 18,
      backgroundImage: hasImage ? NetworkImage(picUrl!) : null,
      child:
          hasImage
              ? null
              : Text(
                mc.member.name.isNotEmpty
                    ? mc.member.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
    );

    // 2) Välj leadingWidget
    Widget leadingWidget;
    if (!isPast && isAdmin) {
      // Admin före event: checkbox eller statusikon
      leadingWidget =
          isNotCalled
              ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggle(ref, mc.member.id),
              )
              : Icon(
                _iconForStatus(mc.status),
                color: _colorForStatus(mc.status),
              );
    } else {
      // Alla andra: avatar
      leadingWidget = avatar;
    }

    // 3) Bygg trailingWidget ENDAST för admin före event
    Widget? trailingWidget;
    if (!isPast && isAdmin) {
      trailingWidget = IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () async {
          final comparisonList = await repo.fetchMembersWithSameRole(
            eventId,
            mc.member.position,
          );

          showPlayerStatsBottomSheet(
            context: context,
            ref: ref,
            eventId: eventId,
            repo: repo,
            memberCallup: mc,
            matchType: matchType,
            comparisonList: comparisonList.map((mc) => mc.member).toList(),
            teamId: teamId,
            seasonCrossYear: seasonCrossYear,
            seasonStartMonth: seasonStartMonth,
          );
        },
      );
    } else if (isPast && isAdmin) {
      trailingWidget = IconButton(
        icon: Icon(
          mc.participated ? Icons.check_circle : Icons.radio_button_unchecked,
          color: mc.participated ? Colors.green : Colors.grey,
        ),
        tooltip: mc.participated ? 'Har deltagit' : 'Markera som deltagit',
        onPressed: () async {
          if (!mc.participated) {
            // 1) Markera i callups‐kollektionen
            await repo.markParticipated(
              eventId: eventId,
              callupId: mc.callupId,
              memberId: mc.member.uid,
            );

            // 2) Uppdatera aggregerad userStats
            final statsSvc = ref.read(playerStatsServiceProvider);
            // Anta att du hämtar säsong dynamiskt eller hårdkodar t.ex. '2025'
            const season = '2025';
            await statsSvc.updateStats(
              userId: mc.member.uid,
              season: season,
              teamId: teamId,
              // öka match‐ eller training‐räknare beroende på eventType
              deltaCallupsForMatches: matchType == 'Match' ? 1 : 0,
              deltaCallupsForTrainings: matchType == 'Training' ? 1 : 0,
            );

            // 3) Skriv per-event-statistik under events/{eventId}/eventStats/{userId}
            await statsSvc.setEventStats(
              eventId: eventId,
              userId: mc.member.uid,
              attended: true,
              goals: 0,
              assists: 0,
              minutes: 0,
            );

            // 4) Ge feedback
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${mc.member.name} markerad som deltagit'),
                ),
              );
            }
          }
        },
      );
    }

    // 4) Returnera ListTile med både leading och trailing
    return ListTile(
      onTap:
          (!isPast && isAdmin && isNotCalled)
              ? () => _toggle(ref, mc.member.id)
              : null,
      leading: leadingWidget,
      title: Text(mc.member.name, style: const TextStyle(fontSize: 14)),
      trailing: trailingWidget, // menyn syns bara för admins & kallade
    );
  }

  void _markAsParticipated(
    BuildContext context,
    MemberCallup mc,
    EventRepository repo,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Markera som deltagit'),
            content: Text(
              'Vill du markera ${mc.member.name} som deltagit i detta event?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Avbryt'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Bekräfta'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await repo.markParticipated(
          eventId: eventId, // se till att eventId finns tillgängligt
          callupId: mc.callupId, // kan vara null, hanteras i repo
          memberId: mc.member.uid,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${mc.member.name} markerad som deltagit.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Kunde inte uppdatera: $e')));
        }
      }
    }
  }

  void showPlayerStatsBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String eventId,
    required EventRepository repo,
    required MemberCallup memberCallup,
    required List<Member> comparisonList,
    required String matchType,
    required String teamId,
    required bool seasonCrossYear,
    required int seasonStartMonth,
  }) {
    final member = memberCallup.member;
    final statsSvc = ref.read(playerStatsServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final db = ref.watch(firestoreProvider);
        final callupId = memberCallup.callupId;

        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Padding(
            // Skapa plats för tangentbord om det dyker upp
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Profilrad ---
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 15),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage:
                            (member.profilePicture?.isNotEmpty == true)
                                ? NetworkImage(member.profilePicture!)
                                : null,
                        child:
                            (member.profilePicture == null ||
                                    member.profilePicture!.isEmpty)
                                ? const Icon(Icons.person, size: 32)
                                : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            member.position.isNotEmpty
                                ? member.position
                                : 'Ingen position angiven',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _buildStatRow(
                    title: 'Matcher',
                    participated: member.matchesParticipated,
                    called: member.matchesCalled,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _buildStatRow(
                    title: 'Träningar',
                    participated: member.trainingsParticipated,
                    called: member.trainingsCalled,
                  ),
                ),

                const SizedBox(height: 24),

                // --- Jämförelse ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'Jämförelse (samma roll)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder(
                    horizontalInside: BorderSide(color: Colors.grey.shade300),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.2),
                    3: FlexColumnWidth(1.2),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Header
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFEFEFEF)),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Namn på spelaren',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Matcher',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Träningar',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Senaste 2/6v',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // Egen rad
                    _buildStatTableRow(member),
                    // Övriga
                    ...comparisonList.where((m) => m.uid != member.uid).map((
                      m,
                    ) {
                      final matchPct =
                          m.matchesCalled > 0
                              ? (m.matchesParticipated / m.matchesCalled * 100)
                                  .round()
                              : 0;
                      final trainingPct =
                          m.trainingsCalled > 0
                              ? (m.trainingsParticipated /
                                      m.trainingsCalled *
                                      100)
                                  .round()
                              : 0;
                      final ownMatchPct =
                          member.matchesCalled > 0
                              ? (member.matchesParticipated /
                                      member.matchesCalled *
                                      100)
                                  .round()
                              : 0;
                      final ownTrainingPct =
                          member.trainingsCalled > 0
                              ? (member.trainingsParticipated /
                                      member.trainingsCalled *
                                      100)
                                  .round()
                              : 0;

                      Color getColor(int val, int own) {
                        if (val > own) return Colors.green;
                        if (val < own) return Colors.red;
                        return Colors.black;
                      }

                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(m.name),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${m.matchesParticipated} (${m.matchesCalled}) $matchPct%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: getColor(matchPct, ownMatchPct),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${m.trainingsParticipated} (${m.trainingsCalled}) $trainingPct%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: getColor(trainingPct, ownTrainingPct),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${m.trainingsLast2WeeksPct}% / ${m.trainingsLast6WeeksPct}%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: getColor(
                                  m.trainingsLast2WeeksPct,
                                  m.trainingsLast6WeeksPct,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                const Spacer(),

                // Om ej kallad – visa bara "Kalla spelare"
                if (callupId == null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Kalla spelare'),
                      onPressed: () async {
                        final newCallup = MemberCallup(
                          callupId: null,
                          member: member,
                          status: CallupStatus.pending,
                          participated: false,
                        );
                        await repo.sendCallups(
                          eventId,
                          [newCallup],
                          statsSvc,
                          crossYear: seasonCrossYear,
                          seasonStartMonth: seasonStartMonth,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ] else ...[
                  // 1) Acceptera / Avböj
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                memberCallup.status == CallupStatus.accepted
                                    ? null
                                    : () async {
                                      await repo.updateCallupStatus(
                                        callupId: callupId,
                                        newStatus: CallupStatus.accepted,
                                        statsSvc: statsSvc,
                                        crossYear: seasonCrossYear,
                                        seasonStartMonth: seasonStartMonth,
                                      );
                                      Navigator.pop(ctx);
                                    },
                            child: const Text('Acceptera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                memberCallup.status == CallupStatus.declined
                                    ? null
                                    : () async {
                                      await repo.updateCallupStatus(
                                        callupId: callupId,
                                        newStatus: CallupStatus.declined,
                                        statsSvc: statsSvc,
                                        crossYear: seasonCrossYear,
                                        seasonStartMonth: seasonStartMonth,
                                      );
                                      Navigator.pop(ctx);
                                    },
                            child: const Text('Avböj'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2) Påminnelse
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream:
                          db.collection('callups').doc(callupId).snapshots(),
                      builder: (ctx2, snap) {
                        final d = snap.data?.data() ?? {};
                        final lastTs = d['lastReminderAt'] as Timestamp?;
                        final now = DateTime.now();
                        final last = lastTs?.toDate();
                        final alreadyToday =
                            last != null &&
                            last.year == now.year &&
                            last.month == now.month &&
                            last.day == now.day;

                        return TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size.fromHeight(0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.notifications),
                          label: const Text('Skicka påminnelse'),
                          onPressed:
                              alreadyToday
                                  ? null
                                  : () async {
                                    await repo.sendReminder(callupId: callupId);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Påminnelse skickad'),
                                      ),
                                    );
                                  },
                        );
                      },
                    ),
                  ),

                  // 3) Ta bort kallelse
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size.fromHeight(0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text(
                        'Ta bort kallelse',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () async {
                        await repo.deleteCallupAndRollback(
                          eventId: eventId,
                          callupId: callupId,
                          memberId: member.uid,
                          participated: false,
                          statsSvc: statsSvc,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${member.name} kallelse borttagen'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  TableRow _buildStatTableRow(Member m) {
    String formatStat(int p, int c) {
      final percent = c > 0 ? '${((p / c) * 100).toStringAsFixed(0)}%' : '0%';
      return '$p ($c) $percent';
    }

    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(m.name)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            formatStat(m.matchesParticipated, m.matchesCalled),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            formatStat(m.trainingsParticipated, m.trainingsCalled),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '${m.trainingsLast2WeeksPct}% / ${m.trainingsLast6WeeksPct}%',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required String title,
    required int participated,
    required int called,
    String subtitle = '',
  }) {
    final percent =
        called > 0 ? ((participated / called) * 100).toStringAsFixed(0) : '0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child:
                subtitle.isEmpty
                    ? Text(title)
                    : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '   $subtitle',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
          Text('$participated ($called kallad, $percent%)'),
        ],
      ),
    );
  }

  void _toggle(WidgetRef ref, String id) {
    final notifier = ref.read(_selectedCallupsProvider.notifier);
    final current = notifier.state;
    if (current.contains(id)) {
      // Skapa ett NYTT Set utan det här id:t
      notifier.state = {...current}..remove(id);
    } else {
      // Skapa ett NYTT Set med alla gamla + det nya
      notifier.state = {...current, id};
    }
  }

  IconData _iconForStatus(CallupStatus status) {
    switch (status) {
      case CallupStatus.notCalled:
        return Icons.person_off;
      case CallupStatus.pending:
        return Icons.hourglass_empty;
      case CallupStatus.accepted:
        return Icons.check_circle;
      case CallupStatus.declined:
        return Icons.cancel;
    }
  }

  Color _colorForStatus(CallupStatus status) {
    switch (status) {
      case CallupStatus.notCalled:
        return Colors.grey;
      case CallupStatus.pending:
        return Colors.orange;
      case CallupStatus.accepted:
        return Colors.green;
      case CallupStatus.declined:
        return Colors.red;
    }
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final int value;
  const _StatBubble({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class CollapsibleSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const CollapsibleSearchBar({
    Key? key,
    required this.controller,
    required this.onChanged,
  }) : super(key: key);

  @override
  _CollapsibleSearchBarState createState() => _CollapsibleSearchBarState();
}

class _CollapsibleSearchBarState extends State<CollapsibleSearchBar> {
  late FocusNode _focusNode;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_expanded) {
      setState(() => _expanded = true);
    } else if (!_focusNode.hasFocus && widget.controller.text.isEmpty) {
      setState(() => _expanded = false);
    }
  }

  void _onTextChange() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText && !_expanded) {
      setState(() => _expanded = true);
    } else if (!hasText && !_focusNode.hasFocus) {
      setState(() => _expanded = false);
    }
    widget.onChanged(widget.controller.text);
    setState(() {}); // uppdatera suffixIcon
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final fullWidth = constraints.maxWidth;
        final targetWidth = _expanded ? fullWidth : 48.0;

        return AnimatedContainer(
          width: targetWidth,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Material(
            elevation: _expanded ? 4 : 0,
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).cardColor,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: 'Sök…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    widget.controller.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            widget.controller.clear();
                            widget.onChanged('');
                            _focusNode.unfocus();
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
