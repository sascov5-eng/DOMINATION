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
    var growth: String {
        switch self {
        case .hq: return "+1 чел +1 мат"
        case .barracks: return "+2 чел −1 паёк"
        case .kitchen: return "+3 паёк"
        case .workshop: return "+2 мат"
        case .radio: return "+1 мор +1 кр"
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

enum Panel {
    case none, explore, tile, build, recruit, event, plan
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
    @Published var panel: Panel = .none
    @Published var hqHp = 6
    @Published var buildPick = 0
    @Published var recruitPick = 0
    @Published var eventDay = 0

    let radius = 3
    let hq = Hex(q: 0, r: 0)
    let point = Hex(q: 2, r: -3)
    let lastDay = 10
    let quotaDay = 6
    let quotaNeed = 5
    let hqMax = 6
    let buildList: [Building] = [.barracks, .kitchen, .workshop, .radio]
    let forceList: [Force] = [.infantry, .scout, .armor, .drone]
    private var nextId = 1

    init() { reset() }

    var idleDrone: Troop? {
        troops.first { $0.side == 1 && $0.kind == .drone && !$0.acted }
    }

    var myTroopCount: Int { troops.filter { $0.side == 1 }.count }

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
        panel = .none
        hqHp = hqMax
        buildPick = 0
        recruitPick = 0
        eventDay = 0
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
    func hasBuilding(_ b: Building) -> Bool { tiles.values.contains { $0.building == b } }

    func isExplorable(_ h: Hex) -> Bool {
        guard let t = tiles[h], !t.revealed else { return false }
        return h.neighbors().contains { tiles[$0]?.revealed == true }
    }

    func isReachable(_ h: Hex) -> Bool {
        guard let pid = pickedTroop, let me = myTroop(pid), !me.acted else { return false }
        let d = me.hex.distance(to: h)
        if d == 1 { return true }
        if d == 2 && (me.kind == .scout || me.kind == .drone) { return true }
        return false
    }

    func closePanel() { if panel != .event { panel = .none } }

    func tap(_ h: Hex) {
        guard !ended, !showBrief, panel != .event, tiles[h] != nil else { return }
        selected = h
        if let pid = pickedTroop, let me = myTroop(pid), !me.acted {
            if me.hex == h {
                pickedTroop = nil
                panel = .none
                return
            }
            if tryOrder(me, to: h) {
                panel = .none
                return
            }
        }
        if let u = troop(on: h), u.side == 1 {
            pickedTroop = u.id
            panel = .none
            log = "\(u.kind.title), HP \(u.hp). Ход или удар по соседу."
            return
        }
        pickedTroop = nil
        if isExplorable(h) {
            panel = .explore
            return
        }
        if let t = tiles[h], t.revealed, t.owner == 1, t.terrain != .river {
            panel = .tile
            return
        }
        panel = .none
    }

    func confirmExplore() {
        guard let h = selected else { return }
        explore(h, drone: false)
        panel = .none
    }

    func confirmDroneExplore() {
        guard let h = selected, let d = idleDrone else {
            log = "Нужен БПЛА без хода."
            return
        }
        guard isExplorable(h) || tiles[h]?.revealed == false else { return }
        explore(h, drone: true)
        if let i = troops.firstIndex(where: { $0.id == d.id }) { troops[i].acted = true }
        panel = .none
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

    func tryOrder(_ me: Troop, to dest: Hex) -> Bool {
        let adj = me.hex.neighbors().contains(dest)
        let near = adj || ((me.kind == .scout || me.kind == .drone) && me.hex.distance(to: dest) <= 2 && tiles.keys.contains(dest))
        guard near else { return false }
        guard var land = tiles[dest] else { return false }
        if !land.revealed {
            if me.kind == .drone || me.kind == .scout {
                explore(dest, drone: true)
                markActed(me.id)
                return true
            }
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
        if !adj && !((me.kind == .scout || me.kind == .drone) && me.hex.distance(to: dest) == 2) { return false }
        if let i = troops.firstIndex(where: { $0.id == me.id }) {
            troops[i].hex = dest
            troops[i].acted = true
        }
        if land.owner != 1 {
            land.owner = 1
            tiles[dest] = land
            log = land.isPoint ? "Точка взята. Держи до дня 10." : "Клетка наша."
        } else {
            log = "\(me.kind.title) перешла."
        }
        checkHq()
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
                log = t.isPoint ? "Точка взята. Держи до дня 10." : "Отряд снят. Клетка наша."
            } else {
                log = "Наш отряд сбит."
            }
        }
        checkHq()
    }

    func markActed(_ id: Int) {
        if let i = troops.firstIndex(where: { $0.id == id }) { troops[i].acted = true }
        pickedTroop = nil
    }

    func buildBlock(_ b: Building) -> String? {
        guard let h = selected, let t = tiles[h] else { return "Выбери клетку." }
        if !t.revealed || t.owner != 1 { return "Только своя клетка." }
        if t.terrain == .river { return "На реку нельзя." }
        if t.building != nil { return "Здесь уже стоит здание." }
        if hasBuilding(b) { return "Уже стоит." }
        if bag.people < b.people || bag.mats < b.mats { return "Не хватает ресурсов." }
        return nil
    }

    func canBuild(_ b: Building, on h: Hex) -> Bool {
        selected = h
        return buildBlock(b) == nil
    }

    func startBuild(_ b: Building) {
        guard let h = selected, buildBlock(b) == nil, var t = tiles[h] else {
            log = buildBlock(b) ?? "Выбери свою пустую клетку."
            return
        }
        bag.people -= b.people
        bag.mats -= b.mats
        t.building = b
        t.buildingDays = 1
        tiles[h] = t
        log = "\(b.title): готово завтра."
        panel = .none
        tickIncome()
    }

    func recruitBlock(_ k: Force) -> String? {
        guard let h = selected, let t = tiles[h] else { return "Выбери клетку." }
        if t.owner != 1 || !t.revealed { return "Выбери свою клетку." }
        if troop(on: h) != nil { return "Здесь уже стоит отряд." }
        if myTroopCount >= 4 { return "Уже 4 отряда." }
        let needBarracks = k == .infantry || k == .scout
        let needShop = k == .armor || k == .drone
        let hasB = tiles.values.contains { $0.building == .barracks && $0.buildingDays == 0 }
        let hasW = tiles.values.contains { $0.building == .workshop && $0.buildingDays == 0 }
        if needBarracks && !hasB { return "Нужна казарма." }
        if needShop && !hasW { return "Нужна мастерская." }
        if bag.people < k.peopleCost || bag.mats < k.matCost { return "Не хватает ресурсов." }
        if !k.canEnter(t.terrain) { return "Сюда этот отряд не встает." }
        return nil
    }

    func recruit(_ k: Force) {
        guard let h = selected, recruitBlock(k) == nil else {
            log = recruitBlock(k) ?? "Выбери свою клетку."
            return
        }
        bag.people -= k.peopleCost
        bag.mats -= k.matCost
        troops.append(spawn(1, k, h))
        log = "\(k.title) в строю."
        panel = .none
        tickIncome()
    }

    func endDay() {
        guard !ended, !showBrief, panel != .event else { return }
        panel = .none
        pickedTroop = nil
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
        if ended { return }

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

        if day == 3 || day == 8 {
            eventDay = day
            panel = .event
            return
        }
        finishDay()
    }

    func eventChoiceEnabled(_ i: Int) -> Bool {
        if eventDay == 3 {
            if i == 0 { return bag.people >= 2 }
            if i == 2 { return bag.mats >= 2 }
            return true
        }
        if eventDay == 8 {
            if i == 0 { return bag.people >= 1 }
            if i == 2 { return bag.mats >= 2 }
            return true
        }
        return false
    }

    func pickEvent(_ i: Int) {
        guard panel == .event, eventChoiceEnabled(i) else { return }
        if eventDay == 3 {
            if i == 0 { bag.people -= 2; bag.morale += 1; log = "Смена тянет эфир." }
            if i == 1 { bag.morale = max(0, bag.morale - 1); log = "Ждём утро." }
            if i == 2 { bag.mats -= 2; bag.credits += 1; log = "Топливо ушло в эфир." }
        } else if eventDay == 8 {
            if i == 0 { bag.people -= 1; log = "Люди в укрытии." }
            if i == 1 { strikeHQ(2); if ended { panel = .none; eventDay = 0; return } }
            if i == 2 { bag.mats -= 2; log = "Ответили огнём." }
        }
        panel = .none
        eventDay = 0
        tickIncome()
        finishDay()
    }

    func finishDay() {
        if day >= lastDay {
            let hold = tiles[hq]?.owner == 1 && hqHp > 0 && tiles[point]?.owner == 1 && quotaDone
            ended = true
            won = hold
            log = won ? "Рейд закрыт. Точка наша." : "10 дней. Цель не взята."
            return
        }
        day += 1
        for i in troops.indices { troops[i].acted = false }
        pickedTroop = nil
        tickIncome()
    }

    func enemyAct() {
        let foes = troops.filter { $0.side == 2 }
        for foe in foes {
            if ended { return }
            let victims = foe.hex.neighbors().compactMap { troop(on: $0) }.filter { $0.side == 1 && $0.kind != .drone }
            if let v = victims.first {
                hit(attacker: foe, defender: v)
            } else if foe.hex.neighbors().contains(hq), troop(on: hq) == nil {
                strikeHQ(2)
            }
        }
    }

    func strikeHQ(_ dmg: Int) {
        hqHp = max(0, hqHp - dmg)
        log = "Удар по штабу: −\(dmg). Осталось \(hqHp)."
        checkHq()
    }

    func checkHq() {
        if hqHp <= 0 || tiles[hq]?.owner != 1 { fail("Штаб упал.") }
    }

    func fail(_ m: String) {
        ended = true
        won = false
        panel = .none
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
        if bag.morale == 0 {
            p = p / 2
            m = m / 2
            c = c / 2
        }
        bag.dPeople = p; bag.dFood = f; bag.dMats = m; bag.dMorale = mo; bag.dCredits = c
    }
}
