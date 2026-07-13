class Attendance {
  final String id;
  final String workDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status;
  final double? workHours;

  Attendance({
    required this.id,
    required this.workDate,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.workHours,
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
      status: (j['status'] ?? 'present').toString(),
      workHours: j['workHours'] == null
          ? null
          : double.tryParse(j['workHours'].toString()),
    );
  }
}
