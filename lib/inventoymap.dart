import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const LatLng _dGooglePlex = LatLng(27.6950, 85.3149);  // Destination 1
  static const LatLng _kGooglePlex = LatLng(27.6862, 85.3149);  // Destination 2
  static const LatLng _TGooglePlex = LatLng(27.6588, 85.3247);  // Destination 3

  // New starting point for the truck
  static const LatLng _startLocation = LatLng(27.6660, 85.3227); // Truck starting point

  LatLng _currentTruckLocation = _startLocation;
  late GoogleMapController _mapController;
  Timer? _movementTimer;
  int _currentDestinationIndex = 0;
  double _speedKmPerHr = 40; // Truck speed in km/h

  final List<LatLng> _destinations = [_TGooglePlex, _kGooglePlex, _dGooglePlex]; // Reverse order

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startMovement();
  }

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _startMovement() {
    _movementTimer?.cancel();
    _movementTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentDestinationIndex < _destinations.length - 1) {
        // Move the truck to the next destination
        _currentTruckLocation = _moveTruckToNextDestination();
        setState(() {
          _updateMarkers();
          _updatePolylines();
        });
      } else {
        // Stop the truck at the last destination
        _movementTimer?.cancel();
        _showNotification('Truck has reached the final destination!');
      }

      // Show notification when a destination is reached
      if (_currentTruckLocation == _destinations[_currentDestinationIndex]) {
        _showNotification('Truck has reached destination ${_currentDestinationIndex + 1}');
        _currentDestinationIndex++;
      }
    });
  }

  LatLng _moveTruckToNextDestination() {
    LatLng destination = _destinations[_currentDestinationIndex + 1];
    double distance = _calculateDistance(_currentTruckLocation, destination);
    double timeInSeconds = (distance / _speedKmPerHr) * 3600; // Time in seconds

    // Interpolation for smooth movement
    double ratio = 1.0 / (timeInSeconds * 2); // Slow down the movement
    double lat = _currentTruckLocation.latitude + (destination.latitude - _currentTruckLocation.latitude) * ratio;
    double lng = _currentTruckLocation.longitude + (destination.longitude - _currentTruckLocation.longitude) * ratio;

    return LatLng(lat, lng);
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double pi = 3.141592653589793;
    const double radius = 6371; // Earth's radius in kilometers

    double dLat = (to.latitude - from.latitude) * pi / 180;
    double dLng = (to.longitude - from.longitude) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(from.latitude * pi / 180) * cos(to.latitude * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radius * c; // Distance in kilometers
  }

  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      channelDescription: 'Truck Arrival Notification',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Truck Notification',
      message,
      notificationDetails,
    );
  }

  void _updateMarkers() {
    _markers.clear();
    for (int i = 0; i < _destinations.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId('destination_$i'),
          position: _destinations[i],
          infoWindow: InfoWindow(
            title: 'Destination ${i + 1}',
            snippet: 'Latitude: ${_destinations[i].latitude}, Longitude: ${_destinations[i].longitude}',
          ),
        ),
      );
    }
    _markers.add(
      Marker(
        markerId: MarkerId('truck'),
        position: _currentTruckLocation,
        infoWindow: InfoWindow(
          title: 'Truck Location',
          snippet: 'Latitude: ${_currentTruckLocation.latitude}, Longitude: ${_currentTruckLocation.longitude}',
        ),
      ),
    );
  }

  void _updatePolylines() {
    _polylines.clear();
    List<LatLng> path = [];
    path.addAll(_destinations);
    path.add(_currentTruckLocation);
    _polylines.add(
      Polyline(
        polylineId: PolylineId('truck_path'),
        points: path,
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double distance = _calculateDistance(_currentTruckLocation, _destinations[_currentDestinationIndex]);

    return Scaffold(
      appBar: AppBar(
        title: Text('Truck Location'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Navigate back when the back button is pressed
          },
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentTruckLocation,
              zoom: 13.5,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Card(
                  color: Colors.blue,
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ListTile(
                    title: Text(
                      'Distance to Destination: ${distance.toStringAsFixed(2)} km',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Card(
                  color: Colors.blue,
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ListTile(
                    title: Text(
                      'Driver Information',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Name: Shrestha Avi\nPhone: +999999\nLicense Plate: 9980',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
