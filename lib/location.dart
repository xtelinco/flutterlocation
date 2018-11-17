import 'dart:async';

import 'package:flutter/services.dart';


class Location {
  static const MethodChannel _channel = const MethodChannel('lyokone/location');
  static const EventChannel _stream = const EventChannel('lyokone/locationstream');
  int _streamAccuracy;
  int _streamInterval;

  Stream<Map<String,double>> _onLocationChanged;

  Future<Map<String,double>> get getLocation =>
      _channel.invokeMethod('getLocation');

  Future<String> get getAuthorizationStatus =>
      _channel.invokeMethod('getAuthorizationStatus');

  Future<String> authorize(String type) {
    return _channel.invokeMethod('authorize', {
      'type': type
    } );
  }

  Future<int> wasStartedByLocationManager() {
    return _channel.invokeMethod('wasStartedByLocationManager');
  }

  Future<int> stopMonitoringSignificant() {
    return _channel.invokeMethod('stopMonitoringSignificant');
  }
  Future<int> startMonitoringSignificant() {
    return _channel.invokeMethod('startMonitoringSignificant');
  }

  Future<Map<String,double>> getLastSignificantLocation() =>
      _channel.invokeMethod('getLastSignificantLocation');

  Future<int> stop() {
    return _channel.invokeMethod('stop');
  }

  Future<int> start({int accuracy=1, int interval=10000}) {
    _streamAccuracy = accuracy;
    _streamInterval = interval;
    return _channel.invokeMethod('start',<String,int>{
      'interval': interval,
      'accuracy': accuracy,
      'start': 1
    });
  }


  Future<Stream<Map<String, double>>> get  onLocationChanged async {
    if (_onLocationChanged == null) {
      _onLocationChanged =
          _stream.receiveBroadcastStream(<String,int>{
            'interval': 10000,
            'accuracy': 1,
            'start': 1
          });
      _streamAccuracy = 1;
      _streamInterval = 10000;
    }
    return _onLocationChanged;
  }

  Future<Stream<Map<String, double>>> getLocationChangedListener({int accuracy=1, int interval=10000, bool start=true}) async {
    if (_onLocationChanged == null ) {
      _onLocationChanged =
          _stream.receiveBroadcastStream(<String,int>{
            'interval': interval,
            'accuracy': accuracy,
            'start': start ? 1 : 0
          });
      _streamAccuracy = accuracy;
      _streamInterval = interval;
    }else if (accuracy != _streamAccuracy || interval != _streamInterval) {
      start(accuracy: accuracy, interval: interval);
    }
    return _onLocationChanged;
  }


}
