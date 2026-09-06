import SwiftUI

struct GameRootView: View {
    @StateObject private var game = OutpostGame()

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.09, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                HexBoard(game: game).frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
            if game.showBrief { brief }
            if game.panel == .explore { exploreSheet }
            if game.panel == .tile { tileSheet }
            if game.panel == .build { buildSheet }
            if game.panel == .recruit { recruitSheet }
            if game.panel == .plan { planSheet }
            if game.panel == .event { eventSheet }
        }
    }

    var brief: some View {
        dim {
            Text("РЕЙД 01")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
            Text("10 дней. Разведай туман, строй базу, возьми точку встречной группы.\nПехота держит. Разведка ходит дальше. Техника сильнее. БПЛА только светит.\nВраг бьёт, землю назад не берёт.\n6 день — сдать 5 кредитов.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            gold("НАЧАТЬ") { game.showBrief = false }
        }
    }

    var exploreSheet: some View {
        dim {
            Text("Разведать")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
            Text("Соседняя клетка. Узнаем землю.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
            if game.bag.people >= 1 {
                gold("Выслать · −1 чел") { game.confirmExplore() }
            } else {
                locked("Нет людей")
            }
            if game.idleDrone != nil {
                gold("БПЛА") { game.confirmDroneExplore() }
            }
            pale("Назад") { game.closePanel() }
        }
    }

    var tileSheet: some View {
        dim {
            if let h = game.selected, let t = game.tile(h) {
                Text(t.terrain.label)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
            }
            gold("Строить") {
                game.buildPick = 0
                game.panel = .build
            }
            if let h = game.selected, game.troop(on: h) == nil {
                gold("Набрать") {
                    game.recruitPick = 0
                    game.panel = .recruit
                }
            }
            pale("Назад") { game.closePanel() }
        }
    }

    var buildSheet: some View {
        let b = game.buildList[game.buildPick]
        let block = game.buildBlock(b)
        return dim {
            HStack {
                pale("‹") { game.buildPick = (game.buildPick + 3) % 4 }
                VStack(spacing: 6) {
                    Text(b.title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
                    Text("1 день · \(b.growth)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                    Text("\(b.people) чел · \(b.mats) мат")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                }.frame(maxWidth: .infinity)
                pale("›") { game.buildPick = (game.buildPick + 1) % 4 }
            }
            if let block {
                locked(block)
            } else {
                gold("Подтвердить") { game.startBuild(b) }
            }
            pale("Назад") { game.panel = .tile }
        }
    }

    var recruitSheet: some View {
        let k = game.forceList[game.recruitPick]
        let block = game.recruitBlock(k)
        return dim {
            HStack {
                pale("‹") { game.recruitPick = (game.recruitPick + 3) % 4 }
                VStack(spacing: 6) {
                    Text(k.title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
                    Text("HP \(k.hp) · удар \(k.atk)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                    Text("\(k.peopleCost) чел · \(k.matCost) мат")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                }.frame(maxWidth: .infinity)
                pale("›") { game.recruitPick = (game.recruitPick + 1) % 4 }
            }
            if let block {
                locked(block)
            } else {
                gold("Подтвердить") { game.recruit(k) }
            }
            pale("Назад") { game.panel = .tile }
        }
    }

    var planSheet: some View {
        dim {
            Text("План связи")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
            Text(game.quotaDone ? "План сдан. Держи точку до дня 10." : "К дню 6 сдать 5 кредитов.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            pale("Закрыть") { game.closePanel() }
        }
    }

    var eventSheet: some View {
        dim {
            Text(game.eventDay == 3 ? "Обрыв связи" : "Налёт")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
            Text(game.eventDay == 3
                 ? "Ночь глушит эфир. Штаб ждёт донесение."
                 : "С гряды бьют по краю базы.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            eventBtn(0)
            eventBtn(1)
            eventBtn(2)
        }
    }

    func eventBtn(_ i: Int) -> some View {
        let labels: [[String]] = [
            ["Тянуть смену · −2 чел +1 мор", "Ждать утро · −1 мор", "Жечь топливо · −2 мат +1 кр"],
            ["Посадить людей · −1 чел", "Не сниматься · штаб −2", "Ответить огнём · −2 мат"]
        ]
        let row = game.eventDay == 8 ? 1 : 0
        let on = game.eventChoiceEnabled(i)
        return Button(action: { if on { game.pickEvent(i) } }) {
            Text(labels[row][i])
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(on ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                .foregroundColor(on ? .white : .white.opacity(0.35))
        }
        .disabled(!on)
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("АВАНПОСТ 2026")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.80, green: 0.86, blue: 0.68))
                Spacer()
                Text("День \(game.day)/10")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
            HStack {
                stat("ЛЮДИ", game.bag.people, game.bag.dPeople)
                stat("ПАЁК", game.bag.food, game.bag.dFood)
                stat("МАТ", game.bag.mats, game.bag.dMats)
                stat("МОР", game.bag.morale, game.bag.dMorale)
                stat("КР", game.bag.credits, game.bag.dCredits)
            }
            Button(action: { if !game.ended && !game.showBrief && game.panel != .event { game.panel = .plan } }) {
                Text(game.quotaDone ? "План сдан · возьми точку" : "План 5 КР · день 6")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.74, green: 0.64, blue: 0.34))
            }
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)
    }

    func stat(_ n: String, _ v: Int, _ d: Int) -> some View {
        VStack(spacing: 1) {
            Text(n).font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.45))
            Text("\(v)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
            Text(d >= 0 ? "+\(d)" : "\(d)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(d >= 0 ? Color(red: 0.55, green: 0.76, blue: 0.44) : Color(red: 0.86, green: 0.38, blue: 0.32))
        }.frame(maxWidth: .infinity)
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.log)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            if let h = game.selected, let t = game.tile(h) {
                let u = game.troop(on: h)
                let hp = t.building == .hq ? "·ШТ \(game.hqHp)" : ""
                let unit = u == nil ? "" : "·\(u!.kind.title) \(u!.hp)"
                Text(t.revealed ? "\(t.terrain.label)·\(t.building?.title ?? "пусто")\(hp)\(unit)" : "Туман")
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
            }
            if game.ended {
                gold(game.won ? "Ещё раз" : "Заново") { game.reset() }
            } else if game.panel != .event {
                gold("КОНЕЦ ДНЯ") { game.endDay() }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.38))
    }

    func dim<Content: View>(@ViewBuilder _ c: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) { c() }
                .padding(20)
                .background(Color(red: 0.10, green: 0.12, blue: 0.10))
                .padding(16)
        }
    }

    func gold(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(Color(red: 0.36, green: 0.28, blue: 0.14))
                .foregroundColor(Color(red: 0.95, green: 0.88, blue: 0.62))
        }
    }

    func pale(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Color.white.opacity(0.08)).foregroundColor(.white)
        }
    }

    func locked(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .foregroundColor(Color(red: 0.86, green: 0.45, blue: 0.40))
    }
}

