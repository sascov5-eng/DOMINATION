import Foundation
import SwiftUI

struct Hex: Hashable {
    var q: Int
    var r: Int
    var s: Int { -q - r }

    static let neighbors = [
        Hex(q: 1, r: 0), Hex(q: 1, r: -1), Hex(q: 0, r: -1),
        Hex(q: -1, r: 0), Hex(q: -1, r: 1), Hex(q: 0, r: 1)
    ]

    func adding(_ o: Hex) -> Hex { Hex(q: q + o.q, r: r + o.r) }
    func neighbors() -> [Hex] { Self.neighbors.map { adding($0) } }
    func distance(to o: Hex) -> Int {
        (abs(q - o.q) + abs(r - o.r) + abs(s - o.s)) / 2
    }
}

enum Terrain: String, CaseIterable {
    case plain, forest, river, ruin, waste

    var label: String {
        switch self {
        case .plain: return "RAVNINA"
        case .forest: return "LES"
        case .river: return "REKA"
        case .ruin: return "RUINY"
        case .waste: return "PUSTOSH"
        }
    }

    var tint: Color {
        switch self {
        case .plain: return Color(red: 0.28, green: 0.36, blue: 0.24)
        case .forest: return Color(red: 0.12, green: 0.24, blue: 0.16)
        case .river: return Color(red: 0.14, green: 0.28, blue: 0.38)
        case .ruin: return Color(red: 0.32, green: 0.28, blue: 0.20)
        case .waste: return Color(red: 0.30, green: 0.26, blue: 0.18)
        }
    }
}

enum Building: String {
    case hq, barracks, kitchen, workshop, radio

    var title: String {
        switch self {
        case .hq: return "SHTAB"
        case .barracks: return "KAZARMA"
        case .kitchen: return "KUHNYA"
        case .workshop: return "MASTER"
        case .radio: return "RADIO"
        }
    }

    var mark: String {
        switch self {
        case .hq: return "HQ"
        case .barracks: return "KZ"
        case .kitchen: return "FD"
        case .workshop: return "WS"
        case .radio: return "RD"
        }
    }

    var personnelCost: Int {
        switch self {
        case .hq: return 0
        case .barracks: return 2
        case .kitchen: return 2
        case .workshop: return 2
        case .radio: return 1
        }
    }

    var materialCost: Int {
        switch self {
        case .hq: return 0
        case .barracks: return 4
        case .kitchen: return 3
        case .workshop: return 5
        case .radio: return 3
        }
    }
}

struct Tile {
    var hex: Hex
    var terrain: Terrain
    var revealed: Bool
    var building: Building?
    var buildDaysLeft: Int = 0
}

struct Resources {
    var personnel = 6
    var rations = 8
    var materiel = 10
    var morale = 4
    var credits = 5
    var dPersonnel = 0
    var dRations = 0
    var dMateriel = 0
    var dMorale = 0
    var dCredits = 0
}

final class OutpostGame: ObservableObject {
    @Published var tiles: [Hex: Tile] = [:]
    @Published var res = Resources()
    @Published var day = 1
    @Published var quotaDay = 8
    @Published var quotaCredits = 6
    @Published var deficitDays = 0
    @Published var selected: Hex?
    @Published var log = "RAZVEDKA. POSTROI BAZU. DERZHI PLAN."
    @Published var ended = false
    @Published var won = false
    @Published var pendingBuild: Building?

    let radius = 4
    let hq = Hex(q: 0, r: 0)

    init() { reset() }

    func reset() {
        var map: [Hex: Tile] = [:]
        for q in -radius...radius {
            for r in max(-radius, -q - radius)...min(radius, -q + radius) {
                let h = Hex(q: q, r: r)
                let t: Terrain
                if h == hq {
                    t = .plain
                } else {
                    let roll = abs((q * 17 + r * 31) % 10)
                    if roll < 4 { t = .plain }
                    else if roll < 6 { t = .forest }
                    else if roll < 7 { t = .river }
                    else if roll < 9 { t = .ruin }
                    else { t = .waste }
                }
                map[h] = Tile(hex: h, terrain: t, revealed: h.distance(to: hq) <= 1, building: h == hq ? .hq : nil)
            }
        }
        tiles = map
        res = Resources()
        day = 1
        quotaDay = 8
        quotaCredits = 6
        deficitDays = 0
        selected = hq
        pendingBuild = nil
        ended = false
        won = false
        log = "DEN 1. SHTAB STOIT. TUMAN VOKRUG."
        recalcIncome()
    }

