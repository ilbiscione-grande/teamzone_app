// lib/ui/screens/event_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/event_providers.dart';
import '../widgets/event_info_section.dart';
import '../widgets/callups_section.dart';
import '../../domain/models/my_event.dart';
import '../widgets/resources_section.dart';
import '../widgets/analysis_section.dart';
import '../widgets/stats_section.dart';
import '../widgets/formation_section.dart';

class EventDetailsPage extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailsPage({Key? key, required this.eventId}) : super(key: key);

  @override
  ConsumerState<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends ConsumerState<EventDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(eventRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Trupp'),
            Tab(text: 'Analys'),
            Tab(text: 'Statistik'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Inuti TabBarView, byt ut första tabben med detta:
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Event-info
              EventInfoSection(eventStream: repo.streamEvent(widget.eventId)),
              const SizedBox(height: 12),
              const Divider(height: 1),

              const SizedBox(height: 12),

              // Formation (sparad bild med länk till editor)
              StreamBuilder<MyEvent>(
                stream: repo.streamEvent(widget.eventId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    // Du kan lägga en loader här om du vill
                    return const SizedBox.shrink();
                  }
                  final event = snap.data!;
                  if (event.type != EventType.match) {
                    // Ingen match → visa ingenting
                    return const SizedBox.shrink();
                  }
                  // Det är en match → bygg FormationSection
                  return Column(
                    children: [
                      SizedBox(
                        height: 330,
                        child: FormationSection(eventId: widget.eventId),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              // Resurser
              ResourcesSection(eventId: widget.eventId),
            ],
          ),

          // ───────────── Trupp ─────────────
          CallupsSection(eventId: widget.eventId),

          // ───────────── Analys ─────────────
          AnalysisSection(eventId: widget.eventId),

          // ───────────── Statistik ─────────────
          StatsSection(statsStream: repo.streamStats(widget.eventId)),
        ],
      ),
    );
  }
}
