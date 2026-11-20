import 'package:flutter/material.dart';

class SeriesIconMapper {
  static const IconData fallbackIcon = Icons.circle;

  static const Map<String, IconData> availableIcons = {
    'thermostat': Icons.thermostat,
    'water_drop': Icons.water_drop,
    'bolt': Icons.bolt,
    'air': Icons.air,
    'speed': Icons.speed,
    'show_chart': Icons.show_chart,
    'sensors': Icons.sensors,
    'device_thermostat': Icons.device_thermostat,
  };

  static IconData fromName(String? iconName) {
    if (iconName == null) return fallbackIcon;
    final key = iconName.trim().toLowerCase();
    return availableIcons[key] ?? fallbackIcon;
  }

  static String? normalizeName(String? iconName) {
    if (iconName == null) return null;
    final key = iconName.trim().toLowerCase();
    if (key.isEmpty) return null;
    return availableIcons.containsKey(key) ? key : null;
  }
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] as String,
      tokenType: (json['tokenType'] ?? 'Bearer') as String,
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 3600,
    );
  }
}

class Series {
  final String id;
  final String name;
  final double minValue;
  final double maxValue;
  final String color; // format #RRGGBB
  final String? icon;
  final String? unit;

  Series({
    required this.id,
    required this.name,
    required this.minValue,
    required this.maxValue,
    required this.color,
    this.icon,
    this.unit,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'].toString(),
      name: json['name'] as String,
      minValue: (json['minValue'] as num).toDouble(),
      maxValue: (json['maxValue'] as num).toDouble(),
      color: json['color'] as String,
      icon: json['icon'] as String?,
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toInputJson() => {
        'name': name,
        'minValue': minValue,
        'maxValue': maxValue,
        'color': color,
        'icon': icon,
        'unit': unit,
      };

  Color get flutterColor {
    return colorFromHex(color);
  }

  IconData get flutterIcon {
    return SeriesIconMapper.fromName(icon);
  }

  static Color colorFromHex(String hexColor) {
    final cleaned = hexColor.trim().replaceFirst('#', '');
    if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleaned)) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return const Color(0xFF1F77B4);
  }

  static String colorToHex(Color color) {
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    final rh = r.toRadixString(16).padLeft(2, '0');
    final gh = g.toRadixString(16).padLeft(2, '0');
    final bh = b.toRadixString(16).padLeft(2, '0');
    return '#$rh$gh$bh'.toLowerCase();
  }
}

class Measurement {
  final String id;
  final String seriesId;
  final String? sensorId;
  final double value;
  final DateTime timestamp;

  Measurement({
    required this.id,
    required this.seriesId,
    this.sensorId,
    required this.value,
    required this.timestamp,
  });

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: json['id'].toString(),
      seriesId: json['seriesId'].toString(),
      sensorId: json['sensorId']?.toString(),
      value: (json['value'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    );
  }
}

class Sensor {
  final String id;
  final String name;
  final String seriesId;
  final DateTime? createdAt;
  final DateTime? lastMeasurementAt;
  final String? apiKey;

  Sensor({
    required this.id,
    required this.name,
    required this.seriesId,
    this.createdAt,
    this.lastMeasurementAt,
    this.apiKey,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      id: json['id'].toString(),
      name: json['name'] as String,
      seriesId: json['seriesId'].toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)?.toLocal()
          : null,
      lastMeasurementAt: json['lastMeasurementAt'] != null
          ? DateTime.tryParse(json['lastMeasurementAt'] as String)?.toLocal()
          : null,
      apiKey: json['apiKey'] as String?,
    );
  }
}