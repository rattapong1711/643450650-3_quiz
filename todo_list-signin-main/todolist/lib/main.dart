import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todolist/screen/signin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 5, 178, 77)),
        useMaterial3: true,
      ),
      home: const SigninScreen(), // เปลี่ยนเป็น TodaApp เพื่อให้เป็นหน้าเริ่มต้น
    );
  }
}

class TodaApp extends StatefulWidget {
  const TodaApp({super.key});

  @override
  State<TodaApp> createState() => _TodaAppState();
}

class _TodaAppState extends State<TodaApp> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  String _selectedType = 'Expense'; // Default to expense
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
  }

  void addTodoHandle(BuildContext context, [DocumentSnapshot? doc]) {
    if (doc != null) {
      _titleController.text = doc['name'];
      _descriptionController.text = doc['detail'];
      _amountController.text = doc['amount'].toString();
      _selectedType = doc['type'];
      _selectedDate = (doc['date'] as Timestamp).toDate();
    } else {
      _titleController.clear();
      _descriptionController.clear();
      _amountController.clear();
      _selectedType = 'Expense';
      _selectedDate = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            doc != null ? "Edit Entry" : "Add Entry",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Title",
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Description",
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Amount",
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Type",
                  ),
                  items: ['Income', 'Expense']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_selectedDate == null
                      ? "Select Date"
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (_titleController.text.isEmpty ||
                    _amountController.text.isEmpty ||
                    _selectedDate == null) {
                  return;
                }

                double amount = double.parse(_amountController.text);

                if (doc != null) {
                  FirebaseFirestore.instance.collection("tasks").doc(doc.id).update({
                    'name': _titleController.text,
                    'detail': _descriptionController.text,
                    'amount': amount,
                    'type': _selectedType,
                    'date': _selectedDate,
                  }).then((_) {
                    print("Entry updated");
                  }).catchError((onError) {
                    print("Failed to update entry");
                  });
                } else {
                  FirebaseFirestore.instance.collection("tasks").add({
                    'name': _titleController.text,
                    'detail': _descriptionController.text,
                    'amount': amount,
                    'type': _selectedType,
                    'date': _selectedDate,
                    'status': false,
                  }).then((_) {
                    print("Entry added");
                  }).catchError((onError) {
                    print("Failed to add entry");
                  });
                }

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void deleteTask(String id) {
    FirebaseFirestore.instance.collection("tasks").doc(id).delete().then((_) {
      print("Task deleted");
    }).catchError((onError) {
      print("Failed to delete task");
    });
  }

  void toggleStatus(String id, bool status) {
    FirebaseFirestore.instance.collection("tasks").doc(id).update({
      'status': !status,
    }).then((_) {
      print("Task status updated");
    }).catchError((onError) {
      print("Failed to update task status");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Todo",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("tasks").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("ไม่มีงาน"));
          }

          double totalIncome = 0.0;
          double totalExpense = 0.0;

          // คำนวณยอดรวม
          for (var task in snapshot.data!.docs) {
            if (task['type'] == 'Income') {
              totalIncome += task['amount'];
            } else if (task['type'] == 'Expense') {
              totalExpense += task['amount'];
            }
          }

          return Column(
            children: [
              // แสดงยอดรวม
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'รายรับรวม: \$${totalIncome.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'รายจ่ายรวม: \$${totalExpense.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // รายการงาน
              Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data?.docs.length,
                  itemBuilder: (context, index) {
                    var task = snapshot.data!.docs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: 5,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          task['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(task['detail']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                task['status']
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: task['status']
                                    ? Color.fromARGB(255, 227, 40, 102)
                                    : Color.fromARGB(255, 206, 19, 19),
                              ),
                              onPressed: () => toggleStatus(task.id, task['status']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color.fromARGB(255, 127, 195, 125)),
                              onPressed: () => addTodoHandle(context, task),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteTask(task.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          addTodoHandle(context);
        },
        backgroundColor: const Color.fromARGB(255, 61, 109, 60),
        child: const Icon(Icons.add),
      ),
    );
  }
}