struct HexBoard: View {
    @ObservedObject var game: OutpostGame
    @State private var origin: CGSize = .zero
    @State private var drag: CGSize = .zero
    var body: some View {
        GeometryReader { geo in
            let hexR = min(geo.size.width, geo.size.height) / CGFloat(game.radius * 2 + 3) * 0.95
            let o = CGPoint(x: geo.size.width/2 + origin.width + drag.width,
                            y: geo.size.height/2 + origin.height + drag.height)
            ZStack {
                ForEach(Array(game.tiles.keys), id: \.self) { h in
                    HexCell(game: game, hex: h, radius: hexR)
                        .position(pt(h, o, hexR))
                        .onTapGesture { game.tap(h) }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { drag = $0.translation }
                    .onEnded {
                        origin.width += $0.translation.width
                        origin.height += $0.translation.height
                        drag = .zero
                    }
            )
            .onTapGesture(count: 2) {
                origin = .zero
                drag = .zero
            }
        }.clipped()
    }
    func pt(_ h: Hex, _ o: CGPoint, _ r: CGFloat) -> CGPoint {
        CGPoint(x: o.x + CGFloat(h.q) * r * 1.75, y: o.y + CGFloat(h.r) * r * 1.55 + CGFloat(h.q) * r * 0.78)
    }
}

struct HexCell: View {
    @ObservedObject var game: OutpostGame
    let hex: Hex
    let radius: CGFloat
    var body: some View {
        let t = game.tile(hex)
        let u = game.troop(on: hex)
        let fog = t?.revealed != true
        let sel = game.selected == hex
        let pointOpen = t?.isPoint == true && t?.revealed == true && t?.owner != 1
        let reach = game.isReachable(hex) && hex != game.selected
        ZStack {
            HexShape().fill(fog ? Color(red: 0.10, green: 0.12, blue: 0.10) : (t?.terrain.tint ?? .gray))
            HexShape().stroke(
                pointOpen ? Color(red: 0.78, green: 0.32, blue: 0.22) :
                (sel ? Color(red: 0.92, green: 0.82, blue: 0.38) :
                 (reach ? Color(red: 0.80, green: 0.72, blue: 0.32).opacity(0.7) : Color.white.opacity(fog ? 0.08 : 0.16))),
                lineWidth: sel || pointOpen ? 2 : 1
            )
            VStack(spacing: 0) {
                if let b = t?.building, t?.revealed == true {
                    Text(b == .hq ? "\(b.mark) \(game.hqHp)" : (t?.buildingDays ?? 0) > 0 ? "\(b.mark) 1д" : b.mark)
                        .font(.system(size: max(7, radius * 0.26), weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                }
                if let u, t?.revealed == true {
                    Text("\(u.kind.mark)\(u.hp)")
                        .font(.system(size: max(9, radius * 0.38), weight: .bold, design: .monospaced))
                        .foregroundColor(u.side == 1 ? Color(red: 0.78, green: 0.88, blue: 0.55) : Color(red: 0.90, green: 0.42, blue: 0.32))
                        .opacity(u.acted ? 0.45 : 1)
                } else if game.isExplorable(hex) {
                    Text("?").font(.system(size: max(9, radius * 0.36), weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .frame(width: radius * 1.7, height: radius * 1.9)
    }
}

struct HexShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3 - .pi / 6
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
