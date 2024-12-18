import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Расписание',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GroupListPage(),
    );
  }
}

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List results = [];
  bool isLoading = false;
  String searchTerm = '';
  String searchType = 'group';

  Future<void> search() async {
    if (searchTerm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите поисковый запрос')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse(
        'http://localhost:5000/api/search?term=$searchTerm&type=$searchType');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final newResults = json.decode(response.body);
        setState(() {
          results = newResults.where((result) =>
              result['label'].toString().toLowerCase().contains(searchTerm.toLowerCase())).toList();
        });
      } else {
        throw Exception('Failed to fetch results');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск групп и преподавателей'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => searchTerm = value,
              decoration: const InputDecoration(
                labelText: 'Введите поисковый запрос',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Группы'),
                selected: searchType == 'group',
                onSelected: (selected) {
                  setState(() {
                    searchType = 'group';
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Преподаватели'),
                selected: searchType == 'person',
                onSelected: (selected) {
                  setState(() {
                    searchType = 'person';
                  });
                },
              ),
            ],
          ),
          ElevatedButton(
            onPressed: search,
            child: const Text('Поиск'),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(results[index]['label'] ?? 'Нет названия'),
                  onTap: searchType == 'group'
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => searchType == 'group'
                            ? GroupSchedulePage(groupId: results[index]['id'], groupName: results[index]['label'])
                            : PersonSchedulePage(personId: results[index]['id'], personName: results[index]['label']),
                      ),
                    );
                  }
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PersonSchedulePage(
                          personId: results[index]['id'],
                          personName: results[index]['label'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class GroupSchedulePage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupSchedulePage(
      {super.key, required this.groupId, required this.groupName});

  @override
  State<GroupSchedulePage> createState() => _GroupSchedulePageState();
}

class _GroupSchedulePageState extends State<GroupSchedulePage> {
  List<Map<String, dynamic>> schedule = [];
  bool isLoading = true;

  Future<void> fetchSchedule() async {
    final start = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
    final end = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now().add(Duration(days: 7)));

    final url = Uri.parse(
        'http://localhost:5000/api/schedule/group/${widget.groupId}?start=$start&finish=$end&lng=1');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          schedule = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load schedule');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : schedule.isEmpty
          ? const Center(child: Text('Нет расписания для этой группы'))
          : ListView.builder(
        itemCount: schedule.length,
        itemBuilder: (context, index) {
          final item = schedule[index];
          return ListTile(
            title: Text(item['discipline'] ?? 'Нет названия'),
            subtitle: Text(
                '${item['date']} - ${item['beginLesson']} до ${item['endLesson']}'),
            trailing: Text(item['auditorium'] ?? 'Нет данных'),
            onTap: () {
              // Здесь можно добавить логику для более детального просмотра
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Дисциплина: ${item['discipline'] ?? 'Нет данных'}'),
                        Text('Аудитория: ${item['auditorium'] ?? 'Нет данных'}'),
                        Text('Здание: ${item['building'] ?? 'Нет данных'}'),
                        Text('Преподаватель: ${item['lecturer'] ?? 'Не определён'}'),
                        Text('Начало занятия: ${item['beginLesson'] ?? 'Не указано'}'),
                        Text('Конец занятия: ${item['endLesson'] ?? 'Не указано'}'),
                        Text('Тип работы: ${item['kindOfWork'] ?? 'Не указано'}'),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
class PersonSchedulePage extends StatefulWidget {
  final String personId;
  final String personName;

  const PersonSchedulePage({super.key, required this.personId, required this.personName});

  @override
  State<PersonSchedulePage> createState() => _PersonSchedulePageState();
}

class _PersonSchedulePageState extends State<PersonSchedulePage> {
  List<Map<String, dynamic>> schedule = [];
  bool isLoading = true;

  Future<void> fetchSchedule() async {
    final start = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
    final end = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now().add(Duration(days: 7)));

    final url = Uri.parse(
        'http://localhost:5000/api/schedule/person/${widget.personId}?start=$start&finish=$end&lng=1');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          schedule = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load schedule');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personName),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : schedule.isEmpty
          ? const Center(child: Text('Нет расписания для этого преподавателя'))
          : ListView.builder(
        itemCount: schedule.length,
        itemBuilder: (context, index) {
          final item = schedule[index];
          return ListTile(
            title: Text(item['discipline'] ?? 'Нет названия'),
            subtitle: Text(
                '${item['date']} - ${item['beginLesson']} до ${item['endLesson']}'),
            trailing: Text(item['auditorium'] ?? 'Нет данных'),
            onTap: () {
              // Здесь можно добавить логику для более детального просмотра
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Дисциплина: ${item['discipline'] ?? 'Нет данных'}'),
                        Text('Аудитория: ${item['auditorium'] ?? 'Нет данных'}'),
                        Text('Здание: ${item['building'] ?? 'Нет данных'}'),
                        Text('Преподаватель: ${item['lecturer'] ?? 'Не определён'}'),
                        Text('Электронная почта преподавателя: ${item['lecturerEmail'] ?? 'Нет данных'}'),
                        Text('Начало занятия: ${item['beginLesson'] ?? 'Не указано'}'),
                        Text('Конец занятия: ${item['endLesson'] ?? 'Не указано'}'),
                        Text('Тип работы: ${item['kindOfWork'] ?? 'Не указано'}'),
                        Text('Факультет: ${item['group_facultyname'] ?? 'Не указан'}'),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
