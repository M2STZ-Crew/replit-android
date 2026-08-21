class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.icon,
    required this.cityName,
    required this.fetchedAt,
  });

  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String description;
  final String icon;
  final String cityName;
  final DateTime fetchedAt;

  factory WeatherData.fromApiResponse(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;

    return WeatherData(
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num).toDouble(),
      description: weather['description'] as String,
      icon: weather['icon'] as String,
      cityName: json['name'] as String,
      fetchedAt: DateTime.now(),
    );
  }

  factory WeatherData.fromMap(Map<String, dynamic> map) {
    return WeatherData(
      temperature: (map['temperature'] as num).toDouble(),
      feelsLike: (map['feels_like'] as num).toDouble(),
      humidity: map['humidity'] as int,
      windSpeed: (map['wind_speed'] as num).toDouble(),
      description: map['description'] as String,
      icon: map['icon'] as String,
      cityName: map['city_name'] as String,
      fetchedAt: DateTime.parse(map['fetched_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'feels_like': feelsLike,
      'humidity': humidity,
      'wind_speed': windSpeed,
      'description': description,
      'icon': icon,
      'city_name': cityName,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }

  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  bool get isStale =>
      DateTime.now().difference(fetchedAt).inMinutes > 30;
}
