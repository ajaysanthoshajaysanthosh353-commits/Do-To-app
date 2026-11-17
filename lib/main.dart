import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path/path.dart' as p;

// ================= TASK MODEL =================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabaseFactory();
  runApp(const MyApp());
}

void initializeDatabaseFactory() {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
  }
}

class Task {
  int? id;
  String title;
  DateTime date;
  bool isCompleted;

  Task({
    this.id,
    required this.title,
    required this.date,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
      isCompleted: (map['isCompleted'] as int) == 1,
    );
  }
}

// ================= SQLITE DATABASE =================

class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = p.join(databaseDirectory, 'todo_tasks.db');

    return openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'date ASC, id DESC');
    return rows.map((row) => Task.fromMap(row)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}

// ================= MAIN APP =================

class ToDoList extends StatelessWidget {
  const ToDoList({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My To-Do List',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color.fromARGB(255, 12, 148, 32),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E9D59)),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const MainScreen(),
    );
  }
}

// ================= MAIN SCREEN =================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedPage = 0;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  // Load saved tasks from SQLite when the main screen opens.
  Future<void> loadTasks() async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final savedTasks = await DatabaseHelper.instance.getAllTasks();
      if (!mounted) return;

      setState(() {
        tasks
          ..clear()
          ..addAll(savedTasks);
      });
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not load tasks: $error')),
      );
    }
  }

  final List<Task> tasks = [];

  DateTime scheduleSelectedDate = DateTime.now();

  String selectedFilter = 'All';

  // ================= ADD TASK =================

  void addTask({DateTime? initialDate}) {
    final TextEditingController taskController = TextEditingController();

    DateTime taskDate = initialDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Create New Task',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: taskController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter task name',
                        prefixIcon: const Icon(Icons.edit),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // DATE PICKER
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: taskDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            taskDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F4E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: Color(0xFF238B4B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(taskDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E9D59),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);

                    if (taskController.text.trim().isEmpty) {
                      messenger?.showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a task name'),
                        ),
                      );
                      return;
                    }

                    final newTask = Task(
                      title: taskController.text.trim(),
                      date: taskDate,
                    );

                    try {
                      final insertedId = await DatabaseHelper.instance
                          .insertTask(newTask);
                      newTask.id = insertedId;

                      if (!mounted) return;

                      setState(() {
                        tasks.add(newTask);
                        scheduleSelectedDate = taskDate;
                      });
                    } catch (error) {
                      if (!mounted) return;
                      messenger?.showSnackBar(
                        SnackBar(content: Text('Could not save task: $error')),
                      );
                      return;
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);

                    if (!mounted) return;

                    // Open Achieve page after adding task.
                    setState(() {
                      selectedPage = 1;
                    });

                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text('Task added successfully!'),
                        backgroundColor: Color(0xFF238B4B),
                      ),
                    );
                  },
                  child: const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= COMPLETE TASK =================

  Future<void> toggleTask(int index) async {
    final task = tasks[index];
    final oldValue = task.isCompleted;
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() {
      task.isCompleted = !oldValue;
    });

    try {
      await DatabaseHelper.instance.updateTask(task);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        task.isCompleted = oldValue;
      });
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not update task: $error')),
      );
    }
  }

  // ================= DELETE TASK =================

  void deleteTask(int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final task = tasks[index];
                final messenger = ScaffoldMessenger.maybeOf(context);

                try {
                  if (task.id != null) {
                    await DatabaseHelper.instance.deleteTask(task.id!);
                  }

                  if (!mounted || !dialogContext.mounted) return;

                  setState(() {
                    tasks.removeAt(index);
                  });

                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (!mounted) return;
                  messenger?.showSnackBar(
                    SnackBar(content: Text('Could not delete task: $error')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ================= BOTTOM NAVIGATION =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 17, 175, 38),
      appBar: AppBar(
        title: Text("To Do List", style: GoogleFonts.poppins(fontSize: 17)),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: const Color.fromRGBO(255, 230, 230, 1),
        centerTitle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      body: SafeArea(
        child: IndexedStack(
          index: selectedPage,
          children: [
            HomePage(
              tasks: tasks,
              onAddTask: () => addTask(),
              onViewTasks: () {
                setState(() {
                  selectedPage = 1;
                });
              },
            ),

            AchievePage(
              tasks: tasks,
              selectedFilter: selectedFilter,
              onFilterChanged: (filter) {
                setState(() {
                  selectedFilter = filter;
                });
              },
              onToggleTask: toggleTask,
              onDeleteTask: deleteTask,
            ),

            SchedulePage(
              tasks: tasks,
              selectedDate: scheduleSelectedDate,
              onDateChanged: (date) {
                setState(() {
                  scheduleSelectedDate = date;
                });
              },
              onAddTask: () {
                addTask(initialDate: scheduleSelectedDate);
              },
              onToggleTask: toggleTask,
              onDeleteTask: deleteTask,
            ),
          ],
        ),
      ),

      // BOTTOM NAVIGATION BAR
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.black,
          indicatorColor: const Color(0xFFDDF2E3),
          selectedIndex: selectedPage,
          onDestinationSelected: (index) {
            setState(() {
              selectedPage = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(CupertinoIcons.home, color: Colors.grey),
              selectedIcon: Icon(CupertinoIcons.home, color: Colors.black),

              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.rosette, color: Colors.grey),
              selectedIcon: Icon(CupertinoIcons.rosette, color: Colors.black),
              label: 'Achieve',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.calendar, color: Colors.grey),
              selectedIcon: Icon(CupertinoIcons.calendar, color: Colors.black),
              label: 'Schedule',
            ),
          ],
        ),
      ),
    );
  }
}

