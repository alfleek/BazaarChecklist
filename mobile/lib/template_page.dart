import 'package:flutter/material.dart';

@Deprecated('Legacy template page; not used in current app flow.')
class TemplatePage extends StatelessWidget {
  const TemplatePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Template page placeholder'),
      ),
    );
  }
}
