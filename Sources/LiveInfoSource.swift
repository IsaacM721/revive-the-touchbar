import Foundation
import Darwin

/// Real numbers for the effects that show them: the time and date (read fresh every frame) and CPU and
/// memory use (sampled once a second, only while something reads them).
final class LiveInfoSource {
    static let shared = LiveInfoSource()

    private var sampled = LiveInfo()
    private var lastSample = Date.distantPast
    private var lastTicks: (busy: UInt64, total: UInt64)?
    private var history: [Double] = []
    private let calendar = Calendar.autoupdatingCurrent

    private init() {}

    var current: LiveInfo {
        let now = Date()
        if now.timeIntervalSince(lastSample) >= 1 { sample(now) }
        var info = sampled
        info.now = now.timeIntervalSince1970
        info.secondsOfDay = now.timeIntervalSince(calendar.startOfDay(for: now))
        return info
    }

    private func sample(_ now: Date) {
        lastSample = now
        let year = calendar.component(.year, from: now)
        sampled.year = year
        if let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
           let next = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) {
            sampled.secondsToNewYear = next.timeIntervalSince(now)
            sampled.yearFraction = now.timeIntervalSince(start) / next.timeIntervalSince(start)
        }
        sampled.dateLabel = Self.dateLabel(now)
        sampled.use24Hour = !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
        if let ticks = Self.cpuTicks() {
            if let last = lastTicks, ticks.total > last.total {
                let load = Double(ticks.busy - last.busy) / Double(ticks.total - last.total)
                sampled.cpu = min(1, max(0, load))
                history.append(sampled.cpu)
                if history.count > 60 { history.removeFirst(history.count - 60) }
                sampled.cpuHistory = history
            }
            lastTicks = ticks
        }
        if let mem = Self.memoryInUse() { sampled.memory = mem }
    }

    /// "SAT 26 SEP", in Spanish, Portuguese, or French when that's the app's language (the dot font draws
    /// Latin letters only, so other languages get English).
    private static func dateLabel(_ now: Date) -> String {
        let lang = appLanguage
        let f = DateFormatter()
        f.locale = Locale(identifier: ["es", "pt", "fr"].contains(lang) ? lang : "en_US")
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return f.string(from: now).uppercased().replacingOccurrences(of: ".", with: "")
    }

    /// Busy and total CPU ticks across all cores since boot.
    private static func cpuTicks() -> (busy: UInt64, total: UInt64)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        return (user + system + nice, user + system + idle + nice)
    }

    /// Share of physical memory in use (active, wired, and compressed), roughly what Activity Monitor shows.
    private static func memoryInUse() -> Double? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let page = Double(sysconf(_SC_PAGESIZE))
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        return total > 0 ? min(1, used / total) : nil
    }
}
