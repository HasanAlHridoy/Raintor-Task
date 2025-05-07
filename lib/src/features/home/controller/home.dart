import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';

typedef HomeNotifier = NotifierProvider<HomeProvider, void>;

final homeProvider = HomeNotifier(HomeProvider.new);

class HomeProvider extends Notifier<void> {
  late HubConnection _hubConnection;
  double lat = 0.0;
  double lon = 0.0;
  Position? position;

  @override
  void build() {
    _connectToSignalR();
    _getCurrentLocation();

    // Properly stopping the connection when the widget is disposed
    ref.onDispose(() {
      _hubConnection.stop();
      debugPrint("Hub connection stopped.");
    });
  }

  // getters

  void _connectToSignalR() {
    _hubConnection =
        HubConnectionBuilder()
            .withUrl("https://raintor-api.devdata.top/hub") // SignalR Hub URL
            .build();

    // Log connection attempt
    debugPrint("Connecting to SignalR Hub...");

    // Listen for ReceiveLatLon event (location update from other user)
    _hubConnection.on("ReceiveLatLon", (args) {
      final location = args?[0] as Map<String, dynamic>?;
      if (location != null) {
        debugPrint("Received location: $location");
        lat = location['lat'];
        lon = location['lon'];
        ref.notifyListeners();
      } else {
        debugPrint("Received invalid location data.");
      }
    });

    // Start the connection and log success/error
    _hubConnection
        .start()!
        .then((_) {
          debugPrint("Connected to SignalR Hub.");
        })
        .catchError((e) {
          debugPrint("Error connecting: $e");
        });
  }

  // Fetch the current location using Geolocator
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        debugPrint("Location permission is denied.");
        return;
      }
    }

    // Get current location
    position = await Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.high));

    // Update the current location of the current user (e.g., User A or User B)
    lat = position!.latitude;
    lon = position!.longitude;
    ref.notifyListeners();
    debugPrint("Current location: Latitude: $lat, Longitude: $lon");
  }

  // Send latitude and longitude to the server
  void sendLocation() {
    // Send the current user's location to the SignalR server
    _hubConnection
        .invoke("SendLatLon", args: [position!.latitude, position!.longitude])
        .then((_) {
          debugPrint("Location sent successfully.");
        })
        .catchError((e) {
          debugPrint("Error sending location: $e");
        });
  }
}
