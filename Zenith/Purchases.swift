import SwiftUI
import StoreKit

/// One non-consumable "Pro" unlock.
@MainActor
final class PurchaseManager: ObservableObject {
    static let productID = "com.vashchenko.zenithsky.pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPro: Bool
    @Published var busy = false
    @Published var message: String?
    private var updates: Task<Void, Never>?

    init() {
        var pro = UserDefaults.standard.bool(forKey: "zen.pro")
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "zpro") { pro = true }
        #endif
        isPro = pro
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await load(); await refresh() }
    }
    deinit { updates?.cancel() }

    var price: String { product?.displayPrice ?? "$7.99" }

    func load() async { product = try? await Product.products(for: [Self.productID]).first }

    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "zpro") { owned = true }
        #endif
        set(owned)
    }

    private func set(_ v: Bool) { isPro = v; UserDefaults.standard.set(v, forKey: "zen.pro") }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        if case .verified(let t) = result, t.productID == Self.productID {
            set(t.revocationDate == nil); await t.finish()
        }
    }

    func buy() async {
        guard let product else { message = "The store isn't reachable right now. Please try again in a moment."; await load(); return }
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                switch result {
                case .verified(let t): set(true); await t.finish(); UINotificationFeedbackGenerator().notificationOccurred(.success)
                case .unverified: message = "We couldn't verify that purchase."
                }
            case .pending: message = "Your purchase is waiting for approval."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "Purchase failed: \(error.localizedDescription)" }
    }

    func restore() async {
        busy = true; defer { busy = false }
        do { try await AppStore.sync() } catch { message = "Couldn't reach the App Store." }
        await refresh()
        if !isPro && message == nil { message = "No previous purchase found for this Apple account." }
    }
}
