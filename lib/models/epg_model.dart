import 'package:another_iptv_player/utils/type_convertions.dart';

class EPGProgram {
  final String title;
  final int startTime;
  final int endTime;
  final String description;
  final bool isCurrent;
  final bool isNext;
  final bool isUpcoming;

  EPGProgram({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.isCurrent,
    this.isNext = false,
    this.isUpcoming = false,
  });

  // Factory method لإنشاء برنامج جديد مع الحالة الحالية
  factory EPGProgram.create({
    required String title,
    required int startTime,
    required int endTime,
    required String description,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isCurrent = now >= startTime && now <= endTime;

    return EPGProgram(
      title: title,
      startTime: startTime,
      endTime: endTime,
      description: description,
      isCurrent: isCurrent,
      isNext: false,
      isUpcoming: false,
    );
  }

  // دالة لتصفية القائمة للحصول على البرنامج الحالي والبرنامجين التاليين فقط
  static List<EPGProgram> getCurrentAndNextTwo(List<EPGProgram> allPrograms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<EPGProgram> result = [];

    // ترتيب البرامج حسب وقت البدء
    final sortedPrograms = List<EPGProgram>.from(allPrograms)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // العثور على البرنامج الحالي
    int currentIndex = -1;
    for (int i = 0; i < sortedPrograms.length; i++) {
      final program = sortedPrograms[i];
      if (now >= program.startTime && now <= program.endTime) {
        currentIndex = i;
        break;
      }
    }

    // إذا لم يكن هناك برنامج حالي، نبحث عن أول برنامج مستقبلي
    if (currentIndex == -1) {
      for (int i = 0; i < sortedPrograms.length; i++) {
        if (sortedPrograms[i].startTime > now) {
          currentIndex = i;
          break;
        }
      }
    }

    // إذا لم نجد أي برنامج مناسب
    if (currentIndex == -1 || currentIndex >= sortedPrograms.length) {
      return result;
    }

    // إضافة البرنامج الحالي/القادم
    result.add(sortedPrograms[currentIndex]._updateStatus(0, currentIndex));

    // إضافة البرنامج التالي إذا كان موجودًا
    if (currentIndex + 1 < sortedPrograms.length) {
      result.add(sortedPrograms[currentIndex + 1]._updateStatus(1, currentIndex));
    }

    // إضافة البرنامج القادم الثاني إذا كان موجودًا
    if (currentIndex + 2 < sortedPrograms.length) {
      result.add(sortedPrograms[currentIndex + 2]._updateStatus(2, currentIndex));
    }

    return result;
  }

  // دالة مساعدة لتحديث حالة البرنامج
  EPGProgram _updateStatus(int position, int currentIndex) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isCurrentProgram = now >= startTime && now <= endTime;

    if (position == 0 && isCurrentProgram) {
      return copyWith(isCurrent: true, isNext: false, isUpcoming: false);
    } else if (position == 1) {
      return copyWith(isCurrent: false, isNext: true, isUpcoming: false);
    } else if (position == 2) {
      return copyWith(isCurrent: false, isNext: false, isUpcoming: true);
    }

    return copyWith(isCurrent: false, isNext: false, isUpcoming: false);
  }

  // دالة لتحويل القائمة الكاملة إلى قائمة البرامج الحالية والتالية فقط
  static List<EPGProgram> filterForDisplay(List<EPGProgram> allPrograms) {
    return getCurrentAndNextTwo(allPrograms);
  }

  // Helper methods للعرض
  String get timeRemaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (isCurrent) {
      final remaining = Duration(milliseconds: endTime - now);
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);

      if (hours > 0) {
        return 'ينتهي خلال ${hours}س ${minutes}د';
      } else {
        return 'ينتهي خلال ${minutes}د';
      }
    }
    return '';
  }

  String get startTimeFormatted {
    final time = DateTime.fromMillisecondsSinceEpoch(startTime);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String get endTimeFormatted {
    final time = DateTime.fromMillisecondsSinceEpoch(endTime);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String get duration {
    final duration = Duration(milliseconds: endTime - startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}س ${minutes}د';
    } else {
      return '${minutes}د';
    }
  }

  bool get isUpcomingProgram {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now < startTime;
  }

  bool get isFinished {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > endTime;
  }

  double get progress {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (isCurrent) {
      final totalDuration = endTime - startTime;
      final elapsed = now - startTime;
      return elapsed / totalDuration;
    }
    return 0.0;
  }

  // دالة لتحديد أيقونة الحالة
  String get statusIcon {
    if (isCurrent) return '▶️';
    if (isNext) return '⏭️';
    if (isUpcoming) return '⏳';
    return '';
  }

  // دالة لتحديد نص الحالة
  String get statusText {
    if (isCurrent) return 'مباشر الآن';
    if (isNext) return 'التالي';
    if (isUpcoming) return 'قادم';
    return '';
  }

  // دالة لتحديد لون الحالة
  String get statusColor {
    if (isCurrent) return '#FF6B9D'; // وردي/بنفسجي للبرنامج الحالي
    if (isNext) return '#4A90E2'; // أزرق للبرنامج التالي
    if (isUpcoming) return '#7B8D8E'; // رمادي للبرنامج القادم
    return '#CCCCCC'; // رمادي فاتح
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      'isCurrent': isCurrent,
      'isNext': isNext,
      'isUpcoming': isUpcoming,
    };
  }

  factory EPGProgram.fromJson(Map<String, dynamic> json) {
    return EPGProgram(
      title: safeString(json['title']),
      startTime: safeInt(json['startTime']),
      endTime: safeInt(json['endTime']),
      description: safeString(json['description']),
      isCurrent: safeBool(json['isCurrent']),
      isNext: safeBool(json['isNext'] ?? false),
      isUpcoming: safeBool(json['isUpcoming'] ?? false),
    );
  }

  @override
  String toString() {
    return 'EPGProgram(title: $title, start: $startTimeFormatted, end: $endTimeFormatted, '
        'duration: $duration, isCurrent: $isCurrent, isNext: $isNext, isUpcoming: $isUpcoming)';
  }

  EPGProgram copyWith({
    String? title,
    int? startTime,
    int? endTime,
    String? description,
    bool? isCurrent,
    bool? isNext,
    bool? isUpcoming,
  }) {
    return EPGProgram(
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      isCurrent: isCurrent ?? this.isCurrent,
      isNext: isNext ?? this.isNext,
      isUpcoming: isUpcoming ?? this.isUpcoming,
    );
  }
}

