import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'gait_data.dart';
import 'package:intl/intl.dart';

/// CSV 导出服务 - 确保数据完整性
class CSVExportService {
  /// 导出步态数据到 CSV 文件（带错误检查）
  static Future<File> exportToCSV(List<GaitDataRecord> records) async {
    if (records.isEmpty) {
      throw Exception('No data to export');
    }

    try {
      // 1. 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'gait_data_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // 2. 创建 CSV 内容（使用 StringBuffer 优化性能）
      final buffer = StringBuffer();
      
      // 写表头
      buffer.writeln(GaitDataRecord.getCSVHeader());
      
      // 写数据行
      int successCount = 0;
      for (var i = 0; i < records.length; i++) {
        try {
          buffer.writeln(records[i].toCSVRow());
          successCount++;
        } catch (e) {
          print('Warning: Error processing record $i: $e');
        }
      }

      if (successCount == 0) {
        throw Exception('Failed to process any records');
      }

      // 3. 写入文件
      await file.writeAsString(buffer.toString(), encoding: utf8);
      
      // 4. 验证文件
      final fileExists = await file.exists();
      final fileSize = await file.length();
      
      if (!fileExists || fileSize == 0) {
        throw Exception('File write failed or file is empty');
      }

      print('✓ CSV exported successfully');
      print('  File: $filePath');
      print('  Records: $successCount/${records.length}');
      print('  Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      return file;
    } catch (e) {
      print('✗ Export failed: $e');
      throw Exception('CSV export failed: $e');
    }
  }

  /// 验证数据有效性
  static bool validateRecord(GaitDataRecord record) {
    // 检查数据范围（可选）
    final pressureValid = 
        record.rightP1 >= 0 && record.rightP5 >= 0 && record.rightPH >= 0 &&
        record.leftP1 >= 0 && record.leftP5 >= 0 && record.leftPH >= 0;
    
    final accValid =
        record.rightAccX.abs() <= 20 && record.rightAccY.abs() <= 20 && record.rightAccZ.abs() <= 20 &&
        record.leftAccX.abs() <= 20 && record.leftAccY.abs() <= 20 && record.leftAccZ.abs() <= 20;
    
    return pressureValid && accValid;
  }

  /// 获取已导出的文件列表
  static Future<List<File>> getExportedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory
          .listSync()
          .where((f) => f.path.contains('gait_data_') && f.path.endsWith('.csv'))
          .map((f) => File(f.path))
          .toList();
      
      // 按修改时间排序（最新的在前）
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      return files;
    } catch (e) {
      print('Error getting files: $e');
      return [];
    }
  }

  /// 获取文件详情
  static Future<Map<String, dynamic>> getFileInfo(File file) async {
    try {
      final stat = await file.stat();
      final content = await file.readAsString();
      final lines = content.split('\n').where((l) => l.isNotEmpty).length;
      
      return {
        'name': file.path.split('/').last,
        'size': stat.size,
        'modified': stat.modified,
        'records': (lines - 1).max(0), // 减去表头
        'path': file.path,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 删除旧文件（保留最近 10 个）
  static Future<void> cleanupOldFiles() async {
    try {
      final files = await getExportedFiles();
      if (files.length > 10) {
        for (var i = 10; i < files.length; i++) {
          await files[i].delete();
          print('Deleted: ${files[i].path}');
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }
}
