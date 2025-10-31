import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartCard extends StatelessWidget {
  final List data;

  const ChartCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data
        .map((e) => FlSpot(
            (e['month'] ?? 0).toDouble(),
            (e['count'] ?? 0).toDouble()))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)
        ],
      ),
      height: 300,
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(show: true),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: const Color(0xFF62C6D9),
              isCurved: true,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF62C6D9).withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
