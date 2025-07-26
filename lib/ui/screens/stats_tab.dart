import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../infrastructure/repositories/event_repository.dart';
import '../../domain/models/stats.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/event_providers.dart';

/// A simple card widget showing a statistic with title and value.
class StatsCard extends StatelessWidget {
  final String title;
  final String value;

  const StatsCard({Key? key, required this.title, required this.value})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Card(
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// The main statistics tab for TeamZone app, split into two tabs: träning and matcher.
class StatsTab extends ConsumerStatefulWidget {
  const StatsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<StatsTab> {
  String _selectedPeriod = '7d';

  /// Här sätter du den sträng som verkligen ska skickas
  /// när användaren valde "season".
  /// Exempel: "2024/2025" eller vad din backend förväntar sig.
  late final int currentSeason;

  @override
  void initState() {
    super.initState();
    currentSeason =
        DateTime.now().year; // TODO: ersätt med din faktiska season‐kod
  }

  /// Används bara för att visa etiketter i dropdownen.
  Map<String, String> get _periodLabels {
    final currentYear = DateTime.now().year.toString();
    final pastYears = List.generate(
      3,
      (i) => (DateTime.now().year - 1 - i).toString(),
    );

    return {
      '7d': '7 dagar',
      '30d': '30 dagar',
      'season': currentYear, // visas som t.ex. "2025"
      for (var y in pastYears) y: y, // "2024", "2023", "2022"
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final session = ref.watch(userSessionProvider(auth.currentUser?.uid ?? ''));
    final teamId = session.currentTeamId;

    // Hämta repository från Riverpod
    final repo = ref.read(eventRepositoryProvider);

    // Om user valt 'season', använd currentSeason i repot
    final periodKey =
        _selectedPeriod == 'season' ? currentSeason : _selectedPeriod;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistik'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Träning'), Tab(text: 'Matcher')],
          ),
          actions: [
            DropdownButton<String>(
              value: _selectedPeriod,
              items:
                  _periodLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _selectedPeriod = val);
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildStatsView(
              context,
              repo,
              teamId,
              'Träning',
              periodKey.toString(),
            ),
            _buildStatsView(
              context,
              repo,
              teamId,
              'Match',
              periodKey.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsView(
    BuildContext context,
    EventRepository repo,
    String teamId,
    String eventType,
    String periodKey,
  ) {
    return SafeArea(
      child: StreamBuilder<Stats>(
        stream: repo.streamTeamStats(teamId, periodKey, eventType),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Ingen statistik tillgänglig'));
          }
          final stats = snapshot.data!;

          // Beräkna "from" baserat på _selectedPeriod (inte periodKey!):
          final now = DateTime.now();
          DateTime from;
          if (_selectedPeriod.endsWith('d')) {
            final days = int.parse(_selectedPeriod.replaceAll('d', ''));
            from = now.subtract(Duration(days: days));
          } else {
            // antingen 'season' eller ett tidigare årtal
            final year =
                _selectedPeriod == 'season'
                    ? DateTime.now().year
                    : int.parse(_selectedPeriod);
            from = DateTime(year, 1, 1);
          }

          // --- Närvaro ---
          final totalSessions = stats.attendance.length;
          final avgAttendance =
              totalSessions > 0
                  ? stats.attendance
                          .map((e) => e.count)
                          .reduce((a, b) => a + b) /
                      totalSessions
                  : 0;
          final attendanceSpots =
              stats.attendance
                  .map((e) => FlSpot(e.dayIndex.toDouble(), e.count.toDouble()))
                  .toList()
                ..sort((a, b) => a.x.compareTo(b.x));
          // x-axel för närvaro: max 10 etiketter
          final attXMin =
              attendanceSpots.isNotEmpty ? attendanceSpots.first.x : 0.0;
          final attXMax =
              attendanceSpots.isNotEmpty ? attendanceSpots.last.x : 0.0;
          final attInterval =
              (attXMax - attXMin) <= 10
                  ? 1.0
                  : ((attXMax - attXMin) / 9).ceilToDouble();
          final topSessions = List.from(stats.attendance)
            ..sort((a, b) => b.count.compareTo(a.count));

          // --- Mål ---
          final totalOurGoals =
              stats.scores.isNotEmpty
                  ? stats.scores.map((s) => s.ourScore).reduce((a, b) => a + b)
                  : 0;
          final totalOppGoals =
              stats.scores.isNotEmpty
                  ? stats.scores
                      .map((s) => s.opponentScore)
                      .reduce((a, b) => a + b)
                  : 0;

          // Kumulativ kurva
          final sortedScores = List<ScoreCount>.from(stats.scores)
            ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
          double cumOur = 0, cumOpp = 0;
          final cumOurSpots = <FlSpot>[];
          final cumOppSpots = <FlSpot>[];
          for (var s in sortedScores) {
            cumOur += s.ourScore;
            cumOpp += s.opponentScore;
            cumOurSpots.add(FlSpot(s.dayIndex.toDouble(), cumOur));
            cumOppSpots.add(FlSpot(s.dayIndex.toDouble(), cumOpp));
          }
          // x-axel för mål: max 10 etiketter
          final goalXMin = cumOurSpots.isNotEmpty ? cumOurSpots.first.x : 0.0;
          final goalXMax = cumOurSpots.isNotEmpty ? cumOurSpots.last.x : 0.0;
          final goalInterval =
              (goalXMax - goalXMin) <= 10
                  ? 1.0
                  : ((goalXMax - goalXMin) / 9).ceilToDouble();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // --- NÄRVARO-SEKTION ---
              Text('Närvaro', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatsCard(title: 'Antal sessioner', value: '$totalSessions'),
                  StatsCard(
                    title: 'Genomsnittlig närvaro',
                    value: '${avgAttendance.toStringAsFixed(1)} %',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Närvarotrend
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Närvarotrend',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            minX: attXMin,
                            maxX: attXMax,
                            lineTouchData: LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: attendanceSpots,
                                isCurved: true,
                                preventCurveOverShooting: true,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: attInterval,
                                  getTitlesWidget: (
                                    double value,
                                    TitleMeta meta,
                                  ) {
                                    final dayIndex = value.toInt();
                                    final date = from.add(
                                      Duration(days: dayIndex),
                                    );
                                    return Text(
                                      DateFormat('d/M').format(date),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: 1,
                                  getTitlesWidget: (
                                    double value,
                                    TitleMeta meta,
                                  ) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Top 5 närvaro
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top 5 sessioner (närvaro)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Divider(),
                      ...topSessions.take(5).map((e) {
                        final sessionDate = from.add(
                          Duration(days: e.dayIndex),
                        );
                        final formatted = DateFormat(
                          'EEEE d/M',
                          'sv_SE',
                        ).format(sessionDate);
                        return ListTile(
                          title: Text(formatted),
                          trailing: Text('${e.count}'),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // --- MÅL-SEKTION (endast för Matcher) ---
              if (eventType == 'Match') ...[
                const SizedBox(height: 24),
                Text('Mål', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatsCard(title: 'Gjorda mål', value: '$totalOurGoals'),
                    StatsCard(title: 'Insläppta mål', value: '$totalOppGoals'),
                  ],
                ),
                const SizedBox(height: 16),
                // Kumulativ måltrend
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kumulativ måltrend',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              minX: goalXMin,
                              maxX: goalXMax,
                              lineTouchData: LineTouchData(enabled: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: cumOurSpots,
                                  isCurved: true,
                                  barWidth: 2,
                                  dotData: FlDotData(show: false),
                                  color: Colors.blue,
                                ),
                                LineChartBarData(
                                  spots: cumOppSpots,
                                  isCurved: true,
                                  barWidth: 2,
                                  dotData: FlDotData(show: false),
                                  color: Colors.red,
                                ),
                              ],
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    interval: goalInterval,
                                    getTitlesWidget: (
                                      double value,
                                      TitleMeta meta,
                                    ) {
                                      final dayIndex = value.toInt();
                                      final date = from.add(
                                        Duration(days: dayIndex),
                                      );
                                      return Text(
                                        DateFormat('d/M').format(date),
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 3,
                                    getTitlesWidget: (
                                      double value,
                                      TitleMeta meta,
                                    ) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendDot(Colors.blue),
                            const SizedBox(width: 4),
                            const Text(
                              'Kumulativa gjorda mål',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 16),
                            _buildLegendDot(Colors.red),
                            const SizedBox(width: 4),
                            const Text(
                              'Kumulativa insläppta mål',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Hjälpmetod för legend‐prick
Widget _buildLegendDot(Color color) {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
