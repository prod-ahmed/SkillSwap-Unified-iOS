import SwiftUI

/// A glassmorphic overlay that highlights a specific area with a spotlight effect
struct CoachMarkOverlay: View {
    let step: TourStep
    let targetRect: CGRect
    let onNext: () -> Void
    let onSkip: () -> Void
    let isLastStep: Bool
    let progress: Double
    
    @State private var isPulsing = false
    @State private var tooltipOpacity: Double = 0
    
    private let spotlightPadding: CGFloat = 12
    private let tooltipWidth: CGFloat = 280
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay with spotlight cutout
                spotlightMask(in: geometry.size)
                
                // Pulsing ring around spotlight
                pulsingRing
                    .position(x: targetRect.midX, y: targetRect.midY)
                
                // Tooltip card
                tooltipCard
                    .position(tooltipPosition(in: geometry.size))
                    .opacity(tooltipOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                tooltipOpacity = 1
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
    
    // MARK: - Spotlight Mask
    
    private func spotlightMask(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Fill entire canvas with dark overlay
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.black.opacity(0.75))
            )
            
            // Cut out the spotlight area
            context.blendMode = .destinationOut
            
            let spotlightRect = targetRect.insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
            let spotlightPath = Path(roundedRect: spotlightRect, cornerRadius: 16)
            
            context.fill(spotlightPath, with: .color(.white))
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
    
    // MARK: - Pulsing Ring
    
    private var pulsingRing: some View {
        let size = max(targetRect.width, targetRect.height) + spotlightPadding * 2 + 8
        
        return ZStack {
            // Outer pulsing ring
            RoundedRectangle(cornerRadius: 20)
                .stroke(step.accentColor.opacity(0.6), lineWidth: 3)
                .frame(width: size + (isPulsing ? 20 : 0), height: size + (isPulsing ? 20 : 0))
                .opacity(isPulsing ? 0.3 : 0.8)
            
            // Inner ring
            RoundedRectangle(cornerRadius: 16)
                .stroke(step.accentColor, lineWidth: 2)
                .frame(width: size, height: size)
        }
    }
    
    // MARK: - Tooltip Card
    
    private var tooltipCard: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Icon and title
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(step.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: step.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(step.accentColor)
                    }
                    
                    Text(step.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                // Description
                Text(step.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Buttons
            HStack(spacing: 12) {
                // Skip button
                Button(action: onSkip) {
                    Text("Passer")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Next/Finish button
                Button(action: onNext) {
                    HStack(spacing: 6) {
                        Text(isLastStep ? "Terminer" : "Suivant")
                            .font(.system(size: 15, weight: .semibold))
                        
                        if !isLastStep {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [step.accentColor, step.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: step.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .frame(width: tooltipWidth)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                // Progress fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.spring(response: 0.4), value: progress)
            }
        }
        .frame(height: 4)
    }
    
    // MARK: - Tooltip Positioning
    
    private func tooltipPosition(in size: CGSize) -> CGPoint {
        let horizontalCenter = size.width / 2
        
        // Position tooltip above or below the target
        let targetBottom = targetRect.maxY + spotlightPadding
        let targetTop = targetRect.minY - spotlightPadding
        
        let tooltipHeight: CGFloat = 220 // Approximate height
        let safeAreaTop: CGFloat = 60
        let safeAreaBottom: CGFloat = 120
        
        let y: CGFloat
        
        // Prefer positioning below the target
        if targetBottom + tooltipHeight + 20 < size.height - safeAreaBottom {
            y = targetBottom + tooltipHeight / 2 + 20
        }
        // Otherwise position above
        else if targetTop - tooltipHeight - 20 > safeAreaTop {
            y = targetTop - tooltipHeight / 2 - 20
        }
        // Fallback to center
        else {
            y = size.height / 2
        }
        
        return CGPoint(x: horizontalCenter, y: y)
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.3)
        
        CoachMarkOverlay(
            step: TourStep.allSteps[0],
            targetRect: CGRect(x: 50, y: 700, width: 60, height: 50),
            onNext: {},
            onSkip: {},
            isLastStep: false,
            progress: 0.25
        )
    }
}
