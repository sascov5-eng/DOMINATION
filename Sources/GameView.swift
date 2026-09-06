import SwiftUI

struct GameRootView: View {
    @StateObject private var game = OutpostGame()

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.08, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                HexBoard(game: game)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("OUTPOST 2026")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.82, green: 0.86, blue: 0.72))
                Spacer()
                Text("DEN \(game.day)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            HStack(spacing: 8) {
                res("LS", game.res.personnel, game.res.dPersonnel)
                res("PAEK", game.res.rations, game.res.dRations)
                res("MAT", game.res.materiel, game.res.dMateriel)
                res("MOR", game.res.morale, game.res.dMorale)
                res("CR", game.res.credits, game.res.dCredits)
            }
            Text("PLAN \(game.quotaCredits) CR / DEN \(game.quotaDay)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(red: 0.72, green: 0.62, blue: 0.32))
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    func res(_ name: String, _ v: Int, _ d: Int) -> some View {
        VStack(spacing: 1) {
            Text(name)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
            Text("\(v)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(d >= 0 ? "+\(d)" : "\(d)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(d >= 0 ? Color(red: 0.55, green: 0.75, blue: 0.45) : Color(red: 0.86, green: 0.38, blue: 0.32))
        }
        .frame(maxWidth: .infinity)
    }

    var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.log)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let h = game.selected, let t = game.tile(h) {
                Text(t.revealed ? "\(t.terrain.label)  \(t.building?.title ?? (t.buildDaysLeft > 0 ? "STROIKA \(t.buildDaysLeft)" : "PUSTO"))" : "TUMAN")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            if game.ended {
                Button(action: game.reset) {
                    Text(game.won ? "ESHYO REID" : "ZANOVO")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.22, green: 0.28, blue: 0.18))
                        .foregroundColor(.white)
                }
            } else {
                HStack(spacing: 6) {
                    ForEach([Building.barracks, .kitchen, .workshop, .radio], id: \.self) { b in
                        Button(action: { game.startBuild(b) }) {
                            Text(b.mark)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white)
                        }
                    }
                }
                Button(action: game.endDay) {
                    Text("KONETS DNYA")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.36, green: 0.28, blue: 0.14))
                        .foregroundColor(Color(red: 0.95, green: 0.88, blue: 0.62))
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.35))
    }
}

struct HexBoard: View {
    @ObservedObject var game: OutpostGame
    @State private var drag: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let hexR = size / CGFloat(game.radius * 2 + 3) * 0.92
            ZStack {
                ForEach(Array(game.tiles.keys), id: \.self) { h in
                    HexCell(game: game, hex: h, radius: hexR)
                        .position(hexPoint(h, origin: CGPoint(x: geo.size.width / 2 + drag.width, y: geo.size.height / 2 + drag.height), r: hexR))
                        .onTapGesture { game.tap(h) }
                }
            }
            .gesture(DragGesture().onChanged { drag = $0.translation }.onEnded { _ in })
        }
        .clipped()
    }

    func hexPoint(_ h: Hex, origin: CGPoint, r: CGFloat) -> CGPoint {
        let x = CGFloat(h.q) * r * 1.75
        let y = CGFloat(h.r) * r * 1.55 + CGFloat(h.q) * r * 0.78
        return CGPoint(x: origin.x + x, y: origin.y + y)
    }
}

struct HexCell: View {
    @ObservedObject var game: OutpostGame
    let hex: Hex
    let radius: CGFloat

    var body: some View {
        let t = game.tile(hex)
        let selected = game.selected == hex
        let fog = t?.revealed != true
        ZStack {
            HexShape()
                .fill(fog ? Color(red: 0.10, green: 0.12, blue: 0.11) : (t?.terrain.tint ?? .gray))
            HexShape()
                .stroke(selected ? Color(red: 0.92, green: 0.82, blue: 0.38) : Color.white.opacity(fog ? 0.08 : 0.18), lineWidth: selected ? 2 : 1)
            if let b = t?.building, t?.revealed == true {
                Text(b.mark)
                    .font(.system(size: max(8, radius * 0.42), weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            } else if game.isExplorable(hex) {
                Text("?")
                    .font(.system(size: max(9, radius * 0.4), weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
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
