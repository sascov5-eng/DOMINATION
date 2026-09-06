import Foundation
import SwiftUI

struct Hex: Hashable {
    var q: Int
    var r: Int
    func adding(_ o: Hex) -> Hex { Hex(q: q + o.q, r: r + o.r) }
    func neighbors() -> [Hex] {
        [Hex(q: 1, r: 0), Hex(q: 1, r: -1), Hex(q: 0, r: -1),
         Hex(q: -1, r: 0), Hex(q: -1, r: 1), Hex(q: 0, r: 1)].map { adding($0) }
    }
    func distance(to o: Hex) -> Int {
        (abs(q - o.q) + abs(r - o.r) + abs((-q - r) - (-o.q - o.r))) / 2
    }
}

enum Terrain {
    case plain, forest, river, ruin, waste
    var label: String {
        switch self {
        case .plain: return "Равнина"
        case .forest: return "Лес"
        case .river: return "Река"
        case .ruin: return "Руины"
        case .waste: return "Пустошь"
        }
    }
    var tint: Color {
        switch self {
        case .plain: return Color(red: 0.30, green: 0.38, blue: 0.24)
        case .forest: return Color(red: 0.12, green: 0.26, blue: 0.16)
        case .river: return Color(red: 0.14, green: 0.28, blue: 0.38)
        case .ruin: return Color(red: 0.34, green: 0.30, blue: 0.20)
        case .waste: return Color(red: 0.32, green: 0.28, blue: 0.18)
        }
    }
}

enum Building {
    case hq, barracks, kitchen, workshop, radio
    var title: String {
        switch self {
        case .hq: return "Штаб"
        case .barracks: return "Казарма"
        case .kitchen: return "Кухня"
        case .workshop: return "Мастерская"
        case .radio: return "Радио"
        }
    }
    var mark: String {
        switch self {
        case .hq: return "ШТ"
        case .barracks: return "КЗ"
        case .kitchen: return "КХ"
        case .workshop: return "МС"
        case .radio: return "РД"
        }
    }
    var people: Int {
        switch self {
        case .hq: return 0
        case .barracks: return 2
        case .kitchen: return 2
        case .workshop: return 2
        case .radio: return 1
        }
    }
    var mats: Int {
        switch self {
        case .hq: return 0
        case .barracks: return 4
        case .kitchen: return 3
        case .workshop: return 5
        case .radio: return 3
        }
    }
}

enum Force: String {
    case infantry, scout, armor, drone
    var title: String {
        switch self {
        case .infantry: return "Пехота"
        case .scout: return "Разведка"
        case .armor: return "Техника"
        case .drone: return "БПЛА"
        }
    }
    var mark: String {
        switch self {
        case .infantry: return "П"
        case .scout: return "Р"
        case .armor: return "Т"
        case .drone: return "Б"
        }
    }
    var hp: Int {
        switch self {
        case .infantry: return 3
        case .scout: return 2
        case .armor: return 5
        case .drone: return 1
        }
    }
    var atk: Int {
        switch self {
        case .infantry: return 2
        case .scout: return 1
        case .armor: return 3
        case .drone: return 0
        }
    }
    var peopleCost: Int {
        switch self {
        case .infantry: return 2
        case .scout: return 1
        case .armor: return 2
        case .drone: return 1
        }
    }
    var matCost: Int {
        switch self {
        case .infantry: return 1
        case .scout: return 1
        case .armor: return 4
        case .drone: return 2
        }
    }
    func canEnter(_ t: Terrain) -> Bool {
        if self == .armor && (t == .forest || t == .river) { return false }
        if t == .river && self != .drone { return false }
        return true
    }
}

struct Tile {
    var hex: Hex
    var terrain: Terrain
    var revealed: Bool
    var building: Building?
    var buildingDays = 0
    var owner: Int = 0
    var isPoint = false
}

