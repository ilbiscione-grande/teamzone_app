// lib/features/home/events_tab.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/firestore_providers.dart'; // ← ny import
import '../../core/providers/user_session.dart';
import '../../domain/models/my_event.dart';
import 'event_details_page.dart';

/// Reusable EventCard widget
class EventCard extends StatelessWidget {
  final MyEvent event;
  final VoidCallback? onTap;
  final bool isDense;

  const EventCard({
    Key? key,
    required this.event,
    this.onTap,
    this.isDense = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final endTime = event.start.add(event.duration);
    final startHour = event.start.hour.toString().padLeft(2, '0');
    final startMinute = event.start.minute.toString().padLeft(2, '0');
    final endHour = endTime.hour.toString().padLeft(2, '0');
    final endMinute = endTime.minute.toString().padLeft(2, '0');
    final timeRange = '$startHour:$startMinute – $endHour:$endMinute';

    final title =
        event.type == EventType.match
            ? (event.opponent.isNotEmpty ? event.opponent : 'Okänd motståndare')
            : event.rawType;

    final padding =
        isDense
            ? const EdgeInsets.symmetric(vertical: 4, horizontal: 8)
            : const EdgeInsets.symmetric(vertical: 12, horizontal: 16);
    final fontSize = isDense ? 12.0 : 16.0;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
              if (!isDense) ...[
                const SizedBox(height: 4),
                Text(
                  timeRange,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: const TextStyle(color: Colors.black, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(
                  '${event.pitch}, ${event.area}',
                  style: const TextStyle(color: Colors.black, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Main EventsTab with month/3-day/day views and top view selector
class EventsTab extends ConsumerStatefulWidget {
  const EventsTab({Key? key}) : super(key: key);

  @override
  _EventsTabState createState() => _EventsTabState();
}

enum _ViewMode { month, multiDay, day }

class _EventsTabState extends ConsumerState<EventsTab> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;
  String _subscribedTeamId = '';

  List<MyEvent> _events = [];
  Map<DateTime, List<MyEvent>> _eventsByDay = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  MyEvent? _selectedEvent;
  _ViewMode _viewMode = _ViewMode.month;
  bool _fullCellMode = false;

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToEvents(String teamId) {
    _eventsSubscription?.cancel();
    final db = ref.read(firestoreProvider);
    _eventsSubscription = db
        .collection('events')
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .listen((snapshot) {
          final events =
              snapshot.docs.map((doc) => MyEvent.fromSnapshot(doc)).toList();
          setState(() {
            _events = events;
            _groupEvents();
            final todays = _eventsByDay[_stripTime(_selectedDay)];
            _selectedEvent =
                (todays != null && todays.isNotEmpty) ? todays.first : null;
          });
        });
  }

  void _groupEvents() {
    _eventsByDay.clear();
    for (var e in _events) {
      final key = _stripTime(e.start);
      _eventsByDay.putIfAbsent(key, () => []).add(e);
    }
  }

  DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final uid = auth.currentUser?.uid ?? '';
    final session = uid.isEmpty ? null : ref.watch(userSessionProvider(uid));
    final teamId = session?.currentTeamId ?? '';

    // Prenumerera om teamId ändras
    if (teamId.isNotEmpty && teamId != _subscribedTeamId) {
      _subscribedTeamId = teamId;
      _subscribeToEvents(teamId);
    }

    Widget body;
    switch (_viewMode) {
      case _ViewMode.month:
        body = _buildMonth();
        break;
      case _ViewMode.multiDay:
        body = _buildMultiDay(context);
        break;
      case _ViewMode.day:
        body = _buildDayView(context);
        break;
    }

    return Scaffold(
      body: Column(
        children: [
          // Översta raden med vyväxling
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _navButton(
                  icon: Icons.chevron_left,
                  label: 'Föregående',
                  onPressed: () {
                    setState(() {
                      if (_viewMode == _ViewMode.multiDay) {
                        _selectedDay = _selectedDay.subtract(
                          const Duration(days: 3),
                        );
                      } else if (_viewMode == _ViewMode.day) {
                        _selectedDay = _selectedDay.subtract(
                          const Duration(days: 1),
                        );
                      } else {
                        _focusedDay = _focusedDay.subtract(
                          const Duration(days: 30),
                        );
                      }
                    });
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _viewButton(
                        label: 'Månad',
                        icon: Icons.calendar_month,
                        mode: _ViewMode.month,
                      ),
                      _viewButton(
                        label: '3-dagar',
                        icon: Icons.view_week,
                        mode: _ViewMode.multiDay,
                      ),
                      _viewButton(
                        label: 'Dag',
                        icon: Icons.calendar_today,
                        mode: _ViewMode.day,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _navButton(
                  icon: Icons.chevron_right,
                  label: 'Nästa',
                  onPressed: () {
                    setState(() {
                      if (_viewMode == _ViewMode.multiDay) {
                        _selectedDay = _selectedDay.add(
                          const Duration(days: 3),
                        );
                      } else if (_viewMode == _ViewMode.day) {
                        _selectedDay = _selectedDay.add(
                          const Duration(days: 1),
                        );
                      } else {
                        _focusedDay = _focusedDay.add(const Duration(days: 30));
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildMonth() {
    final eventsForSelected = _eventsByDay[_stripTime(_selectedDay)] ?? [];

    return Column(
      children: [
        // Rubrik + toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMM('sv_SE').format(_focusedDay),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: _fullCellMode,
                  onChanged: (v) => setState(() => _fullCellMode = v),
                ),
              ),
            ],
          ),
        ),

        // Kalender
        TableCalendar<MyEvent>(
          locale: 'sv_SE',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          eventLoader: (d) => _eventsByDay[_stripTime(d)] ?? [],
          headerVisible: false,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            selectedBuilder: (ctx, date, focused) {
              final evs = _eventsByDay[_stripTime(date)] ?? [];
              final border =
                  evs.isEmpty
                      ? Border.all(color: Colors.black, width: 2)
                      : null;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: evs.isEmpty ? Colors.transparent : _colorForDay(evs),
                  border: border,
                ),
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
            defaultBuilder: (ctx, date, focused) {
              if (!_fullCellMode) return null;
              final evs = _eventsByDay[_stripTime(date)] ?? [];
              if (evs.isEmpty) return null;
              return Container(
                decoration: BoxDecoration(
                  color: _colorForDay(evs),
                  borderRadius: BorderRadius.circular(6),
                ),
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              );
            },
            markerBuilder: (ctx, date, evs) {
              if (_fullCellMode || evs.isEmpty) return const SizedBox();
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _colorForDay(evs),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          onDaySelected: (sel, foc) {
            setState(() {
              _selectedDay = sel;
              _focusedDay = foc;
              final list = _eventsByDay[_stripTime(sel)];
              _selectedEvent =
                  (list != null && list.isNotEmpty) ? list.first : null;
            });
          },
        ),

        const Divider(),

        // Lista för utvalda dagens events
        if (eventsForSelected.isNotEmpty)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListView(
                children: [
                  for (var e in eventsForSelected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: EventCard(
                              event: e,
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              EventDetailsPage(eventId: e.id),
                                    ),
                                  ),
                            ),
                          ),
                          if (ref
                              .watch(
                                userSessionProvider(
                                  ref
                                      .watch(authNotifierProvider)
                                      .currentUser!
                                      .uid,
                                ),
                              )
                              .isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final db = ref.read(firestoreProvider);
                                await db
                                    .collection('events')
                                    .doc(e.id)
                                    .delete();
                              },
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Inga händelser den valda dagen')),
          ),
      ],
    );
  }

  Widget _buildMultiDay(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columnWidth = screenWidth / 3;
    // Skapa tre datum i rad, utgående från _selectedDay
    final days = List.generate(3, (i) => _selectedDay.add(Duration(days: i)));

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          setState(
            () => _selectedDay = _selectedDay.add(const Duration(days: 3)),
          );
        } else if (details.primaryVelocity! > 0) {
          setState(
            () => _selectedDay = _selectedDay.subtract(const Duration(days: 3)),
          );
        }
      },
      child: Column(
        children: [
          // 1) Rubriker för dagarna
          Row(
            children:
                days.map((day) {
                  final isSelected = isSameDay(day, _selectedDay);
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 4),
                      width: columnWidth,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey.shade300),
                          right: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        DateFormat('EEEE d/M', 'sv_SE').format(day),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue : Colors.black,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),

          // 2) Själva kolumnerna, i en Expanded som tar återstående höjd
          Expanded(
            child: Row(
              children:
                  days.map((day) {
                    final eventsForDay = _eventsByDay[_stripTime(day)] ?? [];
                    return Container(
                      width: columnWidth,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                          left: BorderSide(color: Colors.grey.shade300),
                          right: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(4),
                        children:
                            eventsForDay.map((e) {
                              return EventCard(
                                event: e,
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                EventDetailsPage(eventId: e.id),
                                      ),
                                    ),
                              );
                            }).toList(),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(BuildContext context) {
    // 1 pix = 1 minut → varje timme är 60 px högt
    const double hourHeight = 60.0;
    final eventsForDay = _eventsByDay[_stripTime(_selectedDay)] ?? [];
    final controller = ScrollController(initialScrollOffset: hourHeight * 12);
    const int startHour = 6;
    const int totalHours = 18;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          setState(
            () => _selectedDay = _selectedDay.add(const Duration(days: 1)),
          );
        } else if (details.primaryVelocity! > 0) {
          setState(
            () => _selectedDay = _selectedDay.subtract(const Duration(days: 1)),
          );
        }
      },
      child: Column(
        children: [
          // Dagstitel
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              DateFormat('EEEE d/M', 'sv_SE').format(_selectedDay),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),

          // Själva tidsgrid + events
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              child: SizedBox(
                height: 18 * hourHeight,
                child: Row(
                  children: [
                    // 1) Tidsetiketter
                    Column(
                      children: List.generate(totalHours, (i) {
                        final hour = startHour + i;
                        return Container(
                          height: hourHeight,
                          alignment: Alignment.topCenter,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                    ),

                    // 2) Event‐area med Stack
                    Expanded(
                      child: Stack(
                        children: [
                          // Grid-rader
                          Column(
                            children: List.generate(totalHours, (_) {
                              return Container(
                                height: hourHeight,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          // 3) Positionerade events
                          for (var e in eventsForDay)
                            Positioned(
                              top:
                                  (e.start.hour - startHour) * hourHeight +
                                  (e.start.minute / 60) * hourHeight,
                              left: 4,
                              right: 4,
                              height: (e.duration.inMinutes / 60) * hourHeight,
                              child: GestureDetector(
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                EventDetailsPage(eventId: e.id),
                                      ),
                                    ),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  color: Colors.grey.shade100,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 4,
                                      left: 8,
                                      right: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Titel + tidsintervall
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                e.type == EventType.match
                                                    ? e.opponent
                                                    : e.rawType,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${DateFormat.Hm().format(e.start)}–'
                                              '${DateFormat.Hm().format(e.start.add(e.duration))}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Beskrivning
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              e.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              e.pitch + ', ' + e.area,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        e.ourGoals != null &&
                                                e.opponentGoals != null
                                            ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                        bottom: 2,
                                                        left: 8,
                                                        right: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        e.ourGoals! >
                                                                e.opponentGoals!
                                                            ? Colors.green
                                                            : e.ourGoals! ==
                                                                e.opponentGoals!
                                                            ? Colors.grey
                                                            : Colors.red,
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    e.ourGoals.toString() +
                                                        ' - ' +
                                                        e.opponentGoals
                                                            .toString(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Container(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForDay(List<MyEvent> evs) {
    if (evs.any((e) => e.type == EventType.match)) return Colors.red;
    if (evs.any((e) => e.type == EventType.training)) return Colors.blue;
    if (evs.any((e) => e.rawType.toLowerCase().contains('möte')))
      return Colors.orange;
    return Colors.green;
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: Colors.grey.shade400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
    ),
    onPressed: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.black),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );

  Widget _viewButton({
    required String label,
    required IconData icon,
    required _ViewMode mode,
  }) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      side: BorderSide(
        color: _viewMode == mode ? Colors.blue : Colors.grey.shade400,
        width: 2,
      ),
      backgroundColor: _viewMode == mode ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
    ),
    onPressed: () => setState(() => _viewMode = mode),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _viewMode == mode ? Colors.blue : Colors.black),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _viewMode == mode ? Colors.blue : Colors.black,
          ),
        ),
      ],
    ),
  );
}
