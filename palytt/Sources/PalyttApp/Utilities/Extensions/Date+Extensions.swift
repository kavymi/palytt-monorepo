//
//  Date+Extensions.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func detailedTimeDisplay() -> String {
        let now = Date()
        let calendar = Calendar.current
        
        // If posted today, show time only
        if calendar.isDate(self, inSameDayAs: now) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let timeString = timeFormatter.string(from: self)
            let relativeString = timeAgoDisplay()
            return "\(timeString) • \(relativeString)"
        }
        
        // If posted this week, show day and time
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        if self >= weekAgo {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let dayString = dayFormatter.string(from: self)
            let timeString = timeFormatter.string(from: self)
            let relativeString = timeAgoDisplay()
            return "\(dayString) at \(timeString) • \(relativeString)"
        }
        
        // If posted this year, show month and day
        if calendar.component(.year, from: self) == calendar.component(.year, from: now) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let dateString = dateFormatter.string(from: self)
            let timeString = timeFormatter.string(from: self)
            let relativeString = timeAgoDisplay()
            return "\(dateString) at \(timeString) • \(relativeString)"
        }
        
        // If older than a year, show full date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let dateString = dateFormatter.string(from: self)
        let timeString = timeFormatter.string(from: self)
        let relativeString = timeAgoDisplay()
        return "\(dateString) at \(timeString) • \(relativeString)"
    }
} 