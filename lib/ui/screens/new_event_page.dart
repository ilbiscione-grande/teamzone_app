// lib/features/home/new_event_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:teamzone_app/core/providers/auth_providers.dart';
import 'package:teamzone_app/core/providers/firestore_providers.dart';
import 'package:teamzone_app/core/providers/user_session.dart';

class NewEventPage extends ConsumerStatefulWidget {
  const NewEventPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NewEventPage> createState() => _NewEventPageState();
}

class _NewEventPageState extends ConsumerState<NewEventPage> {
  final _formKey = GlobalKey<FormState>();

  // Form-värden
  String _coachNote = '';
  String _description = '';
  String _pitch = '';
  String _area = '';
  String _town = '';
  String _eventType = '';
  String _matchType = '';
  String _opponent = '';
  String _recurrence = 'Ingen';
  int _durationMinutes = 90;
  bool _isHome = false;

  DateTime? _eventDateTime;
  DateTime? _endDate;
  TimeOfDay? _gatheringTime;

  bool _isLoading = false;

  // Predefinierade listor för dropdowns
  final List<String> _eventTypes = [
    'Träning',
    'Match',
    'Möte',
    'Lagaktivitet',
    'Klubbaktivitet',
  ];
  final List<String> _matchTypes = ['Serie', 'Cup', 'Träning', 'Övrigt'];
  final List<String> _recurrenceOptions = [
    'Ingen',
    'Dagligen',
    'Veckovis',
    'Månadsvis',
  ];

  // Ny metod för att plocka slutdatum
  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickEventDateTime() async {
    final now = DateTime.now();
    // 1) Välj datum
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null) return;

