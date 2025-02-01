import 'dart:collection';
import 'dart:developer';

import 'package:logger/logger.dart';

class LogUtil {
  static const _historyLength = 1000;
  static final _history = DoubleLinkedQueue<String>();
  // static final Logger _logger = Logger(printer: CustomLogPrinter());

  static void info(String message) {
    log(message);
    _history.add(message);
    while (_history.length > _historyLength) {
      _history.removeFirst();
    }
  }

  static List<String> history() {
    return _history.toList();
  }
}

class CustomLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final color = PrettyPrinter.defaultLevelColors[event.level];
    final emoji = PrettyPrinter.defaultLevelEmojis[event.level];
    return [color!('$emoji ${event.message}')];
  }
}
