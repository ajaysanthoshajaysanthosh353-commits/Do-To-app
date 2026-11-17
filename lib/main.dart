import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;

// ================= TASK MODEL =================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabaseFactory();
  runApp(const MyApp());
}

void initializeDatabaseFactory() {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
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
    final databaseDirectory = await databaseFactory.getDatabasesPath();
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
            