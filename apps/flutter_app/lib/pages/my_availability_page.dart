// lib/pages/expert/my_availability_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // أضف هذه المكتبة لاستخدام kIsWeb
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class MyAvailabilityPage extends StatefulWidget {
  const MyAvailabilityPage({super.key});

  @override
  State<MyAvailabilityPage> createState() => _MyAvailabilityPageState();
}

class _MyAvailabilityPageState extends State<MyAvailabilityPage> {
  // ✅ دالة baseUrl ديناميكية للويب والموبايل
  String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5000";
    } else {
      // للموبايل (Android emulator)
      return "http://10.0.2.2:5000";
    }
  }

  String get apiBaseUrl => "$baseUrl/api"; // ✅ أضف هذا للراحة

  bool loading = true;
  bool saving = false;

  // 0 = Sun .. 6 = Sat
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

  // ============================
  // GET /expert/availability/me
  // ============================
  Future<void> _fetchAvailability() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse("$apiBaseUrl/expert/availability/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final av = data['availability'];

        if (av != null) {
          final int buf = av['bufferMinutes'] ?? 15;
          final List rules = av['rules'] ?? [];
          final List ex = av['exceptions'] ?? [];

          setState(() {
            bufferMinutes = buf;

            // reset days
            for (var d in days) {
              d['active'] = false;
              d['start'] = "09:00";
              d['end'] = "17:00";
            }

            // apply rules
            for (var r in rules) {
              final idx = days.indexWhere((d) => d['dow'] == r['dow']);
              if (idx != -1) {
                days[idx]['start'] = r['start'] ?? "09:00";
                days[idx]['end'] = r['end'] ?? "17:00";
                days[idx]['active'] = true;
              }
            }

            exceptions =
                List<Map<String, dynamic>>.from(ex.map((e) => Map<String, dynamic>.from(e)));
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching availability: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  // ============================
  // PUT /expert/availability/me
  // ============================
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
        Uri.parse("$apiBaseUrl/expert/availability/me"),
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
        await _fetchAvailability();
      } else {
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
      final formatted =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
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
        backgroundColor: const Color(0xFF62C6D9),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            // ✅ نلف الكل بـ SingleChildScrollView عشان ما يصير Overflow
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth >= 980;
                final bool isMobile = !kIsWeb && constraints.maxWidth < 700;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildWeeklyCard()),
                            const SizedBox(width: 24),
                            Expanded(flex: 5, child: _buildCalendarCard()),
                          ],
                        )
                      else ...[
                        _buildWeeklyCard(),
                        const SizedBox(height: 20),
                        _buildCalendarCard(),
                      ],
                      const SizedBox(height: 80), // مساحة للزرّ تحت
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
 bottomNavigationBar: SafeArea(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (context, c) {
        final bool mobile = c.maxWidth < 600;

        if (mobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBufferSelector(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildSaveButton(),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBufferSelector(),
            _buildSaveButton(),
          ],
        );
      },
    ),
  ),
),
);
  }

  // ============================
  // Weekly Schedule Card
  // ============================

  Widget _buildWeeklyCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Weekly Schedule",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Turn days ON to enable bookings, and adjust working hours for each day.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            ..._buildWeekDays(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWeekDays() {
    return days.map((d) {
      final bool active = d['active'] == true;
return Container(
  margin: const EdgeInsets.symmetric(vertical: 6),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: active ? const Color(0xFFE0F2FE) : Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: active ? const Color(0xFF38BDF8) : const Color(0xFFE5E7EB),
    ),
  ),
  child: LayoutBuilder(
    builder: (context, c) {
      final bool mobile = c.maxWidth < 500;

      // ================= MOBILE =================
      if (mobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Switch + Day
            Row(
              children: [
                Switch(
                  value: active,
                  activeColor: const Color(0xFF62C6D9),
                  onChanged: (v) => setState(() => d['active'] = v),
                ),
                Text(
                  d['label'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.black : Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  active ? "ON" : "OFF",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Time row
            Row(
              children: [
                Expanded(child: _buildTimeField(d, true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text("—"),
                ),
                Expanded(child: _buildTimeField(d, false)),
              ],
            ),
          ],
        );
      }

      // ================= WEB =================
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Switch(
                  value: active,
                  activeColor: const Color(0xFF62C6D9),
                  onChanged: (v) => setState(() => d['active'] = v),
                ),
                Text(
                  d['label'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildTimeField(d, true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text("—"),
                ),
                _buildTimeField(d, false),
              ],
            ),
          ),
        ],
      );
    },
  ),
);
 }).toList();
  }

  Widget _buildTimeField(Map<String, dynamic> d, bool isStart) {
    final bool active = d['active'] == true;
    return InkWell(
      onTap: active ? () => _pickTime(d, isStart) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFFBFDBFE) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(
              isStart ? d['start'] : d['end'],
              style: TextStyle(
                fontSize: 13,
                color: active ? const Color(0xFF111827) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // Calendar + Exceptions Card
  // ============================

  Widget _buildCalendarCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Calendar Overview",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Days with custom hours, days off, or weekly availability are highlighted.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            _buildCalendarView(),
            const SizedBox(height: 20),
            _buildExceptionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              color: const Color(0xFF62C6D9).withOpacity(0.25),
              shape: BoxShape.circle,
            ),
          ),
          // ✅ نلوّن:
          //  - Special Dates (exceptions) بألوان قوية
          //  - أيام الدوام / OFF حسب الـ weekly rules
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, date, _) {
              final dateStr =
                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              final ex = exceptions.firstWhere(
                (e) => e['date'] == dateStr,
                orElse: () => {},
              );

              // 1) لو فيه Exception لهذا اليوم → نلوّنه بقوة (أحمر/أصفر)
              if (ex.isNotEmpty) {
                final isOff = ex['off'] == true;
                final color = isOff
                    ? Colors.redAccent.withOpacity(0.9)
                    : Colors.amber.withOpacity(0.95);
                return InkWell(
                  onTap: () => _showDayDetails(dateStr, ex),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "${date.day}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }

              // 2) لو ما فيه Exception → نلوّن حسب Weekly rules
              final int dow = date.weekday % 7; // Monday=1..Sunday=7 → 0..6
              final dayRule =
                  days.firstWhere((d) => d['dow'] == dow, orElse: () => {});
              final bool isWorkingDay =
                  dayRule.isNotEmpty && dayRule['active'] == true;

              if (isWorkingDay) {
                // يوم دوام عادي
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${date.day}",
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              } else {
                // يوم OFF أسبوعي (بس نخفف لونه)
                return Center(
                  child: Text(
                    "${date.day}",
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              }
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
                    children:
                        windows.map((w) => Text("• ${w['start']} – ${w['end']}")).toList(),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        if (exceptions.isEmpty)
          const Text(
            "No special dates yet. Add days off or custom windows when needed.",
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          )
        else
          ...exceptions.map((e) => _buildExceptionTile(e)).toList(),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _addExceptionDialog,
          icon: const Icon(Icons.add),
          label: const Text("Add Special Date"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF62C6D9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          "$date  ${isOff ? "(Day Off)" : ""}",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: !isOff && windows.isNotEmpty
            ? Text(
                "Windows: ${windows.map((w) => "${w['start']}-${w['end']}").join(', ')}")
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => setState(() => exceptions.remove(e)),
        ),
      ),
    );
  }

  // ============================
  // Dialogs
  // ============================

  Future<void> _addExceptionDialog() async {
    DateTime? selectedDate;
    bool isOff = false;
    List<Map<String, String>> windows = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
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
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: Text(
                      selectedDate == null
                          ? "Select Date"
                          : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF62C6D9),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isOff,
                        onChanged: (v) => setStateDialog(() => isOff = v ?? false),
                      ),
                      const Text("Mark as day off"),
                    ],
                  ),
                  if (!isOff)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Custom Windows:"),
                        const SizedBox(height: 4),
                        ...windows
                            .map((w) => Text("• ${w['start']} - ${w['end']}"))
                            .toList(),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Add Window"),
                          onPressed: () async {
                            final result = await _addWindowDialog();
                            if (result != null) {
                              setStateDialog(() => windows.add(result));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62C6D9),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedDate == null) return;
                  final dateStr =
                      "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
                  setState(() {
                    exceptions.add({
                      "date": dateStr,
                      "off": isOff,
                      "windows": isOff ? [] : windows
                    });
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62C6D9),
                
                ),
                child: const Text(
                                   "Save",
                                    style: TextStyle(color: Colors.white),
                                 ),

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
              TextField(
                decoration:
                    const InputDecoration(labelText: "Start (HH:MM)"),
                onChanged: (v) => start = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "End (HH:MM)"),
                onChanged: (v) => end = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, {"start": start, "end": end}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF62C6D9),
               
              ),
              child: const Text(
                                 "Add",
                           style: TextStyle(color: Colors.white),
                                ),

            ),
          ],
        );
      },
    );
  }

  // ============================
  // Buffer + Save
  // ============================

  Widget _buildBufferSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Break between bookings:",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: bufferMinutes,
          onChanged: (v) => setState(() => bufferMinutes = v!),
          items: const [
            DropdownMenuItem(value: 0, child: Text("0 min")),
            DropdownMenuItem(value: 10, child: Text("10 min")),
            DropdownMenuItem(value: 15, child: Text("15 min")),
            DropdownMenuItem(value: 30, child: Text("30 min")),
            DropdownMenuItem(value: 60, child: Text("60 min")),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      icon: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save),
      label: Text(saving ? "Saving..." : "Save Changes"),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF62C6D9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      onPressed: saving ? null : _saveAvailability,
    );
  }
}