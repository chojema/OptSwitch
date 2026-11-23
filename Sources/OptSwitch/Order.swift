// Pure ordering logic, free of AppKit so scripts/test.sh can compile it on its own.

/// Running app IDs ordered most recently used first; apps never seen active keep launch order at the end.
func mruOrder(running: [Int32], history: [Int32]) -> [Int32] {
    let alive = Set(running)
    var seen = Set<Int32>()
    let recent = history.filter { alive.contains($0) && seen.insert($0).inserted }
    return recent + running.filter { !seen.contains($0) }
}

/// Index arithmetic that wraps in both directions.
func wrap(_ index: Int, _ count: Int) -> Int {
    ((index % count) + count) % count
}

/// Switcher entries: windows front to back (the on-screen stacking order is the recent-use order),
/// then running apps with no window on screen, most recently used first. `window` is nil for those apps.
func switchOrder(windows: [(pid: Int32, window: UInt32)], running: [Int32], history: [Int32]) -> [(pid: Int32, window: UInt32?)] {
    let alive = Set(running)
    let shown = windows.filter { alive.contains($0.pid) }
    let withWindow = Set(shown.map(\.pid))
    let rest = mruOrder(running: running, history: history).filter { !withWindow.contains($0) }
    return shown.map { ($0.pid, Optional($0.window)) } + rest.map { ($0, nil) }
}
