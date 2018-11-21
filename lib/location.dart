import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


enum LocationActivityType {
  other,
  automotiveNavigation,
  fitness,
  otherNavigation,
}

class LocationPoint {
  LocationPoint (
      double _ts, this.latitude, this.longitude, this.altitude, this.speed) :
        _time = _ts,
        ts = DateTime.fromMillisecondsSinceEpoch( (_ts * 1000.0).floor() );


  factory LocationPoint.fromJson(String jsonLocation) {
    final Map<String, dynamic> location = json.decode(jsonLocation);
    return LocationPoint(location['time'], location['latitude'],
        location['longitude'], location['altitude'], location['speed']);
  }

  factory LocationPoint.fromHasnMap( Map<String,double> d ) {
    return LocationPoint( d['timestamp'], d['latitude'], d['longitude'], d['altitude'], d['speed']);
  }

  final double _time;
  final DateTime ts;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;

  DateTime get time =>
      DateTime.fromMillisecondsSinceEpoch((_time * 1000).round(), isUtc: true);

  @override
  String toString() =>
      '[$time] ($latitude, $longitude) altitude: $altitude m/s: $speed ts:${ts}';

  String toJson() {
    final Map<String, double> location = <String, double>{
      'time': _time,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
    };
    return json.encode(location);
  }
}

class Location {
  static const MethodChannel _channel = const MethodChannel('lyokone/location');
  static const EventChannel _stream = const EventChannel('lyokone/locationstream');
  static const EventChannel _backgroundEvents = const EventChannel('lyokone/backgroundlocation');

  static const String _kCancelLocationUpdates = 'cancelLocationUpdates';
  static const String _kMonitorLocationChanges = 'monitorLocationChanges';

  Stream<Map<String,double>> _onLocationChanged;
  static Stream<dynamic> _eventsFetch;

  bool pauseLocationUpdatesAutomatically = false;
  bool showsBackgroundLocationIndicator = true;
  LocationActivityType activityType = LocationActivityType.other;

  Future<Map<String, double>> getLocation() => _channel
      .invokeMethod('getLocation')
      .then((result) => result.cast<String, double>());

  Future<int> wasStartedByLocationManager() => _channel
      .invokeMethod('wasStartedByLocationManager')
      .then((result) => result.cast<int>());

  Future<bool> hasPermission() => _channel
    .invokeMethod('hasPermission')
    .then((result) => result == 1);

  Future<int> start({int accuracy, int interval}) => _channel
      .invokeMethod('start');

  Future<int> stop() => _channel
      .invokeMethod('stop');

  Stream<Map<String, double>> onLocationChanged() {
    if (_onLocationChanged == null) {
      _onLocationChanged = _stream
          .receiveBroadcastStream()
          .map<Map<String, double>>(
              (element) => element.cast<String, double>());
    }
    return _onLocationChanged;
  }

  static Future<bool> registerHeadlessTask(Function(LocationPoint location) callback) {
    WidgetsFlutterBinding.ensureInitialized();

    if (_backgroundEvents != null) {
      _eventsFetch = _backgroundEvents.receiveBroadcastStream();

      _eventsFetch.listen((dynamic v) {
        final p = LocationPoint.fromHasnMap( Map<String,double>.from( v ) );
        callback(p);
      });
    }
    return Future.value(true);
  }

  Future<bool> monitorSignificantLocationChanges({bool pauseAutomatically, bool showBackgroundIndicator, LocationActivityType type}) {
    if(pauseAutomatically != null) {
      pauseLocationUpdatesAutomatically = pauseAutomatically;
    }
    if(showBackgroundIndicator != null) {
      showsBackgroundLocationIndicator = showBackgroundIndicator;
    }
    if(type != null) {
      activityType = type;
    }

    return _channel.invokeMethod(_kMonitorLocationChanges, <dynamic>[
      pauseLocationUpdatesAutomatically,
      showsBackgroundLocationIndicator,
      activityType.index
    ]).then<bool>((dynamic result) => result);
  }

  /// Stop all location updates.
  Future<void> cancelLocationUpdates() =>
      _channel.invokeMethod(_kCancelLocationUpdates);

}
