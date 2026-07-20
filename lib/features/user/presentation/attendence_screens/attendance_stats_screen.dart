import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/logic/attendance_stats_logic.dart';
import 'package:flutter_worksmart_app/shared/widget/common/attendance_stats_skeleton_loading.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';

class AttendanceStatsScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const AttendanceStatsScreen({super.key, this.loginData});

  @override
  State<AttendanceStatsScreen> createState() => _AttendanceStatsScreenState();
}

class _AttendanceStatsScreenState extends AttendanceStatsLogic {
  @override
  Widget build(BuildContext context) {
    // Guard against empty monthlyStats during initial load
    if (monthlyStats.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: const AttendanceStatsSkeletonLoading(),
      );
    }

    final currentStats = monthlyStats[selectedMonthIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCircularRateChart(currentStats),
            const SizedBox(height: 15),
            _buildSummaryStatsRow(currentStats),
            const SizedBox(height: 20),
            _buildMonthlyTrendSection(
              currentStats,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 20),
            _buildShiftFilterRow().animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 20),
            _buildHistorySectionHeader(
              currentStats,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 10),
            _buildAttendanceHistoryList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        IconButton(
          onPressed: () {
            Navigator.pushNamed(
              context,
              AppRoute.attendanCalendarScreen,
              arguments: widget.loginData,
            );
          },
          icon: Icon(
            Icons.calendar_month,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
      automaticallyImplyLeading: false,
      title: Text(
        AppStrings.tr('my_stats'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCircularRateChart(Map<String, dynamic> currentStats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(selectedMonthIndex),
          tween: Tween<double>(begin: 0, end: currentStats['percentage']),
          duration: const Duration(seconds: 1),
          curve: Curves.easeOutQuart,
          builder: (context, value, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 12,
                    backgroundColor: Theme.of(
                      context,
                    ).dividerColor.withOpacity(0.1),
                    color: Theme.of(context).colorScheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                _buildChartCenterText(value, currentStats),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartCenterText(
    double value,
    Map<String, dynamic> currentStats,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${(value * 100).toInt()}%",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          AppStrings.tr('attendance_rate'),
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            AppStrings.tr(currentStats['monthKey']),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB78103),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStatsRow(Map<String, dynamic> currentStats) {
    return Row(
      children: [
        _buildStatCard(
          Icons.check_circle_outline,
          AppStrings.tr('present'),
          currentStats['present'].toString(),
          Colors.green,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(width: 10),
        _buildStatCard(
          Icons.access_time,
          AppStrings.tr('late'),
          currentStats['late'].toString(),
          Colors.orange,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(width: 10),
        _buildStatCard(
          Icons.cancel_outlined,
          AppStrings.tr('absent'),
          currentStats['absent'].toString(),
          Colors.red,
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildMonthlyTrendSection(Map<String, dynamic> currentStats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.tr('monthly_trend'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildYearChip(currentStats['year']),
            ],
          ),
          const SizedBox(height: 20),
          _buildBarChart(),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: 180,
        width: MediaQuery.of(context).size.width - 80,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(monthlyStats.length, (index) {
            final stat = monthlyStats[index];
            return _buildClickableBar(
              index: index,
              label: AppStrings.tr(stat['monthKey']),
              percentage: stat['percentage'],
              isActive: index == selectedMonthIndex,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildShiftFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(AppStrings.tr('all_shifts'), 'All'),
          const SizedBox(width: 10),
          _buildFilterChip(AppStrings.tr('late'), 'Late'),
          const SizedBox(width: 10),
          _buildFilterChip(AppStrings.tr('absent'), 'Absent'),
        ],
      ),
    );
  }

  Widget _buildHistorySectionHeader(Map<String, dynamic> currentStats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppStrings.tr('monthly_attendance'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          "${AppStrings.tr(currentStats['monthKey'])} $selectedYear",
          style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAttendanceHistoryList() {
    final filteredData = getFilteredAttendanceData();
    return filteredData.isEmpty
        ? Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DataEmptyState(
              imageAsset: AppImg.emptyState,
              message: AppStrings.tr('no_records'),
            ),
          )
        : SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filteredData.length,
              itemBuilder: (context, index) {
                final item = filteredData[index];
                return _buildHistoryListItem(item);
              },
            ),
          );
  }

  Widget _buildYearChip(int year) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        "$year",
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHistoryListItem(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoute.attendanceDetail,
        arguments: {
          'date': item['date'],
          'day': AppStrings.tr(item['day']),
          'status': AppStrings.tr(item['status']),
          'color': item['color'],
          'checkIn': item['checkIn'],
          'checkOut': item['checkOut'],
          'hours': item['hours'],
          'isLate': item['isLate'],
        },
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['date'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppStrings.tr(item['day']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
            _buildStatusBadge(item),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> item) {
    final statusText = AppStrings.tr(item['status']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (item['color'] as Color).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            item['status'] == 'leave'
                ? Icons.access_time
                : item['status'] == 'absent'
                ? Icons.cancel
                : Icons.check_circle,
            size: 14,
            color: item['color'],
          ),
          const SizedBox(width: 5),
          Text(
            statusText,
            style: TextStyle(
              color: item['color'],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableBar({
    required int index,
    required String label,
    required double percentage,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => setState(() => selectedMonthIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1.0 : 0.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${(percentage * 100).toInt()}%",
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            width: 30,
            height: animateChart ? 120 * percentage : 0,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFB0BEC5).withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: isActive
                  ? Border.all(color: AppColors.secondary, width: 2)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? Theme.of(context).textTheme.bodyLarge?.color
                  : AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String count,
    Color color,
  ) {
    return Expanded(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: double.infinity,
          key: ValueKey(count),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final bool isSelected = selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textGrey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
