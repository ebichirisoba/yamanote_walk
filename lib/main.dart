import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const YamanoteWalkApp());
}

class _WalkRecord {
  final String from;
  final String to;
  final DateTime arrivalTime;
  final Duration elapsed;

  _WalkRecord({
    required this.from,
    required this.to,
    required this.arrivalTime,
    required this.elapsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'arrivalTime': arrivalTime.toIso8601String(),
      'elapsedSeconds': elapsed.inSeconds,
    };
  }

  factory _WalkRecord.fromJson(Map<String, dynamic> json) {
    return _WalkRecord(
      from: json['from'] as String,
      to: json['to'] as String,
      arrivalTime: DateTime.parse(json['arrivalTime'] as String),
      elapsed: Duration(
        seconds: json['elapsedSeconds'] as int,
      ),
    );
  }
}

class YamanoteWalkApp extends StatefulWidget {
  const YamanoteWalkApp({super.key});

  @override
  State<YamanoteWalkApp> createState() => _YamanoteWalkAppState();
}

class _YamanoteWalkAppState extends State<YamanoteWalkApp> {
  final List<String> stations = [
    '東京駅',
    '神田駅',
    '秋葉原駅',
    '御徒町駅',
    '上野駅',
    '鶯谷駅',
    '日暮里駅',
    '西日暮里駅',
    '田端駅',
    '駒込駅',
    '巣鴨駅',
    '大塚駅',
    '池袋駅',
    '目白駅',
    '高田馬場駅',
    '新大久保駅',
    '新宿駅',
    '代々木駅',
    '原宿駅',
    '渋谷駅',
    '恵比寿駅',
    '目黒駅',
    '五反田駅',
    '大崎駅',
    '品川駅',
    '高輪ゲートウェイ駅',
    '田町駅',
    '浜松町駅',
    '新橋駅',
    '有楽町駅',
  ];

  String selectedStartStation = '渋谷駅';
  String currentStation = '渋谷駅';
  String previousStation = '渋谷駅';

  int currentIndex = 19;
  int completedSegments = 0;

  Duration? elapsedTime;
  Duration? totalTime;

  DateTime? arrivalTime;
  DateTime? walkingStartTime;

  List<_WalkRecord> records = [];

  bool isWalking = false;
  bool isCompleted = false;

  List<Map<String, dynamic>> walkHistory = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final savedHistory = prefs.getString('walkHistory');

