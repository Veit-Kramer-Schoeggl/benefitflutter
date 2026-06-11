import 'package:flutter/material.dart';
import 'package:benefitflutter/core/config/theme.dart';

// Helper function for 10^EXPONENT (for scaling)
double power(double base, double exp) {
  double result = 1.0;
  if (exp >= 0) {
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
  } else {
    for (int i = 0; i < -exp; i++) {
      result /= base;
    }
  }
  return result;
}

// ====================================================
// CustomBarChart
// ====================================================
class CustomBarChart extends StatelessWidget {
  final Map<int, double> data;
  final String title;
  final Map<int, String>? customLabels;

  const CustomBarChart({
    super.key,
    required this.data,
    required this.title,
    this.customLabels,
  });

  // Logic for calculating Y-axis values (scaling)
  List<int> _calculateYAxisValues(double maxDistance) {
    if (maxDistance <= 0) return [0, 5];

    final double paddedMax = maxDistance * 1.1;
    const int maxTicks = 5;

    final double range = paddedMax;
    final double roughStep = range / (maxTicks - 1);

    double exponent = 0;
    if (roughStep < 1 && roughStep > 0) {
      exponent = -1;
    } else if (roughStep > 0) {
      try {
        String expString = roughStep.toStringAsExponential().split('e')[1];
        exponent = double.parse(expString);
      } catch (e) {
        exponent = 0;
      }
    }

    final double powerOfTen = power(10, exponent);

    double niceStep = roughStep / powerOfTen;
    if (niceStep < 1.5) {
      niceStep = 1;
    } else if (niceStep < 3) {
      niceStep = 2;
    } else if (niceStep < 7.5) {
      niceStep = 5;
    } else {
      niceStep = 10;
    }

    final int finalStep = (niceStep * powerOfTen).ceil();
    final int maxLabel = ((paddedMax / finalStep).ceil()) * finalStep;

    final List<int> labels = [];
    for (int i = 0; i <= maxLabel; i += finalStep) {
      labels.add(i);
    }

    return labels;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('No data recorded for $title.'));
    }

    // Colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color darkGrey = AppTheme.darkGrey;
    final Color lightGrey = AppTheme.lightGrey;
    final Color mediumGrey = AppTheme.mediumGrey;

    const defaultWeekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    final sortedKeys = data.keys.toList()..sort();
    final double rawMaxDistance = data.values.isEmpty
        ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b);

    final List<int> yAxisLabels = _calculateYAxisValues(rawMaxDistance);
    final double maxScaleValue = yAxisLabels.isEmpty
        ? 1.0
        : yAxisLabels.last.toDouble();

    const double chartVisualHeight = 200.0;
    const double xAxisLabelHeight = 18.0;
    const double yAxisLabelWidth = 30.0;
    const double chartTotalHeight = chartVisualHeight + xAxisLabelHeight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titel
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: darkGrey),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: chartTotalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: yAxisLabelWidth,
                  height: chartVisualHeight,
                  padding: const EdgeInsets.only(right: 5),
                  child: Stack(
                    children: [
                      ...yAxisLabels.map((value) {
                        final double topPosition =
                            chartVisualHeight * (1 - (value / maxScaleValue));

                        return Positioned(
                          top: (value == maxScaleValue.toInt())
                              ? 0
                              : (value == 0)
                              ? chartVisualHeight - 12
                              : topPosition - 6,
                          right: 0,
                          child: Text(
                            value.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: darkGrey.withOpacity(0.8),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // 2. Chart area with bars, grid lines and labels
                Expanded(
                  child: SizedBox(
                    height: chartTotalHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Grid lines
                        ...yAxisLabels.where((v) => v >= 0).map((value) {
                          final double bottomPosition =
                              (value / maxScaleValue) * chartVisualHeight;
                          final double lineBottom =
                              xAxisLabelHeight + bottomPosition;

                          final Color lineColor = value == 0
                              ? mediumGrey
                              : lightGrey;

                          return Positioned(
                            bottom: lineBottom,
                            left: 0,
                            right: 0,
                            child: Container(height: 1.0, color: lineColor),
                          );
                        }),

                        // Bar visualization and X-axis labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: sortedKeys.map((key) {
                            final double value = data[key] ?? 0.0;

                            const double maxBarHeight = chartVisualHeight;
                            final double barHeight =
                                (value / maxScaleValue) * maxBarHeight;
                            final double finalBarHeight = value > 0
                                ? (barHeight < 5 ? 5 : barHeight)
                                : 0;

                            final String labelText =
                                customLabels != null &&
                                    customLabels!.containsKey(key)
                                ? customLabels![key]!
                                : (key >= 1 && key <= 7
                                      ? defaultWeekdays[key - 1]
                                      : key.toString());

                            return Expanded(
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // 1. X-axis label (below zero line)
                                  Positioned(
                                    bottom: 0,
                                    child: Container(
                                      height: xAxisLabelHeight,
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: Text(
                                          labelText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: darkGrey,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 2. Bar (starts at xAxisLabelHeight)
                                  Positioned(
                                    bottom: xAxisLabelHeight + 1,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Value label above the bar
                                        Text(
                                          value > 0
                                              ? value.toStringAsFixed(1)
                                              : '',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: darkGrey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // The bar itself
                                        Container(
                                          width: 20,
                                          height: finalBarHeight,
                                          decoration: BoxDecoration(
                                            color: value > 0
                                                ? primaryColor
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================
// CustomLineChart
// ====================================================
class CustomLineChart extends StatelessWidget {
  final Map<int, double> data;
  final String title;
  final Map<int, String> customLabels;

  const CustomLineChart({
    super.key,
    required this.data,
    required this.title,
    required this.customLabels,
  });

  // Logic for calculating Y-axis values (scaling)
  List<int> _calculateYAxisValues(double rawMaxValue) {
    if (rawMaxValue <= 0) return [0, 50];

    final double paddedMax = rawMaxValue * 1.1;
    const int maxTicks = 5;

    final double range = paddedMax;
    final double roughStep = range / (maxTicks - 1);

    double exponent = 0;
    if (roughStep < 1 && roughStep > 0) {
      exponent = -1;
    } else if (roughStep > 0) {
      try {
        String expString = roughStep.toStringAsExponential().split('e')[1];
        exponent = double.parse(expString);
      } catch (e) {
        exponent = 0;
      }
    }

    final double powerOfTen = power(10, exponent);

    double niceStep = roughStep / powerOfTen;
    if (niceStep < 1.5) {
      niceStep = 1;
    } else if (niceStep < 3) {
      niceStep = 2;
    } else if (niceStep < 7.5) {
      niceStep = 5;
    } else {
      niceStep = 10;
    }

    final int finalStep = (niceStep * powerOfTen).ceil();
    final int maxLabel = ((paddedMax / finalStep).ceil()) * finalStep;

    final List<int> labels = [];
    for (int i = 0; i <= maxLabel; i += finalStep) {
      labels.add(i);
    }

    if (maxLabel < 50 && maxLabel > 0) {
      final List<int> defaultLabels = [0, 10, 20, 30, 40, 50];
      return defaultLabels.where((v) => v >= 0).toList();
    }

    // Case when maxLabel is 0 but data is present
    if (maxLabel == 0 && rawMaxValue > 0) return [0, rawMaxValue.ceil()];

    return labels;
  }

  // -------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.values.every((d) => d == 0.0)) {
      return Center(child: Text('No data recorded for $title.'));
    }

    // Colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color darkGrey = AppTheme.darkGrey;
    final Color lightGrey = AppTheme.lightGrey;
    final Color mediumGrey = AppTheme.mediumGrey;

    final sortedKeys = data.keys.toList()..sort();
    final double rawMaxValue = data.values.isEmpty
        ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b);

    final List<int> yAxisLabels = _calculateYAxisValues(rawMaxValue);
    final double maxScaleValue = yAxisLabels.isEmpty
        ? 1.0
        : yAxisLabels.last.toDouble();

    const double chartVisualHeight = 200.0;
    const double xAxisLabelHeight = 18.0;
    const double yAxisLabelWidth = 30.0;
    const double chartTotalHeight = chartVisualHeight + xAxisLabelHeight;

    final List<Offset> points = [];

    final double chartWidth =
        MediaQuery.of(context).size.width - 32 - yAxisLabelWidth;

    if (sortedKeys.isNotEmpty) {
      // If only 1 data point is present
      final int divisor = sortedKeys.length > 1 ? sortedKeys.length - 1 : 1;

      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        final value = data[key] ?? 0.0;

        final double xPosition = (i / divisor) * chartWidth;

        final double normalizedValue = maxScaleValue > 0
            ? (value / maxScaleValue)
            : 0;
        final double yPosition =
            chartVisualHeight - (normalizedValue * chartVisualHeight);

        points.add(Offset(xPosition, yPosition));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: darkGrey),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: chartTotalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: yAxisLabelWidth,
                  height: chartVisualHeight,
                  padding: const EdgeInsets.only(right: 5),
                  child: Stack(
                    children: [
                      ...yAxisLabels.map((value) {
                        final double topPosition =
                            chartVisualHeight * (1 - (value / maxScaleValue));

                        return Positioned(
                          top: (value == maxScaleValue.toInt())
                              ? 0
                              : (value == 0)
                              ? chartVisualHeight - 12
                              : topPosition - 6,
                          right: 0,
                          child: Text(
                            value.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: darkGrey.withOpacity(0.8),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // 2. Chart area with lines and labels
                Expanded(
                  child: SizedBox(
                    height: chartTotalHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Grid lines
                        ...yAxisLabels.where((v) => v >= 0).map((value) {
                          final double bottomPosition =
                              (value / maxScaleValue) * chartVisualHeight;
                          final double lineBottom =
                              xAxisLabelHeight + bottomPosition;

                          final Color lineColor = value == 0
                              ? mediumGrey
                              : lightGrey;

                          return Positioned(
                            bottom: lineBottom,
                            left: 0,
                            right: 0,
                            child: Container(height: 1.0, color: lineColor),
                          );
                        }),

                        // The actual drawing area for the line (above X-labels)
                        Positioned(
                          bottom: xAxisLabelHeight + 1,
                          left: 0,
                          right: 0,
                          height: chartVisualHeight,
                          child: CustomPaint(
                            painter: points.isNotEmpty
                                ? LineChartPainter(
                                    points: points,
                                    lineColor: primaryColor,
                                    pointColor: primaryColor,
                                  )
                                : null,
                          ),
                        ),

                        // X-Achsen-Labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: sortedKeys.map((key) {
                            final String labelText =
                                customLabels.containsKey(key)
                                ? customLabels[key]!
                                : key.toString();

                            return Expanded(
                              child: Container(
                                height: xAxisLabelHeight,
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  labelText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: darkGrey,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// CustomPainter for the line chart
// ----------------------------------------------------
class LineChartPainter extends CustomPainter {
  final List<Offset> points;
  final Color lineColor;
  final Color pointColor;

  LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.pointColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final Path path = Path();

    // 1. Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Only draw line if more than 1 point
    if (points.length > 1) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // 2. Draw points
    final pointPaint = Paint()
      ..color = pointColor
      ..strokeWidth = 6.0
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3.0, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
