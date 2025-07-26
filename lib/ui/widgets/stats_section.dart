// lib/widgets/stats_section.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/stats.dart';

class StatsSection extends StatelessWidget {
  final Stream<Stats> statsStream;
  const StatsSection({Key? key, required this.statsStream}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Stats>(
      stream: statsStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return const Center(child: Text('Kunde inte ladda statistik'));
        }
        final stats = snap.data!;
        // Exempel: en enkel stapeldiagram över närvaro
        return Padding(
          padding: const EdgeInsets.all(16),
          child: BarChart(
            BarChartData(
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: true)),
              ),
              barGroups: stats.attendance.map((e) {
                return BarChartGroupData(
                  x: e.dayIndex,
                  barRods: [BarChartRodData(toY: e.count.toDouble())],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
