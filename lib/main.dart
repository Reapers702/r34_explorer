import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: false,
      ),
      debugShowCheckedModeBanner: false,
      routes: PageRoutes.routes,
      initialRoute: PageRoutes.indexPage,
    );
  }
}
