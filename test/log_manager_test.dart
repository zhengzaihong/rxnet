import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/logcat/log_manager.dart';

void main() {
  group('LogManager retention', () {
    test('keeps only the last maxLogs entries', () {
      final manager = LogManager(maxLogs: 3);
      manager.setCollectLogs(true);

      for (var i = 0; i < 5; i++) {
        manager.addLogs('log-$i');
      }

      expect(manager.logsNotifier.value, ['log-2', 'log-3', 'log-4']);
    });

    test('does not record anything when collectLogs is false', () {
      final manager = LogManager(maxLogs: 3);

      manager.addLogs('ignored-1');
      manager.addLogs('ignored-2');

      expect(manager.logsNotifier.value, isEmpty);

      manager.setCollectLogs(true);
      manager.addLogs('kept');

      expect(manager.logsNotifier.value, ['kept']);
    });

    test('maxLogs of zero retains no entries', () {
      final manager = LogManager(maxLogs: 0);
      manager.setCollectLogs(true);

      manager.addLogs('a');
      manager.addLogs('b');

      expect(manager.logsNotifier.value, isEmpty);
    });

    test('clearLogs removes all entries', () {
      final manager = LogManager(maxLogs: 5);
      manager.setCollectLogs(true);
      manager.addLogs('a');
      manager.addLogs('b');

      manager.clearLogs();

      expect(manager.logsNotifier.value, isEmpty);
    });

    test('notifies listeners when logs change', () {
      final manager = LogManager(maxLogs: 2);
      var notifications = 0;
      manager.logsNotifier.addListener(() => notifications++);
      manager.setCollectLogs(true);

      manager.addLogs('a');
      manager.addLogs('b');
      expect(notifications, 2);

      final beforeClear = notifications;
      manager.clearLogs();
      expect(notifications, greaterThan(beforeClear));
      expect(manager.logsNotifier.value, isEmpty);
    });

    test('default maxLogs is 1000', () {
      expect(LogManager().maxLogs, 1000);
    });
  });
}