    // 2) Välj tid
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
    );
    if (pickedTime == null) return;

    // 3) Slå ihop till DateTime
    setState(() {
      _eventDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickGatheringTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _gatheringTime = picked);
    }
  }

  Future<void> _submit() async {
    final db = ref.read(firestoreProvider);
    if (!_formKey.currentState!.validate()) return;
    if (_eventDateTime == null || _gatheringTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Välj både datum och samlingstid')),
      );
      return;
    }
    _formKey.currentState!.save();

    // Hämta först auth, sen session via provider-familjen
    final auth = ref.read(authNotifierProvider);
    final session = ref.read(userSessionProvider(auth.currentUser?.uid ?? ''));
    final teamId = session.currentTeamId;
    if (teamId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Välj ett team innan du skapar ett event'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final coll = db.collection('events');
      final List<String> createdIds = [];
      final List<DateTime> datesToCreate = [];

      // Bygg lista på datum utifrån typ & recurrence
      if (_eventType == 'Träning') {
        switch (_recurrence) {
          case 'Dagligen':
            var date = _eventDateTime!;
            while (!date.isAfter(_endDate!)) {
              datesToCreate.add(date);
              date = date.add(const Duration(days: 1));
            }
            break;
          case 'Veckovis':
            var date = _eventDateTime!;
            while (!date.isAfter(_endDate!)) {
              datesToCreate.add(date);
              date = date.add(const Duration(days: 7));
            }
            break;
          case 'Månadsvis':
            var date = _eventDateTime!;
            while (!date.isAfter(_endDate!)) {
              datesToCreate.add(date);
              date = DateTime(date.year, date.month + 1, date.day);
            }
            break;
          default: // 'Ingen'
            datesToCreate.add(_eventDateTime!);
        }
      } else {
        // För Match/Möte/Annat bara ett event
        datesToCreate.add(_eventDateTime!);
      }

      // Spara ett dokument per datum
      for (var date in datesToCreate) {
        final docRef = coll.doc();
        final eventId = docRef.id;
        final now = FieldValue.serverTimestamp();

        final eventDateTs = Timestamp.fromDate(date);
        final gatheringTs = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, date.hour, date.minute),
        );

        final data = {
          'coachNote': _coachNote.trim(),
          'createdAt': now,
          'createdBy': session.uid,
          'description': _description.trim(),
          'duration': _durationMinutes,
          'eventDate': eventDateTs,
          'eventType': _eventType,
          'gatheringTime': gatheringTs,
          'isHome': _isHome,
          'town': _town.trim(),
          'area': _area.trim(),
          'pitch': _pitch.trim(),
          'matchType': _matchType,
          'opponent': _opponent.trim(),
          'recurrence': _recurrence,
          'teamId': teamId,
          'eventId': eventId,
        };

        await docRef.set(data);
        createdIds.add(eventId);
      }

      // Uppdatera team-dokumentet med alla nya eventId
      await db.collection('teams').doc(teamId).update({
        'events': FieldValue.arrayUnion(createdIds),
      });

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunde inte skapa event: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
        _eventDateTime == null
            ? 'Ingen datum valt'
            : '${_eventDateTime!.toLocal().toIso8601String().split('T').first}';
    final timeText =
        _gatheringTime == null
            ? 'Ingen tid valt'
            : _gatheringTime!.format(context);
    final endDateText =
        _endDate == null
            ? 'Ingen slutdatum valt'
            : _endDate!.toLocal().toIso8601String().split('T').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Skapa nytt event')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                children: [
                  Row(
                    children: [
                      // 70 % av bredden
                      Expanded(
                        flex: 75,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Event Type',
                          ),
                          value: _eventType.isEmpty ? null : _eventType,
                          hint: const Text('Välj typ'),
                          items:
                              _eventTypes
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => _eventType = v!),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Välj event type'
                                      : null,
                          onSaved: (v) => _eventType = v!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 30 % av bredden
                      Expanded(
                        flex: 25,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Duration',
                            suffixText: 'min',
                          ),
                          value: _durationMinutes,
                          items:
                              <int>[
                                    20,
                                    25,
                                    30,
                                    40,
                                    45,
                                    50,
                                    60,
                                    75,
                                    90,
                                    100,
                                    120,
                                  ]
                                  .map(
                                    (min) => DropdownMenuItem(
                                      value: min,
                                      child: Text('$min'),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setState(() => _durationMinutes = v!),
                          validator: (v) => v == null ? 'Välj duration' : null,
                          onSaved: (v) => _durationMinutes = v!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Match Type & Opponent (endast om Match)
                  if (_eventType == 'Match') ...[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Match Type',
                      ),
                      items:
                          _matchTypes
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _matchType = v!),
                      validator:
                          (v) =>
                              v == null || v.isEmpty ? 'Välj match type' : null,
                      onSaved: (v) => _matchType = v!,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 80,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Opponent',
                            ),
                            onSaved: (v) => _opponent = v ?? '',
                            validator: (v) {
                              if (_eventType == 'Match' &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Fyll i motståndare';
                              }
                              return null;
                            },
                          ),
                        ),
                        // checkbox för att sätta _isHome till true om det är hemmamatch
                        Expanded(
                          flex: 20,
                          child: Column(
                            children: [
                              Checkbox(
                                value: _isHome,
                                onChanged: (checked) {
                                  if (checked == null) return;
                                  setState(() {
                                    _isHome = checked;
                                  });
                                },
                              ),
                              const Text('Hemma'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Datum & samlingstid
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Event Date'),
                          subtitle: Text(dateText),
                          onTap: _pickEventDateTime,
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('Gathering Time'),
                          subtitle: Text(timeText),
                          onTap: _pickGatheringTime,
                        ),
                      ),
                    ],
                  ),

                  // Återkommande och slutdatum (endast Träning)
                  if (_eventType == 'Träning')
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Återkommande',
                            ),
                            value: _recurrence,
                            items:
                                _recurrenceOptions
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() => _recurrence = v!),
                            validator:
                                (v) =>
                                    v == null || v.isEmpty
                                        ? 'Välj recurrence'
                                        : null,
                            onSaved: (v) => _recurrence = v!,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _pickEndDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Slutdatum',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(endDateText),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  // Beskrivning
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    onSaved: (v) => _description = v ?? '',
                  ),
                  const SizedBox(height: 12),

                  // Plan och Område
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Plan'),
                          onSaved: (v) => _pitch = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Område',
                          ),
                          onSaved: (v) => _area = v ?? '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stad
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Stad'),
                    onSaved: (v) => _town = v ?? '',
                  ),
                  const SizedBox(height: 12),

                  // Coach-anteckning
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Coach Note'),
                    maxLines: 2,
                    onSaved: (v) => _coachNote = v ?? '',
                  ),
                  const SizedBox(height: 24),

                  // Knappar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                        child: const Text('Avbryt'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Text(_isLoading ? 'Sparar...' : 'Skapa Event'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
