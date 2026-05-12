import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_manager.dart';
import '../models/gait_data.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late BLEManager _bleManager;
  Map<String, SensorRole> _selectedDevices = {};

  @override
  void initState() {
    super.initState();
    _bleManager = context.read<BLEManager>();
    _startScan();
  }

  void _startScan() {
    _bleManager.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描设备'),
        elevation: 0,
      ),
      body: Consumer<BLEManager>(
        builder: (context, bleManager, _) {
          return Column(
            children: [
              // ============================================
              // 扫描状态栏
              // ============================================
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (bleManager.isScanning)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        else
                          const Icon(Icons.bluetooth_searching),
                        const SizedBox(width: 12),
                        Text(
                          bleManager.isScanning ? '扫描中...' : '已停止扫描',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: bleManager.isScanning
                          ? () => bleManager.stopScan()
                          : _startScan,
                      child: Text(bleManager.isScanning ? '停止' : '重新扫描'),
                    ),
                  ],
                ),
              ),

              // ============================================
              // 设备列表
              // ============================================
              Expanded(
                child: bleManager.availableDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '未找到设备',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '请确保传感器已打开并处于配对模式',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: bleManager.availableDevices.length,
                        itemBuilder: (context, index) {
                          final device = bleManager.availableDevices[index];
                          final isSelected =
                              _selectedDevices.containsKey(device.id);
                          final selectedRole = _selectedDevices[device.id];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.sensors,
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.shade400,
                              ),
                              title: Text(
                                device.name.isEmpty
                                    ? '未知设备'
                                    : device.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(device.id),
                              trailing: isSelected
                                  ? Chip(
                                      label: Text(
                                        selectedRole ==
                                                SensorRole.leftFoot
                                            ? '左脚'
                                            : '右脚',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      backgroundColor: Colors.blue,
                                    )
                                  : null,
                              onTap: () => _showRoleSelection(
                                context,
                                device,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ============================================
              // 连接按钮
              // ============================================
              if (_selectedDevices.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '已选择 ${_selectedDevices.length} 个设备',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _connectSelectedDevices();
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('连接选定设备'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showRoleSelection(BuildContext context, dynamic device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name.isEmpty ? '未知设备' : device.name),
        content: const Text('选择传感器位置'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedDevices[device.id] = SensorRole.leftFoot;
              });
              Navigator.pop(context);
            },
            child: const Text('左脚'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedDevices[device.id] = SensorRole.rightFoot;
              });
              Navigator.pop(context);
            },
            child: const Text('右脚'),
          ),
          if (_selectedDevices.containsKey(device.id))
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDevices.remove(device.id);
                });
                Navigator.pop(context);
              },
              child: const Text('取消选择', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _connectSelectedDevices() async {
    final bleManager = context.read<BLEManager>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('连接中...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在连接设备...'),
          ],
        ),
      ),
    );

    try {
      for (var entry in _selectedDevices.entries) {
        final device = bleManager.availableDevices
            .firstWhere((d) => d.id == entry.key);
        final role = entry.value;

        await bleManager.connectDevice(device, role);
      }

      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        
        // 等待一秒后返回主页
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.pop(context); // 返回主页
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ 设备连接成功！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ 连接失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _bleManager.stopScan();
    super.dispose();
  }
}
