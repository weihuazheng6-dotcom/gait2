import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'gait_data.dart';
import 'csv_export.dart';
import 'package:intl/intl.dart';

class BLEManager extends ChangeNotifier {
  final FlutterBlue _flutterBlue = FlutterBlue.instance;

  // 设备列表
  List<BluetoothDevice> _availableDevices = [];
  Map<String, BluetoothDevice> _connectedDevices = {};

  // 数据缓存
  IMUData? _currentLeftIMU;
  IMUData? _currentRightIMU;
  PressureData? _currentLeftPressure;
  PressureData? _currentRightPressure;

  // 录制缓冲
  final List<GaitDataRecord> _recordBuffer = [];
  final int _bufferSize = 1000;

  // 状态
  bool _isScanning = false;
  bool _isRecording = false;
  Timer? _recordTimer;
  int _currentLabel = 0;

  // Getters
  List<BluetoothDevice> get availableDevices => _availableDevices;
  bool get isScanning => _isScanning;
  bool get isRecording => _isRecording;
  List<GaitDataRecord> get records => _recordBuffer;
  int get bufferSize => _recordBuffer.length;

  // ============================================
  // 扫描设备
  // ============================================

  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _availableDevices.clear();
    notifyListeners();

    try {
      _flutterBlue.startScan(timeout: Duration(seconds: 10));

      _flutterBlue.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (!_availableDevices.contains(result.device)) {
            _availableDevices.add(result.device);
            print('Found device: ${result.device.name} (${result.device.id})');
          }
        }
        notifyListeners();
      });
    } catch (e) {
      print('Scan error: $e');
    }
  }

  Future<void> stopScan() async {
    _isScanning = false;
    await _flutterBlue.stopScan();
    notifyListeners();
  }

  // ============================================
  // 连接设备
  // ============================================

  Future<bool> connectDevice(BluetoothDevice device, SensorRole role) async {
    try {
      print('Connecting to ${device.name} as $role...');
      await device.connect(timeout: Duration(seconds: 10));

      _connectedDevices[device.id] = device;

      // 订阅特性
      _setupNotifications(device, role);

      print('✓ Connected to ${device.name}');
      notifyListeners();
      return true;
    } catch (e) {
      print('✗ Connection error: $e');
      return false;
    }
  }

  Future<void> disconnectDevice(String deviceId) async {
    if (_connectedDevices.containsKey(deviceId)) {
      try {
        await _connectedDevices[deviceId]?.disconnect();
        _connectedDevices.remove(deviceId);
        print('✓ Disconnected');
      } catch (e) {
        print('Disconnect error: $e');
      }
    }
    notifyListeners();
  }

  // ============================================
  // 设置通知（蓝牙数据接收）
  // ============================================

  void _setupNotifications(BluetoothDevice device, SensorRole role) async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        print('Service: ${service.uuid}');

        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print('  Characteristic: ${characteristic.uuid}');

          // 订阅通知
          try {
            await characteristic.setNotifyValue(true);

            characteristic.value.listen((value) {
              _handleBluetoothData(value, role, characteristic.uuid.toString());
            });
          } catch (e) {
            // 某些特性不支持通知
          }
        }
      }
    } catch (e) {
      print('Setup notifications error: $e');
    }
  }

  // ============================================
  // 处理蓝牙数据
  // ============================================

  void _handleBluetoothData(List<int> data, SensorRole role, String uuid) {
    try {
      // 维特 IMU 传感器 (0x55 0x61 + 18字节)
      if (data.length >= 20 && data[0] == 0x55 && data[1] == 0x61) {
        _handleIMUData(data, role);
      }
      // JDY-10 压力传感器 (ASCII 字符串 "$P1,P2,P3")
      else if (data.isNotEmpty && data[0] == 0x24) { // '$'
        _handlePressureData(data, role);
      }
    } catch (e) {
      print('Data handling error: $e');
    }
  }

  // ============================================
  // IMU 数据处理
  // ============================================

  void _handleIMUData(List<int> data, SensorRole role) {
    try {
      // 验证帧
      if (data.length < 20) return;

      // 提取 18 字节 IMU 数据
      List<int> imuFrame = data.sublist(2, 20);

      // 解析
      IMUData imuData = IMUData.parseFromFrame(imuFrame);

      // 更新
      if (role == SensorRole.leftFoot) {
        _currentLeftIMU = imuData;
        print('✓ Left IMU: Acc(${imuData.accX.toStringAsFixed(2)}, '
            '${imuData.accY.toStringAsFixed(2)}, '
            '${imuData.accZ.toStringAsFixed(2)})');
      } else {
        _currentRightIMU = imuData;
        print('✓ Right IMU: Acc(${imuData.accX.toStringAsFixed(2)}, '
            '${imuData.accY.toStringAsFixed(2)}, '
            '${imuData.accZ.toStringAsFixed(2)})');
      }

      notifyListeners();
    } catch (e) {
      print('IMU parse error: $e');
    }
  }

  // ============================================
  // 压力数据处理
  // ============================================

  void _handlePressureData(List<int> data, SensorRole role) {
    try {
      // 转换为字符串
      String str = String.fromCharCodes(data).trim();

      if (!str.startsWith('\$')) return;

      // 解析格式: "$P1,P2,P3"
      String valueStr = str.substring(1);
      List<String> values = valueStr.split(',');

      if (values.length < 3) return;

      double p1 = double.tryParse(values[0]) ?? 0;
      double p5 = double.tryParse(values[1]) ?? 0;
      double ph = double.tryParse(values[2]) ?? 0;

      PressureData pressure = PressureData(p1: p1, p5: p5, heel: ph);

      if (role == SensorRole.leftFoot) {
        _currentLeftPressure = pressure;
        print('✓ Left Pressure: P1=$p1, P5=$p5, PH=$ph');
      } else {
        _currentRightPressure = pressure;
        print('✓ Right Pressure: P1=$p1, P5=$p5, PH=$ph');
      }

      notifyListeners();
    } catch (e) {
      print('Pressure parse error: $e');
    }
  }

  // ============================================
  // 录制方法
  // ============================================

  void startRecording() {
    if (_isRecording) return;

    _recordBuffer.clear();
    _isRecording = true;

    // 每 50ms 采样一次（20Hz）
    _recordTimer = Timer.periodic(Duration(milliseconds: 50), (_) {
      _createRecord();
    });

    print('✓ Recording started');
    notifyListeners();
  }

  void stopRecording() {
    _recordTimer?.cancel();
    _recordTimer = null;
    _isRecording = false;

    print('✓ Recording stopped (${_recordBuffer.length} records)');
    notifyListeners();
  }

  // ============================================
  // 创建记录
  // ============================================

  void _createRecord() {
    // 检查数据完整性
    if (_currentLeftIMU == null ||
        _currentRightIMU == null ||
        _currentLeftPressure == null ||
        _currentRightPressure == null) {
      return; // 数据不完整，跳过
    }

    try {
      final record = GaitDataRecord(
        timestamp: DateTime.now().toIso8601String(),

        // 右脚
        rightP1: _currentRightPressure!.p1,
        rightP5: _currentRightPressure!.p5,
        rightPH: _currentRightPressure!.heel,
        rightAccX: _currentRightIMU!.accX,
        rightAccY: _currentRightIMU!.accY,
        rightAccZ: _currentRightIMU!.accZ,
        rightGyroX: _currentRightIMU!.gyroX,
        rightGyroY: _currentRightIMU!.gyroY,
        rightGyroZ: _currentRightIMU!.gyroZ,
        rightRoll: _currentRightIMU!.roll,
        rightPitch: _currentRightIMU!.pitch,
        rightYaw: _currentRightIMU!.yaw,

        // 左脚
        leftP1: _currentLeftPressure!.p1,
        leftP5: _currentLeftPressure!.p5,
        leftPH: _currentLeftPressure!.heel,
        leftAccX: _currentLeftIMU!.accX,
        leftAccY: _currentLeftIMU!.accY,
        leftAccZ: _currentLeftIMU!.accZ,
        leftGyroX: _currentLeftIMU!.gyroX,
        leftGyroY: _currentLeftIMU!.gyroY,
        leftGyroZ: _currentLeftIMU!.gyroZ,
        leftRoll: _currentLeftIMU!.roll,
        leftPitch: _currentLeftIMU!.pitch,
        leftYaw: _currentLeftIMU!.yaw,

        // 标签
        label: _currentLabel.toString(),
      );

      _recordBuffer.add(record);
      notifyListeners();
    } catch (e) {
      print('Record creation error: $e');
    }
  }

  // ============================================
  // 导出数据
  // ============================================

  Future<bool> exportRecords() async {
    if (_recordBuffer.isEmpty) {
      print('⚠ No data to export');
      return false;
    }

    try {
      print('Exporting ${_recordBuffer.length} records...');
      final file = await CSVExportService.exportToCSV(_recordBuffer);
      _recordBuffer.clear();
      print('✓ Export successful: ${file.path}');
      notifyListeners();
      return true;
    } catch (e) {
      print('✗ Export failed: $e');
      return false;
    }
  }

  // ============================================
  // 辅助方法
  // ============================================

  void setLabel(int label) {
    _currentLabel = label;
    notifyListeners();
  }

  void printStatus() {
    print('=== BLE Status ===');
    print('Left IMU: ${_currentLeftIMU != null ? "✓" : "✗"}');
    print('Right IMU: ${_currentRightIMU != null ? "✓" : "✗"}');
    print('Left Pressure: ${_currentLeftPressure != null ? "✓" : "✗"}');
    print('Right Pressure: ${_currentRightPressure != null ? "✓" : "✗"}');
    print('Buffer: ${_recordBuffer.length}');
    print('Recording: ${_isRecording ? "✓" : "✗"}');
    print('==================');
  }
}

enum SensorRole { leftFoot, rightFoot, unknown }
