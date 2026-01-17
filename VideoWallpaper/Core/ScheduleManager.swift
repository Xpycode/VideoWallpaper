//
//  ScheduleManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-17.
//
//  Manages scheduled playback times for automatic start/stop.
//

import Foundation
import Combine

/// Manages scheduled playback times.
/// Monitors current time and determines whether playback should be active based on schedule.
class ScheduleManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ScheduleManager()

    // MARK: - Published Properties

    /// Whether current time is within the scheduled playback window
    @Published private(set) var isWithinSchedule = true

    // MARK: - UserDefaults Keys

    private let scheduleEnabledKey = "scheduleEnabled"
    private let scheduleStartHourKey = "scheduleStartHour"
    private let scheduleStartMinuteKey = "scheduleStartMinute"
    private let scheduleEndHourKey = "scheduleEndHour"
    private let scheduleEndMinuteKey = "scheduleEndMinute"
    private let scheduleEnabledDaysKey = "scheduleEnabledDays"

    // MARK: - Private Properties

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: scheduleEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: scheduleEnabledKey)
            checkSchedule()
        }
    }

    var startHour: Int {
        get { UserDefaults.standard.integer(forKey: scheduleStartHourKey) }
        set { UserDefaults.standard.set(newValue, forKey: scheduleStartHourKey) }
    }

    var startMinute: Int {
        get { UserDefaults.standard.integer(forKey: scheduleStartMinuteKey) }
        set { UserDefaults.standard.set(newValue, forKey: scheduleStartMinuteKey) }
    }

    var endHour: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: scheduleEndHourKey)
            return value == 0 ? 23 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: scheduleEndHourKey) }
    }

    var endMinute: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: scheduleEndMinuteKey)
            // Default to 59 if end hour is 23 and minute is 0
            if value == 0 && UserDefaults.standard.integer(forKey: scheduleEndHourKey) == 0 {
                return 59
            }
            return value
        }
        set { UserDefaults.standard.set(newValue, forKey: scheduleEndMinuteKey) }
    }

    /// Days of week (0 = Sunday, 1 = Monday, etc.)
    var enabledDays: Set<Int> {
        get {
            if let array = UserDefaults.standard.array(forKey: scheduleEnabledDaysKey) as? [Int] {
                return Set(array)
            }
            // Default to weekdays (Mon-Fri)
            return [1, 2, 3, 4, 5]
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: scheduleEnabledDaysKey)
        }
    }

    /// Formatted schedule string for display
    var scheduleDescription: String {
        guard isEnabled else { return "Schedule disabled" }

        let startTime = String(format: "%d:%02d", startHour, startMinute)
        let endTime = String(format: "%d:%02d", endHour, endMinute)

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = enabledDays.sorted()

        var daysString: String
        if sortedDays == [1, 2, 3, 4, 5] {
            daysString = "weekdays"
        } else if sortedDays == [0, 6] {
            daysString = "weekends"
        } else if sortedDays == [0, 1, 2, 3, 4, 5, 6] {
            daysString = "every day"
        } else {
            daysString = sortedDays.map { dayNames[$0] }.joined(separator: ", ")
        }

        return "\(startTime) - \(endTime), \(daysString)"
    }

    // MARK: - Initialization

    private init() {
        // Set default end time if not set
        if UserDefaults.standard.object(forKey: scheduleEndHourKey) == nil {
            UserDefaults.standard.set(23, forKey: scheduleEndHourKey)
            UserDefaults.standard.set(59, forKey: scheduleEndMinuteKey)
        }

        // Set default days if not set
        if UserDefaults.standard.object(forKey: scheduleEnabledDaysKey) == nil {
            UserDefaults.standard.set([1, 2, 3, 4, 5], forKey: scheduleEnabledDaysKey)
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        // Check immediately
        checkSchedule()

        // Check every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSchedule()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Schedule Check

    func checkSchedule() {
        guard isEnabled else {
            if !isWithinSchedule {
                isWithinSchedule = true
            }
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)

        guard let currentHour = components.hour,
              let currentMinute = components.minute,
              let weekday = components.weekday else {
            return
        }

        // Convert weekday (1=Sunday in Calendar) to our format (0=Sunday)
        let dayIndex = weekday - 1

        // Check if today is an enabled day
        guard enabledDays.contains(dayIndex) else {
            updateScheduleState(false)
            return
        }

        // Convert times to minutes since midnight for easier comparison
        let currentMinutes = currentHour * 60 + currentMinute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        let withinTime: Bool
        if startMinutes <= endMinutes {
            // Normal case: e.g., 9:00 - 17:00
            withinTime = currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight case: e.g., 22:00 - 06:00
            withinTime = currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }

        updateScheduleState(withinTime)
    }

    private func updateScheduleState(_ withinSchedule: Bool) {
        if isWithinSchedule != withinSchedule {
            isWithinSchedule = withinSchedule
            NotificationCenter.default.post(
                name: ScheduleManager.scheduleStateDidChangeNotification,
                object: self,
                userInfo: ["isWithinSchedule": withinSchedule]
            )
        }
    }

    // MARK: - Day Toggle

    func toggleDay(_ day: Int) {
        var days = enabledDays
        if days.contains(day) {
            days.remove(day)
        } else {
            days.insert(day)
        }
        enabledDays = days
        checkSchedule()
    }

    func isDayEnabled(_ day: Int) -> Bool {
        enabledDays.contains(day)
    }
}

// MARK: - Notifications

extension ScheduleManager {
    static let scheduleStateDidChangeNotification = Notification.Name("scheduleStateDidChange")
}
