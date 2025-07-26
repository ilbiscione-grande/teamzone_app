// lib/core/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teamzone_app/auth/login_page.dart';
import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/team_providers.dart';
import 'package:teamzone_app/core/providers/user_session.dart';
import 'package:teamzone_app/domain/models/team.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomAppBar({Key? key}) : super(key: key);
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    // 1) Auth-state
    final authState = ref.watch(authNotifierProvider);
    if (authState.isInitializing) {
      return AppBar(title: const Text('Laddar…'));
    }
    final user = authState.currentUser;
    if (user == null) {
      return AppBar(title: const Text('Ej inloggad'));
    }

    // 2) Session för namn, bild och clubLogoUrl
    final session = ref.watch(userSessionProvider(user.uid));
    final userName = session.userName.isNotEmpty ? session.userName : '–';
    final userPhotoUrl = session.userPhotoUrl;
    final clubLogoUrl = session.clubLogoUrl; // <-- här

    // 3) Teams/providers för att hämta clubName & teamName
    final teamsAsync = ref.watch(userTeamsProvider);
    final currentTeamId = ref.watch(currentTeamProvider);

    // Lägg till denna lyssnare precis här:
    ref.listen<AsyncValue<List<Team>>>(userTeamsProvider, (_, teams) {
      teams.whenData((list) {
        debugPrint('🎾 Fetched teams: ${list.map((t) => t.id).toList()}');
        debugPrint('🏷️ currentTeamId: $currentTeamId');
      });
    });

    // Hämta hela roll-listan för valt team
    final rolesMap = session.teamRoles;
    final roleList = rolesMap[currentTeamId] ?? [];
    // Plocka bara första rollen
    final userRole = roleList.isNotEmpty ? roleList.first : '';

    return teamsAsync.when(
      loading: () => AppBar(title: const Text('Laddar lag…')),
      error: (err, _) => AppBar(title: Text('Fel: $err')),
      data: (teams) {
        // 1) Hantera tom lista
        if (teams.isEmpty) {
          return AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Ingen laginformation'),
          );
        }

        // 2) Hitta aktivt lag (faller tillbaka på första i listan om currentTeamId saknas)
        final active = teams.firstWhere(
          (t) => t.id == currentTeamId,
          orElse: () => teams.first,
        );

        final clubName = active.clubName;
        final teamName = active.teamName;
        return AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              if (clubLogoUrl.isNotEmpty) // använder session.clubLogoUrl
                Image.network(clubLogoUrl, width: 32, height: 32),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clubName, style: textTheme.bodyMedium),
                  Text(teamName, style: textTheme.bodySmall),
                ],
              ),
            ],
          ),
          actions: [
            InkWell(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(userName, style: const TextStyle(fontSize: 14)),
                        Text(userRole, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundImage:
                          userPhotoUrl.isNotEmpty
                              ? NetworkImage(userPhotoUrl)
                              : null,
                      child:
                          userPhotoUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
