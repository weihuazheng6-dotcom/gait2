/// BLE Manager 中的关键代码片段
/// 确保惯性传感器数据正确采集和处理

// ============================================
// 1. 在 BLE Manager 中添加这些变量
// ============================================

// 当前数据缓存（确保左右脚数据对齐）
IMUData? _currentLeftIMU;
IMUData? _currentRightIMU;
PressureData? _currentLeftPressure;
PressureData? _currentRightPressure;

// 数据采集缓冲区
final List<GaitDataRecord> _recordBuffer = [];
final int _bufferSize = 1000; // 每 1000 条记录自动保存一次

// ============================================
// 2. IMU 数据 Notify 回调处理
// ============================================

void _handleIMUNotification(List<int> data, SensorRole role) {
  try {
    // 验证数据格式（维特传感器: 0x55 0x61 + 18字节数据）
    if (data.length < 20) {
      print('Warning: IMU frame too short (${data.length} bytes)');
      return;
    }

    // 检查帧头和标志位
    if (data[0] != 0x55 || data[1] != 0x61) {
      print('Warning: Invalid frame header: ${data[0]} ${data[1]}');
      return;
    }

    // 提取 18 字节的 IMU 数据（跳过帧头和标志位）
    List<int> imuFrame = data.sublist(2, 20);

    // 解析 IMU 数据
    try {
      IMUData imuData = IMUData.parseFromFrame(imuFrame);
      
      // 更新对应脚的数据
      if (role == SensorRole.leftFoot) {
        _currentLeftIMU = imuData;
        print('✓ Left IMU: ${imuData.toString()}');
      } else if (role == SensorRole.rightFoot) {
        _currentRightIMU = imuData;
        print('✓ Right IMU: ${imuData.toString()}');
      }

      notifyListeners();
    } catch (e) {
      print('✗ IMU parse error: $e');
    }
  } catch (e) {
    print('✗ IMU notification error: $e');
  }
}

// ============================================
// 3. 压力数据 Notify 回调处理
// ============================================

void _handlePressureNotification(String data, SensorRole role) {
  try {
    // 解析压力数据（格式: "$P1,P2,P3,...")
    if (!data.startsWith('\$')) {
      return;
    }

    final values = data.substring(1).split(',');
    if (values.length < 3) {
      print('Warning: Invalid pressure data: $data');
      return;
    }

    double p1 = double.tryParse(values[0]) ?? 0;
    double p5 = double.tryParse(values[1]) ?? 0;
    double ph = double.tryParse(values[2]) ?? 0;

    PressureData pressure = PressureData(p1: p1, p5: p5, heel: ph);

    if (role == SensorRole.leftFoot) {
      _currentLeftPressure = pressure;
      print('✓ Left Pressure: ${pressure.toString()}');
    } else if (role == SensorRole.rightFoot) {
      _currentRightPressure = pressure;
      print('✓ Right Pressure: ${pressure.toString()}');
    }

    notifyListeners();
  } catch (e) {
    print('✗ Pressure parse error: $e');
  }
}

// ============================================
// 4. 创建 CSV 记录（关键！）
// ============================================

void _createAndBufferRecord() {
  try {
    // ⚠️ 重要：检查数据是否完整
    if (_currentLeftIMU == null || _currentRightIMU == null ||
        _currentLeftPressure == null || _currentRightPressure == null) {
      print('⚠ Warning: Incomplete data - skipping record');
      return;
    }

    // 创建记录
    final record = GaitDataRecord(
      timestamp: DateTime.now().toIso8601String(),
      
      // 右脚 (12 列)
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
      
      // 左脚 (12 列)
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

    // 添加到缓冲区
    _recordBuffer.add(record);
    print('✓ Record added (total: ${_recordBuffer.length})');

    // 自动保存（避免内存溢出）
    if (_recordBuffer.length >= _bufferSize) {
      _autoSaveBuffer();
    }

    notifyListeners();
  } catch (e) {
    print('✗ Record creation error: $e');
  }
}

// ============================================
// 5. 启动录制（定时创建记录）
// ============================================

Timer? _recordTimer;

void startRecording() {
  if (_recordTimer != null) {
    print('⚠ Recording already started');
    return;
  }

  _recordBuffer.clear();
  _isRecording = true;

  // 每 50ms 创建一条记录（20Hz 采样率）
  _recordTimer = Timer.periodic(Duration(milliseconds: 50), (_) {
    _createAndBufferRecord();
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
// 6. 导出数据（确保不丢失）
// ============================================

Future<void> exportRecords() async {
  if (_recordBuffer.isEmpty) {
    print('⚠ No data to export');
    return;
  }

  try {
    print('Starting export (${_recordBuffer.length} records)...');
    
    // 调用 CSV 导出服务
    final file = await CSVExportService.exportToCSV(_recordBuffer);
    
    // 导出成功后清空缓冲区
    _recordBuffer.clear();
    
    print('✓ Export successful!');
    print('  File: ${file.path}');
    
    notifyListeners();
  } catch (e) {
    print('✗ Export failed: $e');
  }
}

// ============================================
// 7. 自动保存缓冲区（可选）
// ============================================

Future<void> _autoSaveBuffer() async {
  try {
    if (_recordBuffer.isEmpty) return;

    print('Auto-saving buffer (${_recordBuffer.length} records)...');
    
    // 创建备份文件
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupFile = File('${directory.path}/backup_$timestamp.csv');
    
    final buffer = StringBuffer();
    buffer.writeln(GaitDataRecord.getCSVHeader());
    for (var record in _recordBuffer) {
      buffer.writeln(record.toCSVRow());
    }
    
    await backupFile.writeAsString(buffer.toString());
    print('✓ Backup saved: ${backupFile.path}');
  } catch (e) {
    print('✗ Auto-save error: $e');
  }
}

// ============================================
// 8. 调试：打印当前数据状态
// ============================================

void printDataStatus() {
  print('=== Data Status ===');
  print('Left IMU: ${_currentLeftIMU != null ? "✓" : "✗"}');
  print('Right IMU: ${_currentRightIMU != null ? "✓" : "✗"}');
  print('Left Pressure: ${_currentLeftPressure != null ? "✓" : "✗"}');
  print('Right Pressure: ${_currentRightPressure != null ? "✓" : "✗"}');
  print('Buffer size: ${_recordBuffer.length}');
  print('Recording: ${_isRecording ? "✓" : "✗"}');
  print('===================');
}
