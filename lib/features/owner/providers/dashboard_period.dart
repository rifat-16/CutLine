enum DashboardPeriod { today, week, month, year }

extension DashboardPeriodLabel on DashboardPeriod {
  String get label {
    switch (this) {
      case DashboardPeriod.today:
        return 'Today';
      case DashboardPeriod.week:
        return 'This week';
      case DashboardPeriod.month:
        return 'This month';
      case DashboardPeriod.year:
        return 'This year';
    }
  }
}
