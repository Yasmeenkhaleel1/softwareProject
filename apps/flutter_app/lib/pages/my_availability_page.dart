// lib/pages/expert/my_availability_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class MyAvailabilityPage extends StatefulWidget {
  const MyAvailabilityPage({super.key});

  @override
  State<MyAvailabilityPage> createState() => _MyAvailabilityPageState();
}

class _MyAvailabilityPageState extends State<MyAvailabilityPage> {
  static const baseUrl = "http://localhost:5000/api";

  bool loading = true;
  bool saving = false;

  final List<Map<String, dynamic>> days = [
    {"dow": 0, "label": "Sunday", "start": "09:00", "end": "17:00", "active": false},
    {"dow": 1, "label": "Monday", "start": "09:00", "end": "17:00", "active": false},
    {"dow": 2, "label": "Tuesday", "start": "09:00", "end": "17:00", "active": false},
    {"dow": 3, "label": "Wednesday", "start": "09:00", "end": "17:00", "active": false},
    {"dow": 4, "label": "Thursday", "start": "09:00", "end": "17:00", "active": false},
    {"dow": 5, "label": "Friday", "start": "09:00", "end": "17:00", "active": false},
    {"dow": 6, "label": "Saturday", "start": "09:00", "end": "17:00", "active": false},
  ];

