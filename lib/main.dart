import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ble_manager.dart';
import 'models/gait_data.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BLEManager(),
      child: MaterialApp(
        title: '步态检测',
        theme: ThemeData(
          primaryColor: Color(0xFF1565C0),
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFF1565C0),
          ),
        ),
        home: const HomePage(),
        routes: {
          '/home': (context) => const HomePage(),
          '/scan': (context) => const ScanScreen(),
        },
      ),
    );
  }
}

// ============================================
// 主页面
// ============================================

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late BLEManager _bleManager;
  int _selectedLabel = 0;

  @override
  void initState() {
    super.initState();
    _bleManager = context.read<BLEManager>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('步态检测系统'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ============================================
              // 连接状态显示
              // ============================================
              Consumer<BLEManager>(
                builder: (context, bleManager, _) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '传感器状态',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  bleManager.printStatus();
                                },
                                icon: const Icon(Icons.info),
                                label: const Text('状态'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _StatusRow(
                            label: '左脚 IMU',
                            isConnected: true, // 需要从 BLE Manager 读取
                          ),
                          _StatusRow(
                            label: '右脚 IMU',
                            isConnected: true,
                          ),
                          _StatusRow(
                            label: '左脚压力',
                            isConnected: true,
                          ),
                          _StatusRow(
                            label: '右脚压力',
                            isConnected: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ============================================
              // 标签选择
              // ============================================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '步态阶段标签 (0-9)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(10, (index) {
                          return FilterChip(
                            label: Text(index.toString()),
                            selected: _selectedLabel == index,
                            onSelected: (selected) {
                              setState(() => _selectedLabel = index);
                              _bleManager.setLabel(index);
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ============================================
              // 控制按钮
              // ============================================
              Consumer<BLEManager>(
                builder: (context, bleManager, _) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // 扫描和连接
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/scan');
                                  },
                                  icon: const Icon(Icons.bluetooth_searching),
                                  label: const Text('扫描设备'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    bleManager.printStatus();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('刷新'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 录制控制
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: bleManager.isRecording
                                      ? null
                                      : () => bleManager.startRecording(),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('开始录制'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: bleManager.isRecording
                                      ? () => bleManager.stopRecording()
                                      : null,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('停止录制'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 导出按钮
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: bleManager.bufferSize > 0
                                      ? () => _showExportDialog(context)
                                      : null,
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('导出数据'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.list),
                                  label: Text('${bleManager.bufferSize} 条'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ============================================
              // 提示信息
              // ============================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '使用说明',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. 点击"扫描设备"，连接左右脚传感器\n'
                      '2. 选择步态阶段标签 (0-9)\n'
                      '3. 点击"开始录制"开始数据采集\n'
                      '4. 点击"停止录制"结束采集\n'
                      '5. 点击"导出数据"保存为 CSV 文件',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出数据'),
        content: Text('确认导出 ${_bleManager.bufferSize} 条记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _bleManager.exportRecords();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? '✓ 导出成功' : '✗ 导出失败',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('确认导出'),
          ),
        ],
      ),
    );
  }
}

// ============================================
// 状态指示器
// ============================================

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isConnected;

  const _StatusRow({
    Key? key,
    required this.label,
    required this.isConnected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
