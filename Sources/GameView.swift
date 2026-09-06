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
        }
    }

    var brief: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("РЕЙД 01")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.56))
                Text("10 дней. Разведай туман, строй базу, возьми точку встречной группы.\nПехота, разведка, техника, БПЛА — только светит.\nВраг бьёт, землю назад не берёт.\n6 день — сдать 5 кредитов.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: { game.showBrief = false }) {
                    Text("НАЧАТЬ")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(red: 0.34, green: 0.28, blue: 0.14))
                        .foregroundColor(Color(red: 0.95, green: 0.88, blue: 0.62))
                }
            }
            .padding(22)
            .background(Color(red: 0.10, green: 0.12, blue: 0.10))
            .padding(18)
        }
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
            Text(game.quotaDone ? "План сдан · возьми точку" : "План 5 КР · день 6")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(red: 0.74, green: 0.64, blue: 0.34))
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
                Text(t.revealed ? "\(t.terrain.label)·\(t.building?.title ?? "пусто")·\(u?.kind.title ?? "")" : "Туман")
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
            }
            if game.ended {
                Button(action: game.reset) {
                    Text(game.won ? "Ещё раз" : "Заново")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(red: 0.20, green: 0.28, blue: 0.18)).foregroundColor(.white)
                }
            } else {
                HStack(spacing: 5) {
                    mini("КЗ") { game.startBuild(.barracks) }
                    mini("КХ") { game.startBuild(.kitchen) }
                    mini("МС") { game.startBuild(.workshop) }
                    mini("РД") { game.startBuild(.radio) }
                }
                HStack(spacing: 5) {
                    mini("Пех") { game.recruit(.infantry) }
                    mini("Разв") { game.recruit(.scout) }
                    mini("Тех") { game.recruit(.armor) }
                    mini("БПЛА") { game.recruit(.drone) }
                    mini("Свет") { game.droneSweep() }
                }
                Button(action: game.endDay) {
                    Text("КОНЕЦ ДНЯ")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(red: 0.36, green: 0.28, blue: 0.14))
                        .foregroundColor(Color(red: 0.95, green: 0.88, blue: 0.62))
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.38))
    }

    func mini(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Color.white.opacity(0.08)).foregroundColor(.white)
        }
    }
}

struct HexBoard: View {
    @ObservedObject var game: OutpostGame
    @State private var drag: CGSize = .zero
    var body: some View {
        GeometryReader { geo in
            let hexR = min(geo.size.width, geo.size.height) / CGFloat(game.radius * 2 + 3) * 0.95
            ZStack {
                ForEach(Array(game.tiles.keys), id: \.self) { h in
                    HexCell(game: game, hex: h, radius: hexR)
                        .position(pt(h, CGPoint(x: geo.size.width/2 + drag.width, y: geo.size.height/2 + drag.height), hexR))
                        .onTapGesture { game.tap(h) }
                }
            }
            .gesture(DragGesture().onChanged { drag = $0.translation }.onEnded { _ in })
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
        ZStack {
            HexShape().fill(fog ? Color(red: 0.10, green: 0.12, blue: 0.10) : (t?.terrain.tint ?? .gray))
            HexShape().stroke(
                t?.isPoint == true && t?.revealed == true ? Color(red: 0.78, green: 0.32, blue: 0.22) :
                (sel ? Color(red: 0.92, green: 0.82, blue: 0.38) : Color.white.opacity(fog ? 0.08 : 0.16)),
                lineWidth: sel || t?.isPoint == true ? 2 : 1
            )
            VStack(spacing: 0) {
                if let b = t?.building, t?.revealed == true {
                    Text(b.mark).font(.system(size: max(7, radius * 0.28), weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                }
                if let u, t?.revealed == true {
                    Text(u.kind.mark)
                        .font(.system(size: max(9, radius * 0.42), weight: .bold, design: .monospaced))
                        .foregroundColor(u.side == 1 ? Color(red: 0.78, green: 0.88, blue: 0.55) : Color(red: 0.90, green: 0.42, blue: 0.32))
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
