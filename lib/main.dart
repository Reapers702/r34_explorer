import 'package:flutter/material.dart';
import 'package:r34_video/page/page_routes.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      routes: PageRoutes.routes,
      initialRoute: PageRoutes.homePage,
    );
  }
}


// return GestureDetector(
//   onTap: () async {
//     log(data[index].previewUrl);
//     final Uri uri = Uri.parse(data[index].previewUrl);
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(
//         uri,
//         mode: LaunchMode.externalApplication,
//       );
//     } else {
//       log('Could not launch $uri');
//     }
//   },
//   child: Text(
//     data[index].title,
//     overflow: TextOverflow.ellipsis,
//   ),
// );