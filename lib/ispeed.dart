import 'package:flutter/material.dart';
import 'package:flutter_internet_speed_test/flutter_internet_speed_test.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class SpeedTestHomePage extends StatefulWidget {
  const SpeedTestHomePage({super.key});

  @override
  State<SpeedTestHomePage> createState() => _SpeedTestHomePageState();
}

class _SpeedTestHomePageState extends State<SpeedTestHomePage>
    with TickerProviderStateMixin {
  final FlutterInternetSpeedTest _internetSpeedTest = FlutterInternetSpeedTest();

  double downloadRate = 0.0;
  double uploadRate = 0.0;
  double progress = 0.0;
  bool isTesting = false;
  String unitText = 'Mbps';

  // Device info
  String? ipAddress;
  String? isp;
  String? region;
  String? country;

  // Historical data
  List<SpeedTestResult> testHistory = [];

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDeviceInfo();
    _loadTestHistory();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final response = await http.get(Uri.parse('https://ipinfo.io/json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          ipAddress = data['ip'];
          isp = data['org'];
          region = data['region'];
          country = data['country'];
        });
      }
    } catch (e) {
      debugPrint('Error loading device info: $e');
    }
  }

  Future<void> _loadTestHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('speed_test_history') ?? [];
    setState(() {
      testHistory = historyJson
          .map((json) => SpeedTestResult.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveTestResult(double download, double upload) async {
    final result = SpeedTestResult(
      downloadSpeed: download,
      uploadSpeed: upload,
      timestamp: DateTime.now(),
      unit: unitText,
    );

    testHistory.insert(0, result);
    if (testHistory.length > 20) {
      testHistory = testHistory.take(20).toList();
    }

    final prefs = await SharedPreferences.getInstance();
    final historyJson = testHistory
        .map((result) => jsonEncode(result.toJson()))
        .toList();
    await prefs.setStringList('speed_test_history', historyJson);
  }

  void _startSpeedTest() {
    setState(() {
      isTesting = true;
      downloadRate = 0.0;
      uploadRate = 0.0;
      progress = 0.0;
    });

    _rotationController.repeat();

    _internetSpeedTest.startTesting(
      useFastApi: true,
      onStarted: () {
        debugPrint("Test started...");
      },
      onProgress: (double percent, TestResult data) {
        setState(() {
          progress = percent;
        });
      },
      onDownloadComplete: (TestResult result) {
        setState(() {
          downloadRate = result.transferRate;
          unitText = result.unit == SpeedUnit.mbps ? 'Mbps' : 'Kbps';
        });
      },
      onUploadComplete: (TestResult result) {
        setState(() {
          uploadRate = result.transferRate;
          unitText = result.unit == SpeedUnit.mbps ? 'Mbps' : 'Kbps';
        });
      },
      onCompleted: (TestResult download, TestResult upload) {
        setState(() {
          isTesting = false;
        });
        _rotationController.stop();
        _saveTestResult(download.transferRate, upload.transferRate);
        debugPrint("Test completed!");
      },
      onError: (String errorMessage, String speedTestError) {
        setState(() {
          isTesting = false;
        });
        _rotationController.stop();
        debugPrint("Speed test error: $errorMessage");
      },
      onDefaultServerSelectionInProgress: () {
        debugPrint("Selecting default server...");
      },
      onDefaultServerSelectionDone: (client) {
        debugPrint("Selected server IP: ${client?.ip}");
      },
      onCancel: () {
        debugPrint("Speed test cancelled");
      },
    );
  }

  Widget _buildGlassmorphicContainer({
    required Widget child,
    double? width,
    double? height,
    EdgeInsets? padding,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSpeedIndicator(String label, double value, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isTesting ? _pulseAnimation.value : 1.0,
              child: _buildGlassmorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularPercentIndicator(
                      radius: 50.0,
                      lineWidth: 6.0,
                      percent: (value / 100).clamp(0.0, 1.0),
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            child: Text(
                              "${value.toStringAsFixed(1)}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          FittedBox(
                            child: Text(
                              unitText,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      progressColor: color,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      animation: true,
                      animateFromLastPercent: true,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return _buildGlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Device Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('IP Address', ipAddress ?? 'Loading...'),
          _buildInfoRow('ISP', isp ?? 'Loading...'),
          _buildInfoRow('Region', region ?? 'Loading...'),
          _buildInfoRow('Country', country ?? 'Loading...'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChart() {
    if (testHistory.isEmpty) {
      return _buildGlassmorphicContainer(
        child: const Center(
          child: Text(
            'No test history available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Get the last 10 test results for the chart
    final chartData = testHistory.reversed.take(10).toList();

    // Find max value for better scaling
    double maxSpeed = 0;
    for (var result in chartData) {
      if (result.downloadSpeed > maxSpeed) maxSpeed = result.downloadSpeed;
      if (result.uploadSpeed > maxSpeed) maxSpeed = result.uploadSpeed;
    }

    // Add some padding to the max value
    maxSpeed = maxSpeed * 1.2;
    if (maxSpeed < 10) maxSpeed = 10; // Minimum scale

    return _buildGlassmorphicContainer(
      height: 300, // Increased height
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(

            children: [
              // Left side - Title
              Row(
                children: [
                  const Icon(Icons.timeline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Speed History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10,),
              // Right side - Legend
              Row(

                children: [
                  Container(width: 12, height: 3, color: Colors.blue),
                  const SizedBox(width: 4),
                  const Text('Download', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 7),
                  Container(width: 12, height: 3, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24), // Added padding on all sides
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxSpeed / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value >= 0 && value < chartData.length) {
                            final date = chartData[value.toInt()].timestamp;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxSpeed / 4,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
                      left: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  minX: 0,
                  maxX: (chartData.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxSpeed,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.black.withOpacity(0.9),
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      tooltipMargin: 16, // Add margin to prevent clipping
                      fitInsideHorizontally: true, // Keep tooltip inside horizontally
                      fitInsideVertically: true, // Keep tooltip inside vertically
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final dataIndex = barSpot.x.toInt();

                          if (dataIndex >= 0 && dataIndex < chartData.length) {
                            final result = chartData[dataIndex];
                            final isDownload = barSpot.barIndex == 0;

                            return LineTooltipItem(
                              '${isDownload ? 'Download' : 'Upload'}\n',
                              TextStyle(
                                color: isDownload ? Colors.blue : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                height: 1.2, // Better line height
                              ),
                              children: [
                                TextSpan(
                                  text: '${barSpot.y.toStringAsFixed(1)} ${result.unit}\n',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                    height: 1.2,
                                  ),
                                ),
                                TextSpan(
                                  text: '${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    touchSpotThreshold: 50,
                  ),
                  lineBarsData: [
                    // Download speed line
                    LineChartBarData(
                      spots: chartData.asMap().entries.map((entry) =>
                          FlSpot(entry.key.toDouble(), entry.value.downloadSpeed)
                      ).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                    // Upload speed line
                    LineChartBarData(
                      spots: chartData.asMap().entries.map((entry) =>
                          FlSpot(entry.key.toDouble(), entry.value.uploadSpeed)
                      ).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.green,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1e3c72),
              Color(0xFF2a5298),
              Color(0xFF3b82f6),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Internet Speed Test',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // Speed indicators
                Row(
                  children: [
                    _buildSpeedIndicator("Download", downloadRate, Colors.blue),
                    const SizedBox(width: 16),
                    _buildSpeedIndicator("Upload", uploadRate, Colors.green),
                  ],
                ),

                const SizedBox(height: 30),

                // Progress or Start button
                if (isTesting)
                  _buildGlassmorphicContainer(
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 2 * 3.14159,
                              child: const Icon(
                                Icons.sync,
                                color: Colors.white,
                                size: 30,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Testing... ${progress.toStringAsFixed(0)}%",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  )
                else
                  _buildGlassmorphicContainer(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.network_check),
                      label: const Text(
                        "Start Speed Test",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _startSpeedTest,
                    ),
                  ),

                const SizedBox(height: 30),

                // Device info
                _buildDeviceInfo(),

                const SizedBox(height: 20),

                // History chart
                _buildHistoryChart(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }
}

class SpeedTestResult {
  final double downloadSpeed;
  final double uploadSpeed;
  final DateTime timestamp;
  final String unit;

  SpeedTestResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.timestamp,
    required this.unit,
  });

  Map<String, dynamic> toJson() {
    return {
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'timestamp': timestamp.toIso8601String(),
      'unit': unit,
    };
  }

  factory SpeedTestResult.fromJson(Map<String, dynamic> json) {
    return SpeedTestResult(
      downloadSpeed: json['downloadSpeed'],
      uploadSpeed: json['uploadSpeed'],
      timestamp: DateTime.parse(json['timestamp']),
      unit: json['unit'],
    );
  }
}