    func tile(_ h: Hex) -> Tile? { tiles[h] }

    func isExplorable(_ h: Hex) -> Bool {
        guard let t = tiles[h], !t.revealed else { return false }
        return h.neighbors().contains { tiles[$0]?.revealed == true }
    }

    func tap(_ h: Hex) {
        guard !ended, tiles[h] != nil else { return }
        selected = h
        if isExplorable(h) {
            explore(h)
            return
        }
        if let t = tiles[h], t.revealed, t.building == nil, t.buildDaysLeft == 0 {
            pendingBuild = pendingBuild ?? .barracks
        }
    }

    func explore(_ h: Hex) {
        guard res.personnel >= 1, var t = tiles[h], !t.revealed else {
            log = "NET LUDEI DLYA RAZVEDKI."
            return
        }
        res.personnel -= 1
        t.revealed = true
        tiles[h] = t
        var bonus = ""
        if t.terrain == .ruin {
            res.credits += 2
            bonus = " NAIDENY ZAPASY +2 CR."
        } else if t.terrain == .forest {
            res.materiel += 1
            bonus = " LES +1 MAT."
        }
        log = "RAZVEDANO: \(t.terrain.label).\(bonus)"
        recalcIncome()
    }

    func canBuild(_ b: Building, on h: Hex) -> Bool {
        guard let t = tiles[h], t.revealed, t.building == nil, t.buildDaysLeft == 0 else { return false }
        if t.terrain == .river { return false }
        return res.personnel >= b.personnelCost && res.materiel >= b.materialCost
    }

    func startBuild(_ b: Building) {
        guard let h = selected, canBuild(b, on: h), var t = tiles[h] else {
            log = "NELZYA POSTROIT."
            return
        }
        res.personnel -= b.personnelCost
        res.materiel -= b.materialCost
        t.buildDaysLeft = 2
        t.building = b
        tiles[h] = t
        pendingBuild = nil
        log = "STROIKA \(b.title). 2 DNYA."
        recalcIncome()
    }

    func endDay() {
        guard !ended else { return }
        for (h, var t) in tiles where t.buildDaysLeft > 0 {
            t.buildDaysLeft -= 1
            if t.buildDaysLeft == 0 { log = "GOTOVO: \(t.building?.title ?? "?")" }
            tiles[h] = t
        }
        recalcIncome()
        res.personnel = max(0, res.personnel + res.dPersonnel)
        res.rations = res.rations + res.dRations
        res.materiel = max(0, res.materiel + res.dMateriel)
        res.morale = max(0, res.morale + res.dMorale)
        res.credits = max(0, res.credits + res.dCredits)

        if res.rations < 0 || res.personnel <= 0 {
            deficitDays += 1
            log = "DEFICIT. DNEI DO SRYVA: \(7 - deficitDays)."
            if deficitDays >= 7 {
                ended = true
                log = "BAZA RASSYPALAS. SRYV."
                return
            }
        } else {
            deficitDays = 0
        }

        if day >= quotaDay {
            if res.credits >= quotaCredits {
                res.credits -= quotaCredits
                quotaDay += 7
                quotaCredits += 3
                log = "PLAN SDAN. SLEDUYUSHCHIY CHEREZ 7 DNEY."
            } else {
                ended = true
                log = "PLAN NE SDAN. KOMANDovanie OTOZVALO BAZU."
                return
            }
        }

        if day >= 21 && deficitDays == 0 {
            ended = true
            won = true
            log = "21 DEN. BAZA UDERZHANA."
            return
        }

        day += 1
        if Int.random(in: 0...8) == 0 {
            let hit = Int.random(in: 1...2)
            res.materiel = max(0, res.materiel - hit)
            log = "SBOI TEHNIKI. -\(hit) MAT."
        }
        recalcIncome()
    }

    func recalcIncome() {
        var p = 0, f = -1, m = 0, mo = 0, c = 0
        for t in tiles.values where t.revealed && t.buildDaysLeft == 0 {
            switch t.building {
            case .hq:
                p += 1; m += 1
            case .barracks:
                p += 2; f -= 1
            case .kitchen:
                f += 3
            case .workshop:
                m += 2
            case .radio:
                mo += 1; c += 1
            default:
                break
            }
            if t.terrain == .forest, t.building == .workshop { m += 1 }
            if t.terrain == .plain, t.building == .kitchen { f += 1 }
        }
        f -= max(0, (res.personnel + p) / 4)
        res.dPersonnel = p
        res.dRations = f
        res.dMateriel = m
        res.dMorale = mo
        res.dCredits = c
    }
}
