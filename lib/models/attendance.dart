class Attendance {
  final String id;
  final String workDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status;
  final double? workHours;

  /// 'leave' | 'emergency' | null — set when the day is covered by an approved
  /// request. NOTE: a partial-day emergency keeps status 'on_time' and only
  /// carries this, so "is this day covered?" is answered here, not by status.
  final String? requestKind;

  /// The request's type name ("Annual leave", "Illness"), null if not covered.
  final String? requestTypeName;

  Attendance({
    required this.id,
    required this.workDate,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.workHours,
    this.requestKind,
    this.requestTypeName,
  });

  bool get checkedIn => checkInTime != null;
  bool get checkedOut => checkOutTime != null;

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory Attendance.fromJson(Map<String, dynamic> j) {
    return Attendance(
      id: (j['id'] ?? '').toString(),
      workDate: (j['workDate'] ?? '').toString(),
      checkInTime: _dt(j['checkInTime']),
      checkOutTime: _dt(j['checkOutTime']),
      // Must match the AttendanceStatus enum: tr('status_$status') is a dynamic
      // key, so a stale value renders the raw key as visible text.
      status: (j['status'] ?? 'on_time').toString(),
      workHours: j['workHours'] == null
          ? null
          : double.tryParse(j['workHours'].toString()),
      requestKind: j['requestKind']?.toString(),
      requestTypeName: j['requestTypeName']?.toString(),
    );
  }
}
