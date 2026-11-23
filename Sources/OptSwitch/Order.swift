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
