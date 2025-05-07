import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';

typedef HomeNotifier = NotifierProvider<HomeProvider, void>;

final homeProvider = HomeNotifier(HomeProvider.new);

class HomeProvider extends Notifier<void> {
  late HubConnection _hubConnection;
  double? lat;
  double? lon;
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
        if (lat != null && lon != null) {
          lat = location['lat'];
          lon = location['lon'];
        } else {
          debugPrint("Invalid location data received.");
        }

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
    sendLocation(BuildContext context) {
    // Send the current user's location to the SignalR server
    if (position == null) {
      debugPrint("Position is null, cannot send location.");
      return;
    }
    _hubConnection
        .invoke("SendLatLon", args: [position!.latitude, position!.longitude])
        .then((_) {
          debugPrint("Location sent successfully.");
          if (!context.mounted) return;
          // Show a Snackbar message when the location is sent
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location sent successfully.'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        })
        .catchError((e) {
          debugPrint("Error sending location: $e");
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending location'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        });
  }
}
