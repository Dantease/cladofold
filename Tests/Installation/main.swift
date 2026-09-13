import Foundation

func check(_ condition: @autoclosure () throws -> Bool) rethrows {
    let result = try condition()
    precondition(result)
}

let files = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
try files.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? files.removeItem(at: root) }
let source = root.appendingPathComponent("source.prefPane")
let destination = root.appendingPathComponent("Library/PreferencePanes/cladofold..prefPane")
func makePane(_ url: URL, id: String) throws {
    try files.createDirectory(at: url.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id, "CFBundlePackageType": "BNDL"], format: .xml, options: 0)
    try plist.write(to: url.appendingPathComponent("Contents/Info.plist"))
}
try makePane(source, id: "com.dante.Foldable.Settings")
let payload = "Contents/test-resource"
try Data("original".utf8).write(to: source.appendingPathComponent(payload))
try PaneInstaller.install(from: source, to: destination)
try check(Data(contentsOf: destination.appendingPathComponent(payload)) == Data("original".utf8))
print("PASS fresh per-user pane installation")
let first = try files.attributesOfItem(atPath: destination.path)[.modificationDate] as! Date
try PaneInstaller.install(from: source, to: destination)
try check(files.attributesOfItem(atPath: destination.path)[.modificationDate] as! Date == first)
print("PASS identical installation leaves pane untouched")
try Data("updated".utf8).write(to: source.appendingPathComponent(payload))
try PaneInstaller.install(from: source, to: destination)
try check(Data(contentsOf: destination.appendingPathComponent(payload)) == Data("updated".utf8))
print("PASS update replaces pane contents")
let foreign = root.appendingPathComponent("unrelated.prefPane")
try makePane(foreign, id: "example.unrelated")
var rejected = false
do { try PaneInstaller.install(from: source, to: foreign) } catch { rejected = true }
precondition(rejected && Bundle(url: foreign)?.bundleIdentifier == "example.unrelated")
print("PASS unrelated pane preserved")
rejected = false
do { try PaneInstaller.install(from: foreign, to: destination) } catch { rejected = true }
precondition(rejected)
try check(Data(contentsOf: destination.appendingPathComponent(payload)) == Data("updated".utf8))
print("PASS invalid source preserves installed pane")