struct Troop {
    var id: Int
    var side: Int
    var kind: Force
    var hex: Hex
    var hp: Int
    var acted = false
}

struct Bag {
    var people = 7
    var food = 9
    var mats = 12
    var morale = 4
    var credits = 3
    var dPeople = 0
    var dFood = 0
    var dMats = 0
    var dMorale = 0
    var dCredits = 0
}

final class OutpostGame: ObservableObject {
    @Published var tiles: [Hex: Tile] = [:]
    @Published var troops: [Troop] = []
    @Published var bag = Bag()
    @Published var day = 1
    @Published var quotaDone = false
    @Published var deficit = 0
    @Published var selected: Hex?
    @Published var pickedTroop: Int?
    @Published var log = ""
    @Published var ended = false
    @Published var won = false
    @Published var showBrief = true
    @Published var mode = "build"

    let radius = 3
    let hq = Hex(q: 0, r: 0)
    let point = Hex(q: 2, r: -3)
    let lastDay = 10
    let quotaDay = 6
    let quotaNeed = 5
    private var nextId = 1

    init() { reset() }

    func reset() {
        var map: [Hex: Tile] = [:]
        for q in -radius...radius {
            for r in max(-radius, -q - radius)...min(radius, -q + radius) {
                let h = Hex(q: q, r: r)
                let roll = abs((q * 17 + r * 31) % 10)
                let t: Terrain = h == hq ? .plain : (roll < 4 ? .plain : roll < 6 ? .forest : roll < 7 ? .river : roll < 9 ? .ruin : .waste)
                var tile = Tile(hex: h, terrain: t, revealed: h.distance(to: hq) <= 1, building: h == hq ? .hq : nil, owner: h == hq ? 1 : 0)
                if h == point {
                    tile.isPoint = true
                    tile.owner = 2
                    tile.revealed = false
                    tile.terrain = .ruin
                }
                map[h] = tile
            }
        }
        tiles = map
        nextId = 1
        troops = [
            spawn(1, .infantry, Hex(q: 0, r: 1)),
            spawn(2, .infantry, point),
            spawn(2, .infantry, Hex(q: 2, r: -2))
        ]
        bag = Bag()
        day = 1
        quotaDone = false
        deficit = 0
        selected = hq
        pickedTroop = nil
        ended = false
        won = false
        showBrief = true
        mode = "build"
        log = "Разведай. Строй. Возьми точку."
        tickIncome()
    }

    func spawn(_ side: Int, _ kind: Force, _ hex: Hex) -> Troop {
        let t = Troop(id: nextId, side: side, kind: kind, hex: hex, hp: kind.hp)
        nextId += 1
        return t
    }

    func tile(_ h: Hex) -> Tile? { tiles[h] }
    func troop(on h: Hex) -> Troop? { troops.first { $0.hex == h } }
    func myTroop(_ id: Int) -> Troop? { troops.first { $0.id == id && $0.side == 1 } }

    func isExplorable(_ h: Hex) -> Bool {
        guard let t = tiles[h], !t.revealed else { return false }
        return h.neighbors().contains { tiles[$0]?.revealed == true }
    }

    func tap(_ h: Hex) {
        guard !ended, !showBrief, tiles[h] != nil else { return }
        selected = h
        if let pid = pickedTroop, let me = myTroop(pid), !me.acted {
            if me.hex == h { pickedTroop = nil; return }
            if tryOrder(me, to: h) { return }
        }
        if let u = troop(on: h), u.side == 1 {
            pickedTroop = u.id
            log = "\(u.kind.title), HP \(u.hp). Ход или удар по соседу."
            return
        }
        pickedTroop = nil
        if isExplorable(h) { explore(h, drone: false) }
    }

