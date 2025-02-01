import 'dart:io';

import 'package:http/io_client.dart';

class ProxyRepo {
  static IOClient getProxyClient() {
    HttpClient client = HttpClient();
    client.findProxy = (uri) {
      return 'PROXY 192.168.10.10:8888';
    };
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(client);
  }
}
