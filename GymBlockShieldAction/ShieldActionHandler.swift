import ManagedSettings

// Handles taps on the shield's buttons. There is exactly one: "Back to the
// workout", which closes the blocked app. There is deliberately no escape
// hatch here — the block ends when the workout ends, in GymBlock, by holding
// "Finish". (The safety cap in GymBlockMonitor guarantees it can't outlive a
// forgotten session.)

nonisolated class ShieldActionHandler: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}
