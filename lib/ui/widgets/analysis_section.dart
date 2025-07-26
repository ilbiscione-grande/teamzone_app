// lib/ui/widgets/analysis_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/event_providers.dart';
import '../../infrastructure/repositories/analysis_repository.dart';

class AnalysisSection extends ConsumerStatefulWidget {
  final String eventId;
  const AnalysisSection({Key? key, required this.eventId}) : super(key: key);

  @override
  ConsumerState<AnalysisSection> createState() => _AnalysisSectionState();
}

class _AnalysisSectionState extends ConsumerState<AnalysisSection> {
  late PageController _pageController;
  int _currentPage = 0;

  // Lokala override-state för dropdowns
  String? _selFormationBefore, _selFormationDuring, _selFormationAfter;
  String? _selPressersBefore, _selPressersDuring, _selPressersAfter;
  String? _selPressBefore, _selPressDuring, _selPressAfter;

  // Lokala override-state för fokusfält (Before)
  String? _selFocus1Before, _selFocus2Before, _selFocus3Before;

  static const List<String> _formationOptions = [
    '4-3-3',
    '4-4-2',
    '3-5-2',
    '5-3-2',
  ];
  static const List<String> _presserOptions = ['1', '2', '3', '4'];
  static const List<String> _pressOptions = ['Hög', 'Medium', 'Låg'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawAsync = ref.watch(analysisProvider(widget.eventId));
    return rawAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (err, _) => Center(
            child: Text(
              'Kunde inte ladda analys: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
      data: (rawData) {
        final metrics = rawData ?? {};
        final before = <String, dynamic>{},
            during = <String, dynamic>{},
            after = <String, dynamic>{};
        metrics.forEach((k, v) {
          if (k.startsWith('before_'))
            before[k.substring('before_'.length)] = v;
          if (k.startsWith('during_'))
            during[k.substring('during_'.length)] = v;
          if (k.startsWith('after_')) after[k.substring('after_'.length)] = v;
        });

        return Column(
          children: [
            _buildPageIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // <-- Disablerar svepning
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPhasePage(
                    title: 'Innan matchen',
                    prefix: 'before_',
                    extraData: before,
                    selFormation: _selFormationBefore,
                    selPressers: _selPressersBefore,
                    selPress: _selPressBefore,
                  ),
                  _buildPhasePage(
                    title: 'Under matchen',
                    prefix: 'during_',
                    extraData: during,
                    selFormation: _selFormationDuring,
                    selPressers: _selPressersDuring,
                    selPress: _selPressDuring,
                  ),
                  _buildPhasePage(
                    title: 'Efter matchen',
                    prefix: 'after_',
                    extraData: after,
                    selFormation: _selFormationAfter,
                    selPressers: _selPressersAfter,
                    selPress: _selPressAfter,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhasePage({
    required String title,
    required String prefix,
    required Map<String, dynamic> extraData,
    required String? selFormation,
    required String? selPressers,
    required String? selPress,
  }) {
    // DISPLAY: formation kan vara null för placeholder
    final displayFormation = selFormation ?? extraData['formation']?.toString();
    // DISPLAY: pressers & press får null om inget sparat
    final displayPressers = selPressers ?? extraData['pressers']?.toString();
    final displayPress = selPress ?? extraData['press']?.toString();

    // DISPLAY: fokuspunkter (endast before)
    final displayFocus1 =
        prefix == 'before_'
            ? (_selFocus1Before ?? extraData['focus1']?.toString() ?? '')
            : '';
    final displayFocus2 =
        prefix == 'before_'
            ? (_selFocus2Before ?? extraData['focus2']?.toString() ?? '')
            : '';
    final displayFocus3 =
        prefix == 'before_'
            ? (_selFocus3Before ?? extraData['focus3']?.toString() ?? '')
            : '';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        children: [
          // TITEL
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 1) Formation med placeholder
          DropdownButtonFormField<String?>(
            decoration: const InputDecoration(labelText: 'Formation'),
            value: displayFormation,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Välj formation'),
              ),
              ..._formationOptions.map(
                (f) => DropdownMenuItem<String?>(value: f, child: Text(f)),
              ),
            ],
            onChanged: (v) {
              // v == null är placeholder → ignorera
              if (v == null || v == displayFormation) return;
              setState(() {
                if (prefix == 'before_') _selFormationBefore = v;
                if (prefix == 'during_') _selFormationDuring = v;
                if (prefix == 'after_') _selFormationAfter = v;
              });
              _saveField(prefix, 'formation', v);
            },
          ),
          const SizedBox(height: 12),

          // 2) Pressers med placeholder
          DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: 'Antal som pressar högt/hårt',
            ),
            value: displayPressers,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Välj antal pressers'),
              ),
              ..._presserOptions.map(
                (n) => DropdownMenuItem<String?>(value: n, child: Text(n)),
              ),
            ],
            onChanged: (v) {
              if (v == null || v == displayPressers) return;
              setState(() {
                if (prefix == 'before_') _selPressersBefore = v;
                if (prefix == 'during_') _selPressersDuring = v;
                if (prefix == 'after_') _selPressersAfter = v;
              });
              _saveField(prefix, 'pressers', v);
            },
          ),
          const SizedBox(height: 12),

          // 3) Pressnivå med placeholder
          DropdownButtonFormField<String?>(
            decoration: const InputDecoration(labelText: 'Pressnivå'),
            value: displayPress,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Välj pressnivå'),
              ),
              ..._pressOptions.map(
                (p) => DropdownMenuItem<String?>(value: p, child: Text(p)),
              ),
            ],
            onChanged: (v) {
              if (v == null || v == displayPress) return;
              setState(() {
                if (prefix == 'before_') _selPressBefore = v;
                if (prefix == 'during_') _selPressDuring = v;
                if (prefix == 'after_') _selPressAfter = v;
              });
              _saveField(prefix, 'press', v);
            },
          ),

