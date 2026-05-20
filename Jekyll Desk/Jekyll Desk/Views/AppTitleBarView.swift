import SwiftUI

struct AppTitleBarView: View {
    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                trafficLight(.red)
                trafficLight(.yellow)
                trafficLight(.green)
                Spacer()
            }
            .padding(.leading, 18)

            Text("Jekyll Desk")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primaryText)
        }
        .frame(height: 38)
        .background(Color.toolbarBackground)
    }

    private func trafficLight(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}
