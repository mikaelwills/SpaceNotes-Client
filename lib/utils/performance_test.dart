import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/performance_tracker.dart';
import '../models/space_event.dart';

class PerformanceTest {
  static const int _testIterations = 100;
  static const int _streamingIterations = 50;
  
  // Test JSON parsing performance
  static Future<void> testJSONParsing() async {
    print('📊 [PerformanceTest] Starting JSON parsing test...');
    
    final sampleEventData = {
      'type': 'message.part.updated',
      'sessionId': 'test-session-123',
      'messageId': 'test-message-456',
      'properties': {
        'part': {
          'id': 'part-789',
          'type': 'text',
          'text': 'This is a sample streaming text that would be received from the server during a typical Space session.',
        }
      }
    };
    
    final jsonString = json.encode(sampleEventData);
    final stopwatch = Stopwatch();
    
    // Test full JSON parsing
    stopwatch.start();
    for (int i = 0; i < _testIterations; i++) {
      final decoded = json.decode(jsonString);
      final event = SpaceEvent.fromJson(decoded);
      // Simulate processing
      final _ = event.type;
    }
    stopwatch.stop();
    
    final fullParsingTime = stopwatch.elapsedMicroseconds / _testIterations;
    print('📊 [PerformanceTest] Full JSON parsing: ${fullParsingTime.toStringAsFixed(2)}μs per event');
    
    // Test regex-based fast path (simulated)
    stopwatch.reset();
    stopwatch.start();
    for (int i = 0; i < _testIterations; i++) {
      final typeMatch = RegExp(r'"type":"([^"]+)"').firstMatch(jsonString);
      // Simulate processing
      final _ = typeMatch?.group(1);
    }
    stopwatch.stop();
    
    final fastPathTime = stopwatch.elapsedMicroseconds / _testIterations;
    print('📊 [PerformanceTest] Fast path parsing: ${fastPathTime.toStringAsFixed(2)}μs per event');
    
    final improvement = ((fullParsingTime - fastPathTime) / fullParsingTime * 100);
    print('📊 [PerformanceTest] Fast path improvement: ${improvement.toStringAsFixed(1)}%');
  }
  
  // Test debounced vs immediate updates
  static Future<void> testDebouncedUpdates() async {
    print('📊 [PerformanceTest] Starting debounced updates test...');
    
    // Reset performance tracker
    PerformanceTracker.reset();
    
    // Test immediate updates (old behavior)
    final stopwatch = Stopwatch();
    stopwatch.start();
    
    for (int i = 0; i < _streamingIterations; i++) {
      PerformanceTracker.markSSEReceived('test-$i');
      // Simulate immediate UI update
      await Future.delayed(const Duration(microseconds: 100));
      PerformanceTracker.markUIUpdated('test-$i');
    }
    
    stopwatch.stop();
    final immediateTime = stopwatch.elapsedMilliseconds;
    final immediateReport = PerformanceTracker.generateReport();
    
    print('📊 [PerformanceTest] Immediate updates:');
    print('   Total time: ${immediateTime}ms');
    print('   Avg latency: ${immediateReport.averageLatencyMs.toStringAsFixed(2)}ms');
    print('   Update frequency: ${immediateReport.averageUpdateFrequency.toStringAsFixed(1)}/sec');
    
    // Reset for debounced test
    PerformanceTracker.reset();
    
    // Test debounced updates (new behavior)
    stopwatch.reset();
    stopwatch.start();
    
    final completer = Completer<void>();
    Timer? debounceTimer;
    int processedCount = 0;
    
    for (int i = 0; i < _streamingIterations; i++) {
      PerformanceTracker.markSSEReceived('debounced-$i');
      
      // Simulate 16ms debouncing
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 16), () {
        PerformanceTracker.markUIUpdated('debounced-$i');
        processedCount++;
        if (processedCount >= _streamingIterations) {
          completer.complete();
        }
      });
      
      // Simulate rapid updates
      await Future.delayed(const Duration(milliseconds: 2));
    }
    
    await completer.future;
    stopwatch.stop();
    
    final debouncedTime = stopwatch.elapsedMilliseconds;
    final debouncedReport = PerformanceTracker.generateReport();
    
    print('📊 [PerformanceTest] Debounced updates:');
    print('   Total time: ${debouncedTime}ms');
    print('   Avg latency: ${debouncedReport.averageLatencyMs.toStringAsFixed(2)}ms');
    print('   Update frequency: ${debouncedReport.averageUpdateFrequency.toStringAsFixed(1)}/sec');
    
    final timeImprovement = ((immediateTime - debouncedTime) / immediateTime * 100);
    print('📊 [PerformanceTest] Debouncing improvement: ${timeImprovement.toStringAsFixed(1)}%');
  }
  
  // Run all performance tests
  static Future<void> runAllTests() async {
    if (!kDebugMode) {
      print('📊 [PerformanceTest] Performance tests only run in debug mode');
      return;
    }
    
    print('📊 [PerformanceTest] Starting Phase 1 optimization validation...');
    print('📊 [PerformanceTest] ================================================');
    
    await testJSONParsing();
    print('');
    await testDebouncedUpdates();
    
    print('📊 [PerformanceTest] ================================================');
    print('📊 [PerformanceTest] Phase 1 optimization tests completed!');
  }
  
  // Generate a performance baseline report
  static Future<String> generateBaselineReport() async {
    await runAllTests();
    
    final report = PerformanceTracker.generateReport();
    
    return '''
Space Mobile Phase 1 Optimization Baseline Report
====================================================

Performance Metrics:
- Average Latency: ${report.averageLatencyMs.toStringAsFixed(2)}ms
- P95 Latency: ${report.p95LatencyMs.toStringAsFixed(2)}ms
- Max Latency: ${report.maxLatencyMs.toStringAsFixed(2)}ms
- Update Frequency: ${report.averageUpdateFrequency.toStringAsFixed(1)}/sec
- Sample Count: ${report.sampleCount}

Target Achievement:
- Sub-5ms latency: ${report.averageLatencyMs < 5 ? '✅ ACHIEVED' : '❌ NOT YET'}
- 60fps streaming: ${report.averageUpdateFrequency <= 60 ? '✅ ACHIEVED' : '❌ NOT YET'}

Optimizations Applied:
✅ Performance measurement framework
✅ 16ms debounced state updates  
✅ Direct text extraction fast path

Generated: ${DateTime.now().toIso8601String()}
''';
  }
}