  int bufferMinutes = 15;
  List<Map<String, dynamic>> exceptions = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailability();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchAvailability() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse("$baseUrl/expert/availability/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          bufferMinutes = data['bufferMinutes'] ?? 15;

          if (data['rules'] != null) {
            for (var r in data['rules']) {
              final idx = days.indexWhere((d) => d['dow'] == r['dow']);
              if (idx != -1) {
                days[idx]['start'] = r['start'];
                days[idx]['end'] = r['end'];
                days[idx]['active'] = true;
              }
            }
          }

          if (data['exceptions'] != null) {
            exceptions = List<Map<String, dynamic>>.from(data['exceptions']);
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching availability: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _saveAvailability() async {
    setState(() => saving = true);
    try {
      final token = await _getToken();
      final rules = days
          .where((d) => d['active'] == true)
          .map((d) => {"dow": d["dow"], "start": d["start"], "end": d["end"]})
          .toList();

      final body = {
        "bufferMinutes": bufferMinutes,
        "rules": rules,
        "exceptions": exceptions
      };

      final res = await http.put(
        Uri.parse("$baseUrl/expert/availability/me"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

     if (res.statusCode == 200) {
  final data = jsonDecode(res.body);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(data['message'] ?? "✅ Saved successfully!"),
      backgroundColor: data['message'].toString().contains("⚠️")
          ? Colors.orangeAccent
          : Colors.green,
    ),
  );
}
 else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Failed to save: ${res.body}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Save error: $e");
    } finally {
      setState(() => saving = false);
    }
  }

  Future<void> _pickTime(Map<String, dynamic> day, bool isStart) async {
    final parts = (isStart ? day['start'] : day['end']).split(":");
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? "Select Start Time" : "Select End Time",
    );
    if (picked != null) {
      final formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      setState(() {
        if (isStart) {
          day['start'] = formatted;
        } else {
          day['end'] = formatted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Availability"),
        backgroundColor: const Color(0xFF007B9E),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Weekly Schedule",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      ..._buildWeekDays(),
                      const SizedBox(height: 25),
                      _buildCalendarSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildBufferSelector(),
                const SizedBox(height: 25),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWeekDays() {
    return days.map((d) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Switch(
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade300,
                      activeThumbColor: const Color(0xFF00A1C9),
                      value: d['active'],
                      onChanged: (v) => setState(() => d['active'] = v),
                    ),
                    Text(
                      d['label'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: d['active'] ? Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeField(d, true),
                    const Text("—"),
                    _buildTimeField(d, false),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTimeField(Map<String, dynamic> d, bool isStart) {
    return InkWell(
      onTap: d['active'] ? () => _pickTime(d, isStart) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: d['active'] ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          isStart ? d['start'] : d['end'],
          style: TextStyle(
            fontSize: 14,
            color: d['active'] ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Calendar Overview",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        _buildCalendarView(),
        const SizedBox(height: 30),
        _buildExceptionsSection(),
      ],
    );
  }

  Widget _buildCalendarView() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: DateTime.now(),
          headerStyle: const HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: const Color(0xFF00A1C9).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, date, _) {
              final dateStr =
                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              final ex = exceptions.firstWhere(
                (e) => e['date'] == dateStr,
                orElse: () => {},
              );

              if (ex.isNotEmpty) {
                final isOff = ex['off'] == true;
                final color = isOff
                    ? Colors.redAccent.withOpacity(0.8)
                    : Colors.amber.withOpacity(0.9);
                return InkWell(
                  onTap: () => _showDayDetails(dateStr, ex),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        "${date.day}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  void _showDayDetails(String date, Map<String, dynamic> ex) {
    final isOff = ex['off'] == true;
    final windows = List<Map<String, String>>.from(ex['windows'] ?? []);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Details for $date"),
        content: isOff
            ? const Text("This day is marked as OFF (no bookings).")
            : windows.isNotEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: windows
                        .map((w) => Text("• ${w['start']} – ${w['end']}"))
                        .toList(),
                  )
                : const Text("This day has no special hours."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildExceptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Special Dates (Days Off / Custom Windows)",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        ...exceptions.map((e) => _buildExceptionTile(e)),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _addExceptionDialog,
          icon: const Icon(Icons.add),
          label: const Text("Add Special Date"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007B9E),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildExceptionTile(Map<String, dynamic> e) {
    final isOff = e['off'] == true;
    final date = e['date'];
    final windows = e['windows'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(
          "$date  ${isOff ? "(Day Off)" : ""}",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: !isOff && windows.isNotEmpty
            ? Text("Windows: ${windows.map((w) => "${w['start']}-${w['end']}").join(', ')}")
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => setState(() => exceptions.remove(e)),
        ),
      ),
    );
  }

  Future<void> _addExceptionDialog() async {
    DateTime? selectedDate;
    bool isOff = false;
    List<Map<String, String>> windows = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Special Date"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 2),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: Text(selectedDate == null
                        ? "Select Date"
                        : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007B9E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(value: isOff, onChanged: (v) => setState(() => isOff = v ?? false)),
                      const Text("Mark as day off"),
                    ],
                  ),
                  if (!isOff)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Custom Windows:"),
                        ...windows.map((w) => Text("${w['start']} - ${w['end']}")),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Add Window"),
                          onPressed: () async {
                            final result = await _addWindowDialog();
                            if (result != null) setState(() => windows.add(result));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007B9E),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  if (selectedDate == null) return;
                  final dateStr =
                      "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
                  setState(() {
                    exceptions.add({"date": dateStr, "off": isOff, "windows": isOff ? [] : windows});
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007B9E)),
                child: const Text("Save"),
              ),
            ],
          );
        });
      },
    );
    setState(() {}); // تحديث التقويم بعد الإضافة
  }

  Future<Map<String, String>?> _addWindowDialog() async {
    String start = "09:00";
    String end = "17:00";
    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Custom Window"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: const InputDecoration(labelText: "Start (HH:MM)"), onChanged: (v) => start = v),
              TextField(decoration: const InputDecoration(labelText: "End (HH:MM)"), onChanged: (v) => end = v),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {"start": start, "end": end}),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007B9E)),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBufferSelector() {
    return Row(
      children: [
        const Text("Break between bookings (minutes):"),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: bufferMinutes,
          onChanged: (v) => setState(() => bufferMinutes = v!),
          items: const [
            DropdownMenuItem(value: 0, child: Text("0")),
            DropdownMenuItem(value: 10, child: Text("10")),
            DropdownMenuItem(value: 15, child: Text("15")),
            DropdownMenuItem(value: 30, child: Text("30")),
            DropdownMenuItem(value: 60, child: Text("60")),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        label: Text(saving ? "Saving..." : "Save Changes"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007B9E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: saving ? null : _saveAvailability,
      ),
    );
  }
}
