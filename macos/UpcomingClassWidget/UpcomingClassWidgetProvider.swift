import WidgetKit
import SwiftUI

struct ClassEntry: TimelineEntry {
    let date: Date
    let hasClass: Bool
    let className: String
    let timeRange: String
    let location: String
    let teacher: String
}

// MARK: - JSON Codable Models

struct WidgetClassItem: Codable {
    let day: Int
    let period: Int
    let weeks: [Int]
    let className: String
    let teacherName: String?
    let locationName: String?
    let periodName: String?
}

struct WidgetClassPeriod: Codable {
    let majorId: Int
    let minorId: Int
    let minorStartTime: String
    let minorEndTime: String
}

struct WidgetCalendarDay: Codable {
    let year: Int
    let month: Int
    let day: Int
    let weekday: Int
    let weekIndex: Int
}

struct WidgetCurriculumData: Codable {
    let hasData: Bool
    let allClasses: [WidgetClassItem]?
    let allPeriods: [WidgetClassPeriod]?
    let calendarDays: [WidgetCalendarDay]?
    let termSeason: Int?
    let summerTermStartYear: Int?
    let summerTermStartMonth: Int?
    let summerTermStartDay: Int?
    let holidayMode: Bool?
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    private let appGroup = "group.com.lyme.beikenext"
    private let curriculumDataKey = "curriculum_full_data"