// ================= HOME PAGE =================

class HomePage extends StatelessWidget {
  final List<Task> tasks;
  final VoidCallback onAddTask;
  final VoidCallback onViewTasks;

  const HomePage({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onViewTasks,
  });

  @override
  Widget build(BuildContext context) {
    int totalTasks = tasks.length;

    int completedTasks = tasks.where((task) => task.isCompleted).length;

    int pendingTasks = totalTasks - completedTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER

          // TODAY CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF238B4B), Color(0xFF55B878)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TODAY',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Make today productive!',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // OVERVIEW
          Text(
            'Your Overview',
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: overviewCard(
                  'Total',
                  totalTasks.toString(),
                  Icons.assignment,
                  const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: overviewCard(
                  'Completed',
                  completedTasks.toString(),
                  Icons.check_circle,
                  const Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: overviewCard(
                  'Pending',
                  pendingTasks.toString(),
                  Icons.pending_actions,
                  const Color(0xFFE59B35),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // CREATE TASK
          const SizedBox(height: 15),

          InkWell(
            onTap: onAddTask,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 0, 0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCEBDD)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF238B4B),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Task',
                          style: GoogleFonts.nunitoSans(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Add a new task to your list',
                          style: GoogleFonts.nunitoSans(
                            fontWeight: FontWeight.w200,
                            color: Colors.white,

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 17),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

          // VIEW ACHIEVEMENTS
        ],
      ),
    );
  }

  Widget overviewCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 8),
          Text(
            count,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ================= ACHIEVE PAGE =================

class AchievePage extends StatelessWidget {
  final List<Task> tasks;
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Function(int) onToggleTask;
  final Function(int) onDeleteTask;

  const AchievePage({
    super.key,
    required this.tasks,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  @override
  Widget build(BuildContext context) {
    int total = tasks.length;

    int completed = tasks.where((task) => task.isCompleted).length;

    int pending = total - completed;

    double progress = total == 0 ? 0 : completed / total;

    final filteredTasks = tasks.asMap().entries.where((entry) {
      final task = entry.value;

      if (selectedFilter == 'Pending') {
        return !task.isCompleted;
      }

      if (selectedFilter == 'Completed') {
        return task.isCompleted;
      }

      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Achievements',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C3525),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Track your progress and complete your goals.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 25),

          // MY TASKS CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF238B4B), Color(0xFF55B878)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MY TASKS',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  total.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const Text(
                  'Total tasks created',
                  style: TextStyle(color: Colors.white),
                ),

                const SizedBox(height: 20),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  '${(progress * 100).toStringAsFixed(0)}% Completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // COMPLETED AND PENDING
          Row(
            children: [
              Expanded(
                child: achievementCard(
                  'Completed',
                  completed.toString(),
                  Icons.check_circle,
                  const Color(0xFF2E9D59),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: achievementCard(
                  'Pending',
                  pending.toString(),
                  Icons.pending_actions,
                  const Color(0xFFE59B35),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // FILTER
          Text(
            'My Tasks',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            children: [
              filterChip('All'),
              filterChip('Pending'),
              filterChip('Completed'),
            ],
          ),

          const SizedBox(height: 18),

          // TASK LIST
          if (filteredTasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(Icons.task_alt, size: 55, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No tasks found',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Create a task to get started.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            ...filteredTasks.map((entry) {
              final index = entry.key;
              final task = entry.value;

              return taskCard(
                task: task,
                onToggle: () => onToggleTask(index),
                onDelete: () => onDeleteTask(index),
              );
            }),
        ],
      ),
    );
  }

  Widget achievementCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 10),
          Text(
            count,
            style: GoogleFonts.poppins(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget filterChip(String filter) {
    bool isSelected = selectedFilter == filter;

    return ChoiceChip(
      label: Text(filter),
      selected: isSelected,
      onSelected: (_) => onFilterChanged(filter),
      selectedColor: const Color(0xFF2E9D59),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
    );
  }

  Widget taskCard({
    required Task task,
    required VoidCallback onToggle,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: const Color(0xFF2E9D59),
            onChanged: (_) => onToggle(),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: task.isCompleted ? Colors.grey : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(task.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ================= SCHEDULE PAGE =================

class SchedulePage extends StatelessWidget {
  final List<Task> tasks;
  final DateTime selectedDate;

  final Function(DateTime) onDateChanged;
  final VoidCallback onAddTask;
  final Function(int) onToggleTask;
  final Function(int) onDeleteTask;

  const SchedulePage({
    super.key,
    required this.tasks,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  // Get Monday of selected week.

  DateTime get weekStart {
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).subtract(Duration(days: selectedDate.weekday - 1));
  }

  // Change week.

  void changeWeek(int amount) {
    onDateChanged(selectedDate.add(Duration(days: amount * 7)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedTasks = tasks.asMap().entries.where((entry) {
      return DateUtils.isSameDay(entry.value.date, selectedDate);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Text(
            'Weekly Planner',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1C3525),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Plan your week and stay organised.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 25),

          // WEEK NAVIGATION
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => changeWeek(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),

                    Text(
                      '${DateFormat('dd MMM').format(weekStart)} - '
                      '${DateFormat('dd MMM yyyy').format(weekStart.add(const Duration(days: 6)))}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    IconButton(
                      onPressed: () => changeWeek(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // WEEK DAYS
                Row(
                  children: List.generate(7, (index) {
                    final date = weekStart.add(Duration(days: index));

                    final isSelected = DateUtils.isSameDay(date, selectedDate);

                    final isToday = DateUtils.isSameDay(date, DateTime.now());

                    final hasTasks = tasks.any(
                      (task) => DateUtils.isSameDay(task.date, date),
                    );

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          onDateChanged(date);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2E9D59)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('E').format(date).substring(0, 2),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 9),

                              Text(
                                date.day.toString(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasTasks
                                      ? (isSelected
                                            ? Colors.white
                                            : const Color(0xFF2E9D59))
                                      : Colors.transparent,
                                ),
                              ),

                              if (isToday)
                                Text(
                                  'Today',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF2E9D59),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // SELECTED DATE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  DateUtils.isSameDay(selectedDate, DateTime.now())
                      ? "Today's Schedule"
                      : DateFormat('dd MMMM yyyy').format(selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF2E3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${selectedTasks.length} Tasks',
                  style: const TextStyle(
                    color: Color(0xFF238B4B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // SCHEDULED TASKS
          if (selectedTasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 55,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Schedule Found',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Add a task to plan your day.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...selectedTasks.map((entry) {
              final index = entry.key;
              final task = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 45,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? Colors.grey
                            : const Color(0xFF2E9D59),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: task.isCompleted
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            DateFormat('EEEE, dd MMM').format(task.date),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Checkbox(
                      value: task.isCompleted,
                      activeColor: const Color(0xFF2E9D59),
                      onChanged: (_) => onToggleTask(index),
                    ),

                    IconButton(
                      onPressed: () => onDeleteTask(index),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 15),

          // ADD SCHEDULE BUTTON
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Schedule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E9D59),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To Do List',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      home: const IntroPage(),
    );
  }
}

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text(
          'To Do List',
          style: GoogleFonts.nunito(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task_alt, size: 100, color: Colors.white),
              const SizedBox(height: 25),
              Text(
                'Welcome to the To Do List App!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Organize your tasks, manage your schedule '
                'and achieve your daily goals.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: 200,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Get Started',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
