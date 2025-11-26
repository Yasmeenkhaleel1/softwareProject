import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';

class CustomerCalendarViewPage extends StatefulWidget {
  final String expertId; // ExpertProfile._id
  final String expertName;

  const CustomerCalendarViewPage({
    super.key,
    required this.expertId,
    required this.expertName,
  });

  @override
  State<CustomerCalendarViewPage> createState() => _CustomerCalendarViewPageState();
}

class _CustomerCalendarViewPageState extends State<CustomerCalendarViewPage> {
  final baseUrl = ApiConfig.baseUrl;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, dynamic> _calendarData = {};
  List<dynamic> _slotsForSelectedDay = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchCalendarStatus();
  }

  Future<void> _fetchCalendarStatus() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final from = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final to = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 30)));

      final uri = Uri.parse(
        "$baseUrl/api/public/experts/${widget.expertId}/calendar-status?from=$from&to=$to&durationMinutes=60",
      );

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _calendarData = {
            for (var d in data['days'] ?? [])
              d['date']: d
          };
          loading = false;
        });
      } else {
        throw Exception("HTTP ${res.statusCode}");
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Color _getDayColor(String status) {
    switch (status) {
      case "OFF":
        return Colors.redAccent;
      case "FULL":
        return Colors.grey;
      case "AVAILABLE":
        return Colors.green;
      default:
        return Colors.transparent;
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final dayKey = DateFormat('yyyy-MM-dd').format(selectedDay);
    final info = _calendarData[dayKey];
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _slotsForSelectedDay = info != null ? (info['slots'] ?? []) : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Calendar - ${widget.expertName}"),
        backgroundColor: Colors.teal.shade600,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text("Error: $error"))
              : Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.now().subtract(const Duration(days: 1)),
                      lastDay: DateTime.now().add(const Duration(days: 60)),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: _onDaySelected,
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final dateKey =
                              DateFormat('yyyy-MM-dd').format(day);
                          final dayInfo = _calendarData[dateKey];
                          if (dayInfo == null) return Center(child: Text("${day.day}"));
                          final color = _getDayColor(dayInfo['status']);
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color, width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${day.day}",
                              style: TextStyle(
                               color: color,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                        todayBuilder: (context, day, focusedDay) =>
                            Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade300.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text("${day.day}",
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const Divider(),
                    if (_selectedDay != null)
                      Expanded(
                        child: _slotsForSelectedDay.isEmpty
                            ? const Center(
                                child: Text("No available slots for this day."),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _slotsForSelectedDay.length,
                                itemBuilder: (context, i) {
                                  final slot = _slotsForSelectedDay[i];
                                  final start = DateTime.parse(slot["startAt"]).toLocal();
                                  final end = DateTime.parse(slot["endAt"]).toLocal();
                                  final timeRange =
                                      "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - "
                                      "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
                                  return Card(
                                    color: slot["available"]
                                        ? Colors.white
                                        : Colors.grey.shade200,
                                    child: ListTile(
                                      title: Text(timeRange),
                                      trailing: slot["available"]
                                          ? ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.teal.shade600,
                                              ),
                                              onPressed: () {
                                                // TODO: integrate booking/payment here
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                  content: Text(
                                                      "Selected slot: $timeRange"),
                                                ));
                                              },
                                              child: const Text("Book"),
                                            )
                                          : const Text(
                                              "Booked",
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                    ),
                                  );
                                },
                              ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Select a day to view available slots."),
                      )
                  ],
                ),
    );
  }
}
