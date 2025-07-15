import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // kIsWeb用

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'ESP32 Status Viewer', home: StatusPage());
  }
}

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  String status = "接続中...";
  String message = "日本語";
  Color statusColor = Colors.grey;
  List<Map<String, dynamic>> statusHistory = [];
  bool _isMounted = true;

  final TextEditingController ipController = TextEditingController(
    text: "http://192.168.177.156:8000",
  );
  late String esp32Ip;

  @override
  void initState() {
    super.initState();
    esp32Ip = ipController.text;
    fetchStatus();
  }

  @override
  void dispose() {
    _isMounted = false;
    ipController.dispose();
    super.dispose();
  }

  Future<void> fetchStatus() async {
    try {
      final response = await http.get(Uri.parse('$esp32Ip/status'));
      if (!_isMounted) return;

      if (response.statusCode == 200) {
        final newStatus = response.body.trim().toUpperCase();
        final now = DateTime.now().toLocal().toIso8601String().substring(
          11,
          19,
        );

        Color newColor;
        String newMessage;
        switch (newStatus) {
          case "NORMAL":
            newMessage = "握っています";
            newColor = Colors.green;
            break;
          case "WARNING":
            newMessage = "手が離れています";
            newColor = Colors.orange;
            break;
          case "BRAKE":
            newMessage = "ブレーキ作動!!";
            newColor = Colors.red;
            break;
          default:
            newMessage = "default";
            newColor = Colors.grey;
        }

        setState(() {
          status = newStatus;
          message = newMessage;
          statusColor = newColor;

          statusHistory.insert(0, {
            'text': "$newStatus ($now)",
            'color': newColor,
          });

          if (statusHistory.length > 10) {
            statusHistory = statusHistory.sublist(0, 10);
          }
        });
      } else {
        setState(() {
          status = "取得失敗";
          statusColor = Colors.grey;
        });
        debugPrint("HTTPエラー: \\${response.statusCode}");
      }
    } catch (e) {
      if (!_isMounted) return;
      setState(() {
        status = "接続エラー";
        statusColor = Colors.grey;
      });
      debugPrint("接続エラー: \\$e");
    }

    if (_isMounted) {
      Future.delayed(const Duration(seconds: 3), fetchStatus);
    }
  }

  void updateIpAndFetch() {
    setState(() {
      esp32Ip = ipController.text;
    });
    fetchStatus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double messageFontSize = kIsWeb ? 30 : screenWidth * 0.15;

    return Scaffold(
      appBar: AppBar(title: const Text('ベビーカー状態受信')),
      drawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text(
                  'ESP32のIPアドレス設定',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ipController,
                  decoration: const InputDecoration(
                    labelText: 'http://IP:ポート',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: updateIpAndFetch,
                  icon: const Icon(Icons.save),
                  label: const Text("保存して接続"),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                '現在の状態: $status',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 8),
              Text('接続先: $esp32Ip', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: fetchStatus,
                icon: const Icon(Icons.refresh),
                label: const Text("更新"),
              ),
              const SizedBox(height: 16),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                ' $message',
                style: TextStyle(
                  fontSize: messageFontSize,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '状態履歴（最新10件）',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: statusHistory.length,
                itemBuilder: (context, index) {
                  final item = statusHistory[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: item['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: Text(
                        item['text'],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
