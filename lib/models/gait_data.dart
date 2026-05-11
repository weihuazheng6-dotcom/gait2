import 'package:flutter/foundation.dart';

/// 压力数据 (JDY-10-V2.5 传感器) - 3个字段
class PressureData {
  final double p1;      // 第一跖骨头
  final double p5;      // 第五跖骨头
  final double heel;    // 足跟

  PressureData({
    required this.p1,
    required this.p5,
    required this.heel,
  });

  @override
  String toString() => 'P1:$p1,P5:$p5,PH:$heel';
}

/// 惯性测量单元数据 (WT9011DCL 传感器) - 9个数据字段
class IMUData {
  // 加速度 (g)
  final double accX;
  final double accY;
  final double accZ;

  // 角速度 (°/s)
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  // 欧拉角 (°) - Roll, Pitch, Yaw
  final double roll;
  final double pitch;
  final double yaw;

  IMUData({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.roll,
    required this.pitch,
    required this.yaw,
  });

  /// 从维特传感器的蓝牙原始数据解析 (Flag=0x61, 18字节)
  /// 数据顺序: AXL AXH AYL AYH AZL AZH WXL WXH WYL WYH WZL WZH RollL RollH PitchL PitchH YawL YawH
  static IMUData parseFromFrame(List<int> frame) {
    if (frame.length < 18) {
      throw Exception('Invalid IMU frame length: ${frame.length}');
    }

    // 辅助函数：16位有符号整数转换
    int toShort(int low, int high) {
      int value = ((high & 0xFF) << 8) | (low & 0xFF);
      if (value & 0x8000 != 0) {
        value = value - 0x10000;
      }
      return value;
    }

    // 解析加速度 (g): value/32768*16g
    double accX = toShort(frame[0], frame[1]) / 32768.0 * 16.0;
    double accY = toShort(frame[2], frame[3]) / 32768.0 * 16.0;
    double accZ = toShort(frame[4], frame[5]) / 32768.0 * 16.0;

    // 解析角速度 (°/s): value/32768*2000(°/s)
    double gyroX = toShort(frame[6], frame[7]) / 32768.0 * 2000.0;
    double gyroY = toShort(frame[8], frame[9]) / 32768.0 * 2000.0;
    double gyroZ = toShort(frame[10], frame[11]) / 32768.0 * 2000.0;

    // 解析欧拉角 (°): value/32768*180(°)
    double roll = toShort(frame[12], frame[13]) / 32768.0 * 180.0;
    double pitch = toShort(frame[14], frame[15]) / 32768.0 * 180.0;
    double yaw = toShort(frame[16], frame[17]) / 32768.0 * 180.0;

    return IMUData(
      accX: accX,
      accY: accY,
      accZ: accZ,
      gyroX: gyroX,
      gyroY: gyroY,
      gyroZ: gyroZ,
      roll: roll,
      pitch: pitch,
      yaw: yaw,
    );
  }

  @override
  String toString() => 
      'A:($accX,$accY,$accZ) G:($gyroX,$gyroY,$gyroZ) E:($roll,$pitch,$yaw)';
}

/// BLE 设备信息
class BLEDevice {
  final String id;
  final String name;
  final SensorRole role;
  final int rssi;

  BLEDevice({
    required this.id,
    required this.name,
    required this.role,
    required this.rssi,
  });

  @override
  String toString() => '$name ($role) - RSSI: $rssi';
}

/// 传感器角色
enum SensorRole { leftFoot, rightFoot, unknown }

/// 连接状态
enum ConnectionStatus { disconnected, connecting, connected, error }

/// 步态数据记录 - 26 列 CSV 格式
/// 结构: timestamp | rightP1 rightP5 rightPH rightAcc(3) rightGyro(3) rightAngle(3) | 
///                  leftP1 leftP5 leftPH leftAcc(3) leftGyro(3) leftAngle(3) | label
class GaitDataRecord {
  final String timestamp;
  
  // 右脚: 3个压力 + 9个惯性 = 12个
  final double rightP1;
  final double rightP5;
  final double rightPH;
  final double rightAccX;
  final double rightAccY;
  final double rightAccZ;
  final double rightGyroX;
  final double rightGyroY;
  final double rightGyroZ;
  final double rightRoll;
  final double rightPitch;
  final double rightYaw;
  
  // 左脚: 3个压力 + 9个惯性 = 12个
  final double leftP1;
  final double leftP5;
  final double leftPH;
  final double leftAccX;
  final double leftAccY;
  final double leftAccZ;
  final double leftGyroX;
  final double leftGyroY;
  final double leftGyroZ;
  final double leftRoll;
  final double leftPitch;
  final double leftYaw;
  
  // 标签
  final String label;

  GaitDataRecord({
    required this.timestamp,
    required this.rightP1,
    required this.rightP5,
    required this.rightPH,
    required this.rightAccX,
    required this.rightAccY,
    required this.rightAccZ,
    required this.rightGyroX,
    required this.rightGyroY,
    required this.rightGyroZ,
    required this.rightRoll,
    required this.rightPitch,
    required this.rightYaw,
    required this.leftP1,
    required this.leftP5,
    required this.leftPH,
    required this.leftAccX,
    required this.leftAccY,
    required this.leftAccZ,
    required this.leftGyroX,
    required this.leftGyroY,
    required this.leftGyroZ,
    required this.leftRoll,
    required this.leftPitch,
    required this.leftYaw,
    required this.label,
  });

  /// 转换为 CSV 行 (26 列)
  String toCSVRow() {
    return [
      timestamp,
      // 右脚 (12列)
      rightP1, rightP5, rightPH,
      rightAccX, rightAccY, rightAccZ,
      rightGyroX, rightGyroY, rightGyroZ,
      rightRoll, rightPitch, rightYaw,
      // 左脚 (12列)
      leftP1, leftP5, leftPH,
      leftAccX, leftAccY, leftAccZ,
      leftGyroX, leftGyroY, leftGyroZ,
      leftRoll, leftPitch, leftYaw,
      // 标签
      label,
    ]
    .map((v) => _formatValue(v))
    .join(',');
  }

  /// 格式化值（避免科学计数法）
  static String _formatValue(dynamic value) {
    if (value is double) {
      return value.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return value.toString();
  }

  /// CSV 表头 (26 列)
  static String getCSVHeader() {
    return [
      'timestamp',
      // 右脚
      'rightP1', 'rightP5', 'rightPH',
      'rightAccX', 'rightAccY', 'rightAccZ',
      'rightGyroX', 'rightGyroY', 'rightGyroZ',
      'rightRoll', 'rightPitch', 'rightYaw',
      // 左脚
      'leftP1', 'leftP5', 'leftPH',
      'leftAccX', 'leftAccY', 'leftAccZ',
      'leftGyroX', 'leftGyroY', 'leftGyroZ',
      'leftRoll', 'leftPitch', 'leftYaw',
      // 标签
      'label',
    ].join(',');
  }
}