    func explore(_ h: Hex, drone: Bool) {
        guard var t = tiles[h], !t.revealed else { return }
        if !drone {
            guard bag.people >= 1 else { log = "Нет людей на разведку."; return }
            bag.people -= 1
        }
        t.revealed = true
        tiles[h] = t
        var extra = ""
        if t.terrain == .ruin { bag.credits += 2; extra = " +запасы" }
        if t.terrain == .forest { bag.mats += 1; extra = " +лес" }
        if t.isPoint { extra = " Цель." }
        log = "Открыто: \(t.terrain.label).\(extra)"
        tickIncome()
    }

    func droneSweep() {
        guard let h = selected, let d = troops.first(where: { $0.side == 1 && $0.kind == .drone && !$0.acted }) else {
            log = "Нужен БПЛА без хода."
            return
        }
        guard isExplorable(h) || (tiles[h]?.revealed == false) else {
            log = "Выбери туман."
            return
        }
        explore(h, drone: true)
        if let i = troops.firstIndex(where: { $0.id == d.id }) { troops[i].acted = true }
    }

    func tryOrder(_ me: Troop, to dest: Hex) -> Bool {
        let adj = me.hex.neighbors().contains(dest)
        let near = adj || (me.kind == .scout && me.hex.distance(to: dest) <= 2 && tiles.keys.contains(dest))
        guard near else { return false }
        guard var land = tiles[dest] else { return false }
        if !land.revealed {
            if me.kind == .drone || me.kind == .scout { explore(dest, drone: true); markActed(me.id); return true }
            return false
        }
        if let foe = troop(on: dest), foe.side != 1 {
            if me.kind == .drone { log = "БПЛА не бьёт."; return true }
            guard adj else { log = "Удар только в соседа."; return true }
            hit(attacker: me, defender: foe)
            markActed(me.id)
            return true
        }
        if troop(on: dest) != nil { log = "Клетка занята."; return true }
        if !me.kind.canEnter(land.terrain) { log = "Сюда не пройти."; return true }
        if !adj && !(me.kind == .scout && me.hex.distance(to: dest) == 2) { return false }
        if let i = troops.firstIndex(where: { $0.id == me.id }) {
            troops[i].hex = dest
            troops[i].acted = true
        }
        if land.owner != 1 {
            land.owner = 1
            tiles[dest] = land
            if land.isPoint { log = "Точка взята." } else { log = "Клетка наша." }
        } else {
            log = "\(me.kind.title) перешла."
        }
        checkWinLose()
        return true
    }

    func hit(attacker: Troop, defender: Troop) {
        guard let di = troops.firstIndex(where: { $0.id == defender.id }) else { return }
        let dmg = attacker.kind.atk
        troops[di].hp -= dmg
        log = "\(attacker.kind.title) бьёт \(defender.kind.title): -\(dmg)"
        if troops[di].hp <= 0 {
            let deadHex = troops[di].hex
            troops.remove(at: di)
            if defender.side == 2, var t = tiles[deadHex] {
                t.owner = 1
                tiles[deadHex] = t
                log = "Отряд снят. Клетка наша."
            } else {
                log = "Наш отряд сбит."
            }
        }
        checkWinLose()
    }

    func markActed(_ id: Int) {
        if let i = troops.firstIndex(where: { $0.id == id }) { troops[i].acted = true }
        pickedTroop = nil
    }

    func canBuild(_ b: Building, on h: Hex) -> Bool {
        guard let t = tiles[h], t.revealed, t.building == nil, t.buildingDays == 0, t.owner == 1 else { return false }
        if t.terrain == .river { return false }
        return bag.people >= b.people && bag.mats >= b.mats
    }

    func startBuild(_ b: Building) {
        guard let h = selected, canBuild(b, on: h), var t = tiles[h] else {
            log = "Выбери свою пустую клетку."
            return
        }
        bag.people -= b.people
        bag.mats -= b.mats
        t.building = b
        t.buildingDays = 1
        tiles[h] = t
        log = "\(b.title): готово завтра."
        tickIncome()
    }

