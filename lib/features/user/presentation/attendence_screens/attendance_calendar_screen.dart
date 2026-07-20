import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/shared/model/activity_models/attendance_record.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const AttendanceCalendarScreen({super.key, this.loginData});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  late UserProfile _currentUser;
  List<AttendanceRecord> _userAttendanceRecords = [];
  late String? loggedInUserId;

  late int _selectedDay;
  late DateTime _currentViewDate;
  bool _isLoading = true;
  bool _isDownloading = false;
  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = now.day;
    _currentViewDate = DateTime(now.year, now.month);
    loggedInUserId = _resolveUserId();
    _loadData();
  }

  String _resolveUserId() {
    return (widget.loginData?['uid'] ??
            widget.loginData?['user_id'] ??
            widget.loginData?['userId'] ??
            '')
        .toString()
        .trim();
  }

  Future<void> _loadData() async {
    try {
      final users = await _realtimeDataController.fetchUserRecords();
      final attendanceRecords = await _realtimeDataController
          .fetchAttendanceRecords();

      final currentUserData = users.firstWhere(
        (user) =>
            (user['uid'] ?? user['user_id'] ?? user['userId'])
                ?.toString()
                .trim() ==
            loggedInUserId,
        orElse: () => defaultUserRecord,
      );

      _currentUser = UserProfile.fromJson(currentUserData);

      _userAttendanceRecords = attendanceRecords
          .where((record) => record['uid'] == _currentUser.uid)
          .map((json) => AttendanceRecord.fromJson(json))
          .toList();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('attendance_proof_failed')}: $error'),
        ),
      );
    }
  }

  Future<void> _downloadAttendanceProof() async {
    if (_isLoading || _isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final monthLabel = _getLocalizedMonthYear(_currentViewDate);
      final monthRecords = _userAttendanceRecords.where((record) {
        final recordDate = DateTime.parse(record.date);
        return recordDate.year == _currentViewDate.year &&
            recordDate.month == _currentViewDate.month;
      }).toList()..sort((a, b) => a.date.compareTo(b.date));

      final selectedDayData = _getDayData(_selectedDay);
      final presentCount = monthRecords
          .where((record) => record.status == 'on_time')
          .length;
      final lateCount = monthRecords
          .where((record) => record.status == 'late')
          .length;
      final absentCount = monthRecords
          .where((record) => record.status == 'absent')
          .length;
      final generatedAt = DateFormat(
        'dd MMM yyyy, HH:mm',
      ).format(DateTime.now());

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Text(
                'Attendance Proof',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Generated at: $generatedAt'),
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Employee Details',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('User ID: ${_currentUser.uid}'),
                    pw.Text(
                      'Name: ${_currentUser.displayName.isNotEmpty ? _currentUser.displayName : '-'}',
                    ),
                    pw.Text(
                      'Role: ${_currentUser.roleTitle.isNotEmpty ? _currentUser.roleTitle : '-'}',
                    ),
                    pw.Text('Month: $monthLabel'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                children: [
                  _buildPdfSummaryCard(
                    'Present',
                    presentCount.toString(),
                    PdfColors.green,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfSummaryCard(
                    'Late',
                    lateCount.toString(),
                    PdfColors.orange,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfSummaryCard(
                    'Absent',
                    absentCount.toString(),
                    PdfColors.red,
                  ),
                  pw.SizedBox(width: 8),
                  _buildPdfSummaryCard(
                    'Attendance',
                    '${_getMonthAttendanceRate(_currentViewDate)}%',
                    PdfColors.blue,
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Selected Day',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(DateTime(_currentViewDate.year, _currentViewDate.month, _selectedDay))}',
                    ),
                    pw.Text('Check In: ${selectedDayData['in']}'),
                    pw.Text('Check Out: ${selectedDayData['out']}'),
                    pw.Text('Total Hours: ${selectedDayData['h']}'),
                    pw.Text(
                      'Status: ${_formatProofStatus(selectedDayData['s'] as String)}',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Monthly Records',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Date',
                  'Check In',
                  'Check Out',
                  'Hours',
                  'Status',
                ],
                data: monthRecords.isEmpty
                    ? [
                        ['No records found', '-', '-', '-', '-'],
                      ]
                    : monthRecords
                          .map(
                            (record) => [
                              record.date,
                              record.checkIn,
                              record.checkOut,
                              record.totalHours.toStringAsFixed(1),
                              _formatProofStatus(record.status),
                            ],
                          )
                          .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(0.8),
                  4: const pw.FlexColumnWidth(1),
                },
              ),
            ];
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final fileName =
          'attendance_proof_${_currentUser.uid}_${DateFormat('yyyy_MM').format(_currentViewDate)}.pdf';

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$fileName').writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles([XFile(file.path)], subject: 'Attendance Proof');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('attendance_proof_ready'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.tr('attendance_proof_failed')}: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  pw.Widget _buildPdfSummaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 10, color: color)),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatProofStatus(String status) {
    switch (status) {
      case 'on_time':
        return 'On Time';
      case 'late':
        return 'Late';
      case 'absent':
        return 'Absent';
      default:
        return status;
    }
  }

  String _getLocalizedMonthYear(DateTime date) {
    String monthKey = 'month_${DateFormat('MMM').format(date).toLowerCase()}';
    return "${AppStrings.tr(monthKey)} ${date.year}";
  }

  Map<String, dynamic> _getDayData(int day) {
    final searchDate = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(_currentViewDate.year, _currentViewDate.month, day));

    final match = _userAttendanceRecords
        .where((record) => record.date == searchDate)
        .toList();

    if (match.isEmpty) {
      return {
        "in": "--:--",
        "out": "--:--",
        "h": "0",
        "s": "no_data",
        "c": Colors.grey,
      };
    }

    final record = match.first;
    final color = record.status == 'on_time'
        ? Colors.green
        : record.status == 'late'
        ? Colors.orange
        : Colors.red;

    return {
      "in": record.checkIn,
      "out": record.checkOut,
      "h": record.totalHours.toStringAsFixed(1),
      "s": record.status,
      "c": color,
    };
  }

  int _getMonthAttendanceRate(DateTime date) {
    final monthRecords = _userAttendanceRecords.where((record) {
      final recordDate = DateTime.parse(record.date);
      return recordDate.year == date.year && recordDate.month == date.month;
    }).toList();

    if (monthRecords.isEmpty) return 0;

    final onTimeCount = monthRecords
        .where((record) => record.status == 'on_time')
        .length;
    final rate = (onTimeCount / monthRecords.length) * 100;

    return rate.round();
  }

  @override
  Widget build(BuildContext context) {
    var dayData = _getDayData(_selectedDay);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildCalendarHeader(),
                  _buildLegend().animate().fadeIn(delay: 200.ms),
                  _buildCalendarGrid(),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildDayDetailView(dayData),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        AppStrings.tr('attendance_calendar_title'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.file_download_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: _downloadAttendanceProof,
        ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getLocalizedMonthYear(_currentViewDate),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                "${_getMonthAttendanceRate(_currentViewDate)}% ${AppStrings.tr('avg_attendance')}",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavCircle(Icons.chevron_left, () => _updateMonth(-1)),
              const SizedBox(width: 15),
              _buildNavCircle(Icons.chevron_right, () => _updateMonth(1)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  void _updateMonth(int add) {
    setState(() {
      _currentViewDate = DateTime(
        _currentViewDate.year,
        _currentViewDate.month + add,
      );
    });
  }

  Widget _buildNavCircle(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: Theme.of(context).iconTheme.color),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildLegendDot(Colors.green, AppStrings.tr('present')),
          const SizedBox(width: 15),
          _buildLegendDot(Colors.orange, AppStrings.tr('late')),
          const SizedBox(width: 15),
          _buildLegendDot(Colors.red, AppStrings.tr('absent')),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final List<String> days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentViewDate.year,
      _currentViewDate.month,
    );
    final firstDayOffset =
        DateTime(_currentViewDate.year, _currentViewDate.month, 1).weekday - 1;

    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: days
              .map(
                (d) => Text(
                  d,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: 35,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
          ),
          itemBuilder: (context, index) {
            int dayNum = index - firstDayOffset + 1;
            bool isGrey = dayNum <= 0 || dayNum > daysInMonth;
            return GestureDetector(
              onTap: isGrey
                  ? null
                  : () => setState(() => _selectedDay = dayNum),
              child: _buildDayCell(dayNum, isGrey),
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildDayCell(int day, bool isGrey) {
    bool isSelected = _selectedDay == day && !isGrey;
    var dayData = isGrey ? null : _getDayData(day);
    Color? dotColor = (dayData != null && dayData['s'] != "no_data")
        ? dayData['c']
        : null;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  )
                : null,
          ),
          child: Center(
            child: Text(
              isGrey ? "" : "$day",
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isGrey
                          ? Colors.grey[300]
                          : Theme.of(context).textTheme.bodyLarge?.color),
              ),
            ),
          ),
        ),
        if (!isGrey && dotColor != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ).animate().scale(),
      ],
    );
  }

  Widget _buildDayDetailView(Map<String, dynamic> data) {
    return Column(
      key: ValueKey("$_selectedDay-${_currentViewDate.month}"),
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${AppStrings.tr('day_label')} $_selectedDay ${_getLocalizedMonthYear(_currentViewDate)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              _buildStatusTag(AppStrings.tr(data['s']), data['c']),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            _buildInfoCard(
              AppStrings.tr('check_in_title'),
              data['in'],
              Icons.login,
              Colors.green,
            ),
            const SizedBox(width: 10),
            _buildInfoCard(
              AppStrings.tr('check_out_title'),
              data['out'],
              Icons.logout,
              Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildTotalCard(data['h']),
      ],
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildStatusTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String time, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(String hours) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 15),
              Text(
                AppStrings.tr('total_work_hours'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            "$hours ${AppStrings.tr('hours_unit')}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
