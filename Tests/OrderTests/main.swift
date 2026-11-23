// Run with scripts/test.sh.
import Foundation

func check(_ ok: Bool, _ name: String) {
    if !ok { print("FAIL: \(name)"); exit(1) }
}

check(mruOrder(running: [1, 2, 3], history: []) == [1, 2, 3], "no history keeps launch order")
check(mruOrder(running: [1, 2, 3], history: [3, 1]) == [3, 1, 2], "recent apps first")
check(mruOrder(running: [1, 2], history: [9, 2, 2, 1]) == [2, 1], "dead and duplicate entries dropped")
check(mruOrder(running: [], history: [1]) == [], "nothing running")

check(wrap(3, 3) == 0, "wrap forward")
check(wrap(-1, 3) == 2, "wrap backward")
check(wrap(-4, 3) == 2, "wrap far backward")
check(wrap(0, 1) == 0, "single item")

let order = switchOrder(windows: [(2, 20), (1, 10), (2, 21), (9, 90)], running: [1, 2, 3, 4], history: [4, 1])
check(order.map(\.pid) == [2, 1, 2, 4, 3], "windows front to back, then windowless apps by recent use")
check(order.map(\.window) == [20, 10, 21, nil, nil], "window ids kept, nil for windowless apps")
check(switchOrder(windows: [], running: [1], history: []).map(\.window) == [nil], "no windows falls back to apps")

print("OK: all order tests passed")
