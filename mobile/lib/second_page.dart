import 'package:flutter/material.dart';

@Deprecated('Legacy template page; not used in current app flow.')
class MySecondPage extends StatelessWidget {
  const MySecondPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Legacy page placeholder'),
      ),
    );
  }
}
