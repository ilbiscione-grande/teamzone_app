// lib/features/home/edit_event_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/my_event.dart';
import '../../core/providers/firestore_providers.dart';

class EditEventPage extends ConsumerStatefulWidget {
  final MyEvent event;
  const EditEventPage({Key? key, required this.event}) : super(key: key);

  @override
  ConsumerState<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends ConsumerState<EditEventPage> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _start;
  late int _durationMinutes;
  late String? _area;
  late String? _pitch;
  late String? _town;
  late String _description;
  DateTime? _gatheringTime;
  late String? _coachNote;
  late String _opponent;
  late String? _matchType;
  late bool _isHome;
  late int _ourGoals;
  late int _opponentGoals;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _start = e.start;
    _durationMinutes = e.durationMinutes;
    _area = e.area;
    _pitch = e.pitch;
    _town = e.town;
    _description = e.description;
    _gatheringTime = e.gatheringTime;
    _coachNote = e.coachNote;
    _opponent = e.opponent;
    _matchType = e.matchType;
    _isHome = e.isHome;
    _ourGoals = e.ourGoals ?? -1;
    _opponentGoals = e.opponentGoals ?? -1;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final db = ref.read(firestoreProvider);
    final docRef = db.collection('events').doc(widget.event.id);

    final dataToUpdate = {
      'eventDate': Timestamp.fromDate(_start),
      'duration': _durationMinutes,
      'area': _area,
      'pitch': _pitch,
      'town': _town,
      'description': _description,
      'gatheringTime':
          _gatheringTime != null ? Timestamp.fromDate(_gatheringTime!) : null,
      'coachNote': _coachNote,
      'opponent': _opponent,
      'matchType': _matchType,
      'isHome': _isHome,
    };
    if (_ourGoals >= 0) dataToUpdate['ourScore'] = _ourGoals;
    if (_opponentGoals >= 0) dataToUpdate['opponentScore'] = _opponentGoals;

    await docRef.update(dataToUpdate);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event uppdaterat')));
  }

  Future<void> _confirmAndDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Bekräfta radering'),
            content: const Text(
              'Är du säker på att du vill ta bort det här eventet? Detta går inte att ångra.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Ta bort'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // 1) Töm Firestore
      await ref
          .read(firestoreProvider)
          .collection('events')
          .doc(widget.event.id)
          .delete();

      // 2) Poppa EditEventPage och skicka ingen retur‑värde
      Navigator.of(context).pop();

      // 2) Poppa EventDetailsPage och skicka ingen retur‑värde
      Navigator.of(context).pop();

      // 3) Visa ev. snackbar på sidan du kommer tillbaka till
      //    (ScaffoldMessenger.of(context) pekar nu på föregående sida)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event borttaget')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redigera event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Ta bort event',
            onPressed: _confirmAndDelete,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Spara ändringar',
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Motståndare
              TextFormField(
                initialValue: _opponent,
                decoration: const InputDecoration(labelText: 'Motståndare'),
                onSaved: (v) => _opponent = v ?? '',
              ),
              const SizedBox(height: 12),

              // Starttid
              const Text('Starttid'),
              TextButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_start),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _start = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(_start),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),

              // Samlingstid
              const Text('Samlingstid'),
              TextButton(
                onPressed: () async {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime:
                        _gatheringTime != null
                            ? TimeOfDay.fromDateTime(_gatheringTime!)
                            : const TimeOfDay(hour: 0, minute: 0),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _gatheringTime = DateTime(
                        _start.year,
                        _start.month,
                        _start.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  }
                },
                child: Text(
                  _gatheringTime != null
                      ? DateFormat('HH:mm').format(_gatheringTime!)
                      : 'Välj tid',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),

              // Längd
              TextFormField(
                initialValue: '$_durationMinutes',
                decoration: const InputDecoration(labelText: 'Längd (minuter)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Fyll i längd';
                  if (int.tryParse(v) == null) return 'Ogiltigt nummer';
                  return null;
                },
                onSaved: (v) => _durationMinutes = int.parse(v!),
              ),
              const SizedBox(height: 12),

              // Pitch
              TextFormField(
                initialValue: _pitch,
                decoration: const InputDecoration(
                  labelText: 'Plan (träning/match)',
                ),
                onSaved: (v) => _pitch = v,
              ),
              const SizedBox(height: 12),

              // Area + Town
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _area,
                      decoration: const InputDecoration(labelText: 'Område'),
                      onSaved: (v) => _area = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _town,
                      decoration: const InputDecoration(labelText: 'Ort'),
                      onSaved: (v) => _town = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Coachnotering
              TextFormField(
                initialValue: _coachNote,
                decoration: const InputDecoration(labelText: 'Coachnotering'),
                onSaved: (v) => _coachNote = v,
              ),
              const SizedBox(height: 12),

              // Matchtyp
              TextFormField(
                initialValue: _matchType,
                decoration: const InputDecoration(labelText: 'Matchtyp'),
                onSaved: (v) => _matchType = v,
              ),
              const SizedBox(height: 12),

              // Mål
              Row(
                children: [
                  // Våra mål
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Gjorda mål'),
                        const SizedBox(height: 8),
                        Container(
                          height: 100,
                          width: 75,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: _ourGoals >= 0 ? _ourGoals : 0,
                            ),
                            itemExtent: 32.0,
                            onSelectedItemChanged: (value) {
                              setState(() => _ourGoals = value);
                            },
                            children: List.generate(
                              21,
                              (i) => Center(child: Text('$i')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Motståndarens mål
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Insläppta mål'),
                        const SizedBox(height: 8),
                        Container(
                          height: 100,
                          width: 75,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem:
                                  _opponentGoals >= 0 ? _opponentGoals : 0,
                            ),
                            itemExtent: 32.0,
                            onSelectedItemChanged: (value) {
                              setState(() => _opponentGoals = value);
                            },
                            children: List.generate(
                              21,
                              (i) => Center(child: Text('$i')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hemma/Borta
              Row(
                children: [
                  const Text('Hemma/Borta:'),
                  const SizedBox(width: 12),
                  DropdownButton<bool>(
                    value: _isHome,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Hemma')),
                      DropdownMenuItem(value: false, child: Text('Borta')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _isHome = val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
