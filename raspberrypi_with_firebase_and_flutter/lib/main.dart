import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:raspberrypiwithfirebase/firebase_options.dart';
import 'CRUD.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _thresholdController = TextEditingController();

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  // 顯示設置閾值的對話框
  Future<void> _showThresholdDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('設置 Z 軸閾值'),
          content: TextField(
            controller: _thresholdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '請輸入新的閾值',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (_thresholdController.text.isNotEmpty) {
                  try {
                    double threshold = double.parse(_thresholdController.text);
                    await FirestoreServices().setZThreshold(threshold);
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('閾值已更新為: $threshold')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請輸入有效的數字')),
                      );
                    }
                  }
                }
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // 在 AppBar 右側添加設置按鈕
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showThresholdDialog,
          ),
        ],
      ),
      body: Center(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirestoreServices().getDeviceInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('No devices found');
            }

            final devices = snapshot.data!.docs;

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index].data() as Map<String, dynamic>;
                      final docId = devices[index].id;

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          title: Text(device['timestamp'] ?? 'Unknown Device'),
                          subtitle: const Text("has been open!"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              FirestoreServices().deleteNote(docId);
                            },
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
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showThresholdDialog,
            tooltip: '設置閾值',
            heroTag: 'setThreshold',
            child: const Icon(Icons.tune),
          ),
          const SizedBox(width: 16),
          // 清除所有記錄按鈕
          FloatingActionButton(
            onPressed: () async {
              await FirestoreServices().deleteAllNotes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All devices deleted')),
                );
              }
            },
            tooltip: '一鍵清除',
            heroTag: 'deleteAll',
            child: const Icon(Icons.delete_forever),
          ),
        ],
      ),
    );
  }
}