    func recruit(_ k: Force) {
        guard let h = selected, let t = tiles[h], t.owner == 1, t.revealed else {
            log = "Выбери свою клетку."
            return
        }
        guard troop(on: h) == nil else { log = "Здесь уже стоит отряд."; return }
        let needBarracks = k == .infantry || k == .scout
        let needShop = k == .armor || k == .drone
        let hasB = tiles.values.contains { $0.building == .barracks && $0.buildingDays == 0 }
        let hasW = tiles.values.contains { $0.building == .workshop && $0.buildingDays == 0 }
        if needBarracks && !hasB { log = "Нужна казарма."; return }
        if needShop && !hasW { log = "Нужна мастерская."; return }
        guard bag.people >= k.peopleCost, bag.mats >= k.matCost else { log = "Не хватает ресурсов."; return }
        guard k.canEnter(t.terrain) else { log = "Сюда этот отряд не встает."; return }
        bag.people -= k.peopleCost
        bag.mats -= k.matCost
        troops.append(spawn(1, k, h))
        log = "\(k.title) в строю."
        tickIncome()
    }

    func endDay() {
        guard !ended, !showBrief else { return }
        for (h, var t) in tiles where t.buildingDays > 0 {
            t.buildingDays -= 1
            tiles[h] = t
            if t.buildingDays == 0 { log = "Готово: \(t.building?.title ?? "")" }
        }
        tickIncome()
        bag.people = max(0, bag.people + bag.dPeople)
        bag.food += bag.dFood
        bag.mats = max(0, bag.mats + bag.dMats)
        bag.morale = max(0, bag.morale + bag.dMorale)
        bag.credits = max(0, bag.credits + bag.dCredits)

        enemyAct()

        if bag.food < 0 || bag.people <= 0 {
            deficit += 1
            log = "Дефицит. Осталось дней: \(3 - deficit)."
            if deficit >= 3 { fail("Срыв по снабжению."); return }
        } else { deficit = 0 }

        if day == quotaDay {
            if bag.credits >= quotaNeed {
                bag.credits -= quotaNeed
                quotaDone = true
                log = "План сдан. Бери точку."
            } else { fail("План на 6 день не сдан."); return }
        }

        if day >= lastDay {
            let hold = tiles[hq]?.owner == 1 && tiles[point]?.owner == 1 && quotaDone
            ended = true
            won = hold
            log = won ? "Рейд закрыт. Точка наша." : "10 дней. Цель не взята."
            return
        }

        day += 1
        for i in troops.indices { troops[i].acted = false }
        pickedTroop = nil
        tickIncome()
        checkWinLose()
    }

    func enemyAct() {
        let foes = troops.filter { $0.side == 2 }
        for foe in foes {
            let victims = foe.hex.neighbors().compactMap { troop(on: $0) }.filter { $0.side == 1 && $0.kind != .drone }
            if let v = victims.first {
                hit(attacker: foe, defender: v)
            }
        }
    }

    func checkWinLose() {
        if tiles[point]?.owner == 1 && quotaDone && day <= lastDay && !ended {
            ended = true
            won = true
            log = "Точка взята. Рейд закрыт."
        }
    }

    func fail(_ m: String) {
        ended = true
        won = false
        log = m
    }

    func tickIncome() {
        var p = 0, f = -1, m = 0, mo = 0, c = 0
        for t in tiles.values where t.revealed && t.buildingDays == 0 {
            switch t.building {
            case .hq: p += 1; m += 1
            case .barracks: p += 2; f -= 1
            case .kitchen: f += 3
            case .workshop: m += 2
            case .radio: mo += 1; c += 1
            default: break
            }
            if t.terrain == .forest, t.building == .workshop { m += 1 }
            if t.terrain == .plain, t.building == .kitchen { f += 1 }
        }
        f -= max(0, (bag.people + p) / 5)
        bag.dPeople = p; bag.dFood = f; bag.dMats = m; bag.dMorale = mo; bag.dCredits = c
    }
}