    if (savedHistory != null) {
      setState(() {
        walkHistory =
            List<Map<String, dynamic>>.from(
          jsonDecode(savedHistory),
        );
      });
    }
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'walkHistory',
      jsonEncode(walkHistory),
    );
  }

  Future<void> saveCurrentWalk() async {
    if (walkingStartTime == null || totalTime == null) {
      return;
    }

    final history = {
      'date': walkingStartTime!.toIso8601String(),
      'startStation': selectedStartStation,
      'totalSeconds': totalTime!.inSeconds,
      'completed': isCompleted,

      'records': records.map((record) {
        return record.toJson();
      }).toList(),
    };

    walkHistory.insert(0, history);

    await saveHistory();
  }

  void changeStartStation(String? station) {
    if (station == null || isWalking) {
      return;
    }

    setState(() {
      selectedStartStation = station;

      currentIndex = stations.indexOf(station);
      currentStation = station;
      previousStation = station;

      elapsedTime = null;
      totalTime = null;
      arrivalTime = null;
      walkingStartTime = null;

      records = [];
      completedSegments = 0;
      isCompleted = false;
    });
  }

  void startWalking() {
    setState(() {
      isWalking = true;
      isCompleted = false;

      currentIndex = stations.indexOf(selectedStartStation);

      currentStation = selectedStartStation;
      previousStation = selectedStartStation;

      completedSegments = 0;
      records = [];

      elapsedTime = null;
      totalTime = null;

      walkingStartTime = DateTime.now();
      arrivalTime = DateTime.now();
    });
  }

  Future<void> arriveAtNextStation() async {
    if (!isWalking) {
      return;
    }

    bool completed = false;

    setState(() {
      final now = DateTime.now();

      if (arrivalTime != null) {
        elapsedTime = now.difference(arrivalTime!);

        records.add(
          _WalkRecord(
            from: previousStation,
            to: currentStation,
            arrivalTime: now,
            elapsed: elapsedTime!,
          ),
        );
      }

      completedSegments++;

      previousStation = currentStation;

      currentIndex++;

      if (currentIndex >= stations.length) {
        currentIndex = 0;
      }

      currentStation = stations[currentIndex];

      arrivalTime = now;

      if (currentStation == selectedStartStation &&
          completedSegments == 30) {
        isWalking = false;
        isCompleted = true;

        totalTime = now.difference(walkingStartTime!);

        completed = true;
      }
    });

    if (completed) {
      await saveCurrentWalk();
    }
  }

  Future<void> finishWalking() async {
    if (!isWalking) {
      return;
    }

    setState(() {
      final now = DateTime.now();

      if (walkingStartTime != null) {
        totalTime = now.difference(walkingStartTime!);
      }

      isWalking = false;
    });

    await saveCurrentWalk();
  }

  void resetWalking() {
    setState(() {
      currentIndex = stations.indexOf(selectedStartStation);

      currentStation = selectedStartStation;
      previousStation = selectedStartStation;

      completedSegments = 0;

      elapsedTime = null;
      totalTime = null;

      arrivalTime = null;
      walkingStartTime = null;

      records = [];

      isWalking = false;
      isCompleted = false;
    });
  }

  String formatDuration(Duration? duration) {
    if (duration == null) {
      return '--時間--分--秒';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '${hours}時間${minutes}分${seconds}秒';
  }

  String formatShortDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '${minutes}分${seconds.toString().padLeft(2, '0')}秒';
  }

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);

    return '${date.year}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  List<_WalkRecord> getHistoryRecords(
    Map<String, dynamic> history,
  ) {
    final rawRecords = history['records'];

    if (rawRecords is! List) {
      return [];
    }

    final result = <_WalkRecord>[];

    for (final item in rawRecords) {
      if (item is Map &&
          item['from'] != null &&
          item['to'] != null &&
          item['arrivalTime'] != null &&
          item['elapsedSeconds'] != null) {
        result.add(
          _WalkRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    return result;
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('walkHistory');

    setState(() {
      walkHistory = [];
    });
  }

  Widget buildHistoryCard(
    Map<String, dynamic> history,
  ) {
    final duration = Duration(
      seconds: history['totalSeconds'] as int,
    );

    final historyRecords = getHistoryRecords(history);

    final completed =
        history['completed'] == true &&
        historyRecords.length == 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        title: Text(
          formatDate(history['date'] as String),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${history['startStation']}スタート　'
            '${formatDuration(duration)}',
          ),
        ),
        trailing: completed
            ? const Icon(
                Icons.check_circle,
                size: 28,
              )
            : const Icon(
                Icons.directions_walk,
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16,
            ),
            child: Column(
              children: [
                const Divider(),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      completed
                          ? '🎉 山手線一周達成'
                          : 'ウォーキング途中終了',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${historyRecords.length}/30区間',
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                ...List.generate(
                  historyRecords.length,
                  (index) {
                    final record = historyRecords[index];

                    return Container(
                      margin: const EdgeInsets.only(
                        bottom: 8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${record.from} → ${record.to}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '到着 ${formatTime(record.arrivalTime)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Text(
                            formatShortDuration(
                              record.elapsed,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                if (completed)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      top: 5,
                    ),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '総ウォーキング時間',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formatDuration(duration),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '山手線ウォーク',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('山手線ウォーク'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'スタート駅',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  initialValue: selectedStartStation,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: stations.map((station) {
                    return DropdownMenuItem(
                      value: station,
                      child: Text(station),
                    );
                  }).toList(),
                  onChanged:
                      isWalking ? null : changeStartStation,
                ),

                const SizedBox(height: 25),

                const Text(
                  '現在の駅',
                  style: TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 8),

                Text(
                  currentStation,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  arrivalTime == null
                      ? '到着時刻：--:--'
                      : '到着時刻：'
                          '${formatTime(arrivalTime!)}',
                  style: const TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 8),

                Text(
                  '$previousStation → $currentStation',
                  style: const TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 8),

                Text(
                  elapsedTime == null
                      ? '駅間の時間：--分--秒'
                      : '駅間の時間：'
                          '${elapsedTime!.inMinutes}分'
                          '${elapsedTime!.inSeconds % 60}秒',
                  style: const TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    onPressed:
                        isWalking ? null : startWalking,
                    child: const Text('ウォーキング開始'),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    onPressed:
                        isWalking
                            ? arriveAtNextStation
                            : null,
                    child: const Text('次の駅に到着'),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    onPressed:
                        isWalking ? finishWalking : null,
                    child: const Text('ウォーキング終了'),
                  ),
                ),

                const SizedBox(height: 25),

                if (isCompleted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '🎉 山手線一周達成！',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          '総ウォーキング時間',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formatDuration(totalTime),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 25),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '今回の記録',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                  child: records.isEmpty
                      ? const Center(
                          child: Text(
                            'まだ記録がありません',
                          ),
                        )
                      : ListView.builder(
                          itemCount: records.length,
                          itemBuilder:
                              (context, index) {
                            final record =
                                records[index];

                            return ListTile(
                              dense: true,
                              leading: Text(
                                '${index + 1}',
                              ),
                              title: Text(
                                '${record.from} → ${record.to}',
                              ),
                              trailing: Text(
                                formatShortDuration(
                                  record.elapsed,
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '過去のウォーキング',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (walkHistory.isNotEmpty)
                      TextButton(
                        onPressed: clearHistory,
                        child: const Text('全削除'),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                if (walkHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'まだ過去の記録はありません',
                    ),
                  ),

                ...walkHistory.map(
                  (history) {
                    return buildHistoryCard(
                      history,
                    );
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: 250,
                  child: OutlinedButton(
                    onPressed: resetWalking,
                    child: const Text(
                      '最初からやり直す',
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}