    func placeholder(in context: Context) -> ClassEntry {
        ClassEntry(
            date: Date(),
            hasClass: true,
            className: "高等数学",
            timeRange: "09:00 - 10:30",
            location: "教学楼A101",
            teacher: "张老师"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ClassEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassEntry>) -> Void) {
        guard let curriculum = readCurriculumData(), curriculum.hasData else {
            let entry = ClassEntry(date: Date(), hasClass: false,
                className: "等待数据同步…", timeRange: "",
                location: "", teacher: "")
            let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(refresh)))
            return
        }

        if curriculum.holidayMode == true {
            let entry = ClassEntry(date: Date(), hasClass: false,
                className: "假期愉快，要天天开心呀～",
                timeRange: "", location: "", teacher: "")
            let midnight = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            )
            completion(Timeline(entries: [entry], policy: .after(midnight)))
            return
        }

        let entries = generateTimelineEntries(from: curriculum)
        let lastEntry = entries.last!
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let policy: TimelineReloadPolicy = lastEntry.date >= midnight ? .after(midnight) : .atEnd
        completion(Timeline(entries: entries, policy: policy))
    }

    // MARK: - Timeline generation

    private func generateTimelineEntries(from data: WidgetCurriculumData) -> [ClassEntry] {
        if data.holidayMode == true {
            return [ClassEntry(date: Date(), hasClass: false,
                className: "假期愉快，要天天开心呀～",
                timeRange: "", location: "", teacher: "")]
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: now)
        let todayWeekday = ((components.weekday ?? 1) + 5) % 7 + 1

        guard let allClasses = data.allClasses,
              let allPeriods = data.allPeriods else {
            return [ClassEntry(date: now, hasClass: false,
                className: "数据不完整", timeRange: "", location: "", teacher: "")]
        }

        if (data.termSeason ?? 1) >= 3
            && (data.summerTermStartMonth == nil
                || data.summerTermStartDay == nil) {
            return [ClassEntry(date: now, hasClass: false,
                className: "未设定小学期起始日",
                timeRange: "", location: "", teacher: "")]
        }

        let isSummerTerm = (data.termSeason ?? 1) >= 3
        let todayWeekIndex: Int
        if let exact = data.calendarDays?.first(where: {
            $0.year == components.year && $0.month == components.month && $0.day == components.day
        })?.weekIndex {
            todayWeekIndex = exact
        } else if isSummerTerm {
            todayWeekIndex = computeSummerWeekIndex(
                year: data.summerTermStartYear ?? Calendar.current.component(.year, from: Date()),
                month: data.summerTermStartMonth!,
                day: data.summerTermStartDay!)
        } else if let estimated = estimateWeekIndex(from: data.calendarDays,
                                                     year: components.year!,
                                                     month: components.month!,
                                                     day: components.day!,
                                                     maxWeek: maxWeekIndex(from: allClasses,
                                                                           calendarDays: data.calendarDays)) {
            todayWeekIndex = estimated
        } else {
            let entry = computeEntry(for: now, allClasses: allClasses,
                                     allPeriods: allPeriods, todayWeekday: todayWeekday,
                                     todayWeekIndex: 1)
            return [entry]
        }

        let lookupWeekday = todayWeekday
        let todayClasses = allClasses.filter {
            $0.day == lookupWeekday && $0.weeks.contains(todayWeekIndex)
        }

        if todayClasses.isEmpty {
            let isWeekend = todayWeekday >= 6
            return [ClassEntry(date: now, hasClass: false,
                className: isWeekend ? "周末愉快～" : "啊？今天一节课都没有！",
                timeRange: isWeekend ? "" : "", location: "", teacher: "")]
        }

        struct TimedClass {
            let item: WidgetClassItem
            let start: Date
            let end: Date
        }

        let timedClasses: [TimedClass] = todayClasses.compactMap { item in
            guard let start = computeDate(for: item, periods: allPeriods,
                                          on: todayStart, useEnd: false),
                  let end = computeDate(for: item, periods: allPeriods,
                                        on: todayStart, useEnd: true) else {
                return nil
            }
            return TimedClass(item: item, start: start, end: end)
        }.sorted { $0.start < $1.start }

        if timedClasses.isEmpty {
            return [ClassEntry(date: now, hasClass: false,
                className: "啊？今天一节课都没有！", timeRange: "", location: "", teacher: "")]
        }

        var entries: [ClassEntry] = []

        // Always include current state as the first entry
        entries.append(computeEntry(for: now, allClasses: allClasses,
            allPeriods: allPeriods, todayWeekday: lookupWeekday,
            todayWeekIndex: todayWeekIndex))

        // Future boundary entries: when each class starts
        for tc in timedClasses {
            if now < tc.start {
                let endStr = formatTime(tc.end)
                entries.append(ClassEntry(date: tc.start, hasClass: true,
                    className: tc.item.className,
                    timeRange: "进行中 - \(endStr)",
                    location: tc.item.locationName ?? "",
                    teacher: tc.item.teacherName ?? ""))
            }
        }

        // Future boundary entries: when each class ends → show next
        for (i, tc) in timedClasses.enumerated() {
            if now < tc.end {
                if i + 1 < timedClasses.count {
                    let next = timedClasses[i + 1]
                    let startStr = formatTime(next.start)
                    let endStr = formatTime(next.end)
                    entries.append(ClassEntry(date: tc.end, hasClass: true,
                        className: next.item.className,
                        timeRange: "\(startStr) - \(endStr)",
                        location: next.item.locationName ?? "",
                        teacher: next.item.teacherName ?? ""))
                } else {
                    entries.append(ClassEntry(date: tc.end, hasClass: false,
                        className: "今天的课都上完啦～", timeRange: "",
                        location: "", teacher: ""))
                }
            }
        }

        let midnight = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        entries.append(ClassEntry(date: midnight, hasClass: false,
            className: "", timeRange: "", location: "", teacher: ""))

        var seen: [TimeInterval: ClassEntry] = [:]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            seen[entry.date.timeIntervalSince1970] = entry
        }
        return seen.values.sorted { $0.date < $1.date }
    }

    // MARK: - Single entry computation

    private func computeEntry(for date: Date, allClasses: [WidgetClassItem],
                              allPeriods: [WidgetClassPeriod], todayWeekday: Int,
                              todayWeekIndex: Int) -> ClassEntry {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)

        let todayClasses = allClasses.filter {
            $0.day == todayWeekday && $0.weeks.contains(todayWeekIndex)
        }

        if todayClasses.isEmpty {
            let isWeekend = todayWeekday >= 6
            return ClassEntry(date: date, hasClass: false,
                className: isWeekend ? "周末愉快～" : "啊？今天一节课都没有！",
                timeRange: isWeekend ? "" : "", location: "", teacher: "")
        }

        struct TimedClass {
            let item: WidgetClassItem
            let start: Date
            let end: Date
        }

        let timedClasses: [TimedClass] = todayClasses.compactMap { item in
            guard let start = computeDate(for: item, periods: allPeriods,
                                          on: todayStart, useEnd: false),
                  let end = computeDate(for: item, periods: allPeriods,
                                        on: todayStart, useEnd: true) else {
                return nil
            }
            return TimedClass(item: item, start: start, end: end)
        }.sorted { $0.start < $1.start }

        if timedClasses.isEmpty {
            return ClassEntry(date: date, hasClass: false,
                className: "啊？今天一节课都没有！", timeRange: "", location: "", teacher: "")
        }

        var currentClass: TimedClass?
        var nextClass: TimedClass?

        for tc in timedClasses {
            if date >= tc.start && date < tc.end {
                currentClass = tc
            } else if date < tc.start, nextClass == nil {
                nextClass = tc
            }
        }

        if let ongoing = currentClass {
            let endStr = formatTime(ongoing.end)
            return ClassEntry(date: date, hasClass: true,
                className: ongoing.item.className,
                timeRange: "进行中 - \(endStr)",
                location: ongoing.item.locationName ?? "",
                teacher: ongoing.item.teacherName ?? "")
        }

        if let upcoming = nextClass {
            let startStr = formatTime(upcoming.start)
            let endStr = formatTime(upcoming.end)
            return ClassEntry(date: date, hasClass: true,
                className: upcoming.item.className,
                timeRange: "\(startStr) - \(endStr)",
                location: upcoming.item.locationName ?? "",
                teacher: upcoming.item.teacherName ?? "")
        }

        return ClassEntry(date: date, hasClass: false,
            className: "今天的课都上完啦～", timeRange: "",
            location: "", teacher: "")
    }

    // MARK: - Helpers

    private func computeSummerWeekIndex(year: Int, month: Int, day: Int) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return 1
        }
        let diffDays = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
        if diffDays < 0 { return 1 }
        return (diffDays / 7) + 1
    }

    private func estimateWeekIndex(from calendarDays: [WidgetCalendarDay]?,
                                    year: Int, month: Int, day: Int,
                                    maxWeek: Int) -> Int? {
        guard let calendarDays, !calendarDays.isEmpty else { return nil }

        let today = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
        let calendar = Calendar.current

        var baseWeek: Int?
        var baseDate: Date?
        var minDiff = Double.greatestFiniteMagnitude

        for cd in calendarDays {
            guard let cdDate = calendar.date(from: DateComponents(year: cd.year, month: cd.month, day: cd.day)) else { continue }
            let diff = abs(today.timeIntervalSince(cdDate))
            if diff < minDiff {
                minDiff = diff
                baseWeek = cd.weekIndex
                baseDate = cdDate
            }
        }

        guard let baseWeek, let baseDate else { return nil }
        let daysDiff = Int(today.timeIntervalSince(baseDate) / 86400)
        let weeksDiff = Int((Double(daysDiff) / 7.0).rounded())
        return max(1, min(maxWeek, baseWeek + weeksDiff))
    }

    private func maxWeekIndex(from allClasses: [WidgetClassItem],
                               calendarDays: [WidgetCalendarDay]?) -> Int {
        var maxW = 0
        for cls in allClasses {
            if let w = cls.weeks.max(), w > maxW { maxW = w }
        }
        if let days = calendarDays {
            for cd in days {
                if cd.weekIndex > maxW { maxW = cd.weekIndex }
            }
        }
        return max(maxW, 1)
    }

    private func computeDate(for item: WidgetClassItem, periods: [WidgetClassPeriod],
                             on today: Date, useEnd: Bool) -> Date? {
        let matching = periods.filter { $0.majorId == item.period }
        guard !matching.isEmpty else { return nil }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: today)

        if useEnd {
            guard let latest = matching.max(by: { $0.minorEndTime < $1.minorEndTime }),
                  let (h, m) = parseTime(latest.minorEndTime) else { return nil }
            return calendar.date(from: DateComponents(
                year: components.year, month: components.month, day: components.day,
                hour: h, minute: m))
        } else {
            guard let earliest = matching.min(by: { $0.minorStartTime < $1.minorStartTime }),
                  let (h, m) = parseTime(earliest.minorStartTime) else { return nil }
            return calendar.date(from: DateComponents(
                year: components.year, month: components.month, day: components.day,
                hour: h, minute: m))
        }
    }

    private func parseTime(_ str: String) -> (Int, Int)? {
        let parts = str.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return (hour, minute)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    // MARK: - Data reading

    private func readCurriculumData() -> WidgetCurriculumData? {
        guard let json = readString(forKey: curriculumDataKey),
              let data = json.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        return try? decoder.decode(WidgetCurriculumData.self, from: data)
    }

    private func readString(forKey key: String) -> String? {
        if let defaults = UserDefaults(suiteName: appGroup),
           let json = defaults.string(forKey: key) {
            return json
        }
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) {
            let fileURL = containerURL.appendingPathComponent("\(key).json")
            return try? String(contentsOf: fileURL, encoding: .utf8)
        }
        return nil
    }
}
