import 'package:flutter/material.dart';

@Deprecated('Legacy template page; not used in current app flow.')
class MyThirdPage extends StatelessWidget {
  const MyThirdPage({super.key, required this.title});

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