          // FOKUSPUNKTER (endast innan)
          if (prefix == 'before_') ...[
            const SizedBox(height: 24),
            Text(
              'Fokuspunkter',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: displayFocus1,
              decoration: const InputDecoration(labelText: 'Fokus 1'),
              onChanged: (v) {
                if (v == displayFocus1) return;
                setState(() => _selFocus1Before = v);
                _saveField(prefix, 'focus1', v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: displayFocus2,
              decoration: const InputDecoration(labelText: 'Fokus 2'),
              onChanged: (v) {
                if (v == displayFocus2) return;
                setState(() => _selFocus2Before = v);
                _saveField(prefix, 'focus2', v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: displayFocus3,
              decoration: const InputDecoration(labelText: 'Fokus 3'),
              onChanged: (v) {
                if (v == displayFocus3) return;
                setState(() => _selFocus3Before = v);
                _saveField(prefix, 'focus3', v);
              },
            ),
            const Divider(height: 32),
          ] else
            const Divider(height: 32),

          // Övrig data
          ...extraData.entries
              .where((e) {
                if (e.key == 'formation' ||
                    e.key == 'pressers' ||
                    e.key == 'press')
                  return false;
                if (prefix == 'before_' &&
                    (e.key == 'focus1' ||
                        e.key == 'focus2' ||
                        e.key == 'focus3'))
                  return false;
                return true;
              })
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(e.value.toString()),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Future<void> _saveField(String prefix, String field, dynamic value) async {
    try {
      await ref
          .read(analysisRepositoryProvider)
          .updateField(
            eventId: widget.eventId,
            field: '$prefix$field',
            value: value,
          );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte spara $prefix$field: $e')),
      );
    }
  }

  Widget _buildPageIndicator() {
    final labels = ['Innan', 'Under', 'Efter'];
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final selected = _currentPage == i;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: () {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentPage = i);
              },
              style: TextButton.styleFrom(
                backgroundColor:
                    selected
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color:
                      selected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
