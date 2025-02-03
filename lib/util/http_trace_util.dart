import 'dart:io';

import 'package:r34_video/util/log_util.dart';
import 'package:r34_video/util/toast_util.dart';

class HttpTraceUtil {
  static void handleHttpError(int statusCode) {
    String errorMessage;
    switch (statusCode) {
      case 400:
        errorMessage =
            'Bad Request: The server could not understand the request due to invalid syntax.';
        break;
      case 401:
        errorMessage =
            'Unauthorized: Authentication is required and has failed or has not yet been provided.';
        break;
      case 403:
        errorMessage =
            'Forbidden: The server understood the request but refuses to authorize it.';
        break;
      case 404:
        errorMessage = 'Not Found: The requested resource could not be found.';
        break;
      case 500:
        errorMessage =
            'Internal Server Error: The server encountered an unexpected condition that prevented it from fulfilling the request.';
        break;
      default:
        errorMessage = 'HTTP Error: Status code $statusCode';
    }
    ToastUtil.showToast(errorMessage);
    LogUtil.info(errorMessage);
  }

  static void handleConnectionError(dynamic error, {dynamic st}) {
    String errorMessage;
    if (error is SocketException) {
      errorMessage =
          'Connection Error: Could not connect to the server. Please check your network connection.';
    } else {
      errorMessage = 'Unexpected Error: ${error.toString()}';
    }
    errorMessage += st?.toString() ?? '';
    ToastUtil.showToast(errorMessage);
    LogUtil.info(errorMessage);
  }
}
