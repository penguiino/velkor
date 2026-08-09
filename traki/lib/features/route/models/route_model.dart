class StopModel {
  final String id;
  final int orderIndex;
  final String customerName;
  final String? address;
  final double lat;
  final double lng;
  final String? notes;
  final String status; // pending | arrived | completed | skipped
  final int? arrivedAt;
  final int? departedAt;

  StopModel({
    required this.id,
    required this.orderIndex,
    required this.customerName,
    required this.lat,
    required this.lng,
    required this.status,
    this.address,
    this.notes,
    this.arrivedAt,
    this.departedAt,
  });

  factory StopModel.fromJson(Map<String, dynamic> json) {
    return StopModel(
      id: json['id'] as String,
      orderIndex: json['orderIndex'] as int? ?? 0,
      customerName: json['customerName'] as String? ?? '',
      address: json['address'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      arrivedAt: json['arrivedAt'] as int?,
      departedAt: json['departedAt'] as int?,
    );
  }
}

class RouteModel {
  final String id;
  final String? name;
  final String routeDate;
  final String status; // pending | active | completed
  final int? startedAt;
  final int? completedAt;
  final List<StopModel> stops;
  final String? currentStopId;
  final String? nextStopId;
  final int completedStopCount;
  final int totalStopCount;

  RouteModel({
    required this.id,
    required this.routeDate,
    required this.status,
    required this.stops,
    required this.completedStopCount,
    required this.totalStopCount,
    this.name,
    this.startedAt,
    this.completedAt,
    this.currentStopId,
    this.nextStopId,
  });

  StopModel? get currentStop {
    if (currentStopId == null) return null;
    for (final s in stops) {
      if (s.id == currentStopId) return s;
    }
    return null;
  }

  StopModel? get nextStop {
    if (nextStopId == null) return null;
    for (final s in stops) {
      if (s.id == nextStopId) return s;
    }
    return null;
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final stopsJson = json['stops'] as List<dynamic>? ?? [];

    return RouteModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      routeDate: json['routeDate'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      startedAt: json['startedAt'] as int?,
      completedAt: json['completedAt'] as int?,
      stops: stopsJson
          .map((s) => StopModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      currentStopId: json['currentStopId'] as String?,
      nextStopId: json['nextStopId'] as String?,
      completedStopCount: json['completedStopCount'] as int? ?? 0,
      totalStopCount: json['totalStopCount'] as int? ?? 0,
    );
  }
}
