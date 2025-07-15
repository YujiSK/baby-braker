import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // kIsWeb用
import 'dart:async';

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
  Timer? _statusTimer;

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
    _statusTimer?.cancel();
    ipController.dispose();
    super.dispose();
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
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
        IconData newIcon;
        switch (newStatus) {
          case "NORMAL":
            newMessage = "握っています";
            newColor = Colors.green;
            newIcon = Icons.pan_tool_alt;
            break;
          case "WARNING":
            newMessage = "手が離れています";
            newColor = Colors.orange;
            newIcon = Icons.warning_amber_rounded;
            break;
          case "BRAKE":
            newMessage = "ブレーキ作動!!";
            newColor = Colors.red;
            newIcon = Icons.report;
            break;
          default:
            newMessage = "default";
            newColor = Colors.grey;
            newIcon = Icons.help_outline;
        }

        setState(() {
          status = newStatus;
          message = newMessage;
          statusColor = newColor;
          statusHistory.insert(0, {
            'text': "$newStatus ($now)",
            'color': newColor,
            'icon': newIcon,
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
        showErrorSnackBar("HTTPエラー: ${response.statusCode}");
      }
    } catch (e) {
      if (!_isMounted) return;
      setState(() {
        status = "接続エラー";
        statusColor = Colors.grey;
      });
      showErrorSnackBar("接続エラー: $e");
    }

    if (_isMounted) {
      _statusTimer?.cancel();
      _statusTimer = Timer(const Duration(seconds: 3), fetchStatus);
    }
  }

  void updateIpAndFetch() {
    setState(() {
      esp32Ip = ipController.text;
    });
    _statusTimer?.cancel();
    fetchStatus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double messageFontSize = kIsWeb ? 36 : screenWidth * 0.12;
    double statusFontSize = kIsWeb ? 28 : screenWidth * 0.07;
    double historyFontSize = kIsWeb ? 18 : screenWidth * 0.045;

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
                const Divider(height: 32),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('アプリ情報'),
                  subtitle: Text('ベビーカー状態受信 v1.0'),
                ),
                const ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('ヘルプ'),
                  subtitle: Text('IPアドレスはESP32のWebサーバーに合わせて設定してください'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  '現在の状態: $status',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: statusFontSize,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '接続先: $esp32Ip',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                    statusColor.r.toInt(),
                    statusColor.g.toInt(),
                    statusColor.b.toInt(),
                    0.8,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: statusColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(
                        statusColor.r.toInt(),
                        statusColor.g.toInt(),
                        statusColor.b.toInt(),
                        0.3,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  status == "NORMAL"
                      ? Icons.pan_tool_alt
                      : status == "WARNING"
                      ? Icons.warning_amber_rounded
                      : status == "BRAKE"
                      ? Icons.report
                      : Icons.help_outline,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: messageFontSize,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '状態履歴（最新10件）',
                style: TextStyle(
                  fontSize: historyFontSize + 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: statusHistory.length,
                itemBuilder: (context, index) {
                  final item = statusHistory[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        item['icon'] ?? Icons.help_outline,
                        color: item['color'],
                        size: 28,
                      ),
                      title: Text(
                        item['text'],
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: item['color'],
                          fontSize: historyFontSize,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _statusTimer?.cancel();
          fetchStatus();
        },
        icon: const Icon(Icons.refresh),
        label: const Text("更新"),
        backgroundColor: statusColor,
      ),
    );
  }
}
