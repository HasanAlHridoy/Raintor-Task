import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raitor_task/src/features/home/controller/home.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text("SignalR Location Sharing"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show received location data (only updates when another user sends it)
            Text("Received Location:"),
            SizedBox(height: 10),
            Text('lat : ${notifier.lat}'),
            Text('lon : ${notifier.lon}'),
            SizedBox(height: 10),
            ElevatedButton(onPressed: notifier.sendLocation, child: Text("Send Location")),
          ],
        ),
      ),
    );
  }
}
