import Foundation
import Testing
@testable import yls_app

struct CodexMonitorStoreTests {
    @Test
    func resolvesUsedPercentageFromAPIPayload() {
        let usage = UsagePayload(
            remainingQuota: .double(85.94),
            usedPercentage: .double(14.06),
            totalCost: nil,
            totalQuota: .double(100)
        )

        let percent = CodexMonitorStore.resolveUsedPercentage(usage: usage, remaining: .double(85.94))

        #expect(percent == 14.06)
    }

    @Test
    func resolvesUsedPercentageFromTotalAndRemaining() {
        let usage = UsagePayload(
            remainingQuota: .double(85.94),
            usedPercentage: nil,
            totalCost: nil,
            totalQuota: .double(100)
        )

        let percent = CodexMonitorStore.resolveUsedPercentage(usage: usage, remaining: .double(85.94))

        #expect(percent != nil)
        #expect(abs((percent ?? 0) - 14.06) < 0.001)
    }

    @Test
    func formatsQuotaValuesWithoutNoise() {
        #expect(CodexMonitorStore.formatQuotaValue(14) == "14")
        #expect(CodexMonitorStore.formatQuotaValue(14.0625) == "14.06")
    }

    @Test
    func formatsAGIByteValuesAsBytes() {
        #expect(CodexMonitorStore.formatByteCount(8_000_000) == "8,000,000 B")
        #expect(CodexMonitorStore.formatByteCount(18_274) == "18,274 B")
    }

    @Test
    func selectsNearestUpcomingPackage() {
        let package = PackagePayload(
            totalQuota: nil,
            weeklyQuota: nil,
            packages: [
                PackageItem(
                    packageType: "later_pack",
                    packageStatus: "active",
                    startAt: "2026-04-01T00:00:00Z",
                    expiresAt: "2099-05-10T23:59:00Z"
                ),
                PackageItem(
                    packageType: "sooner_pack",
                    packageStatus: "active",
                    startAt: "2026-04-01T00:00:00Z",
                    expiresAt: "2099-04-30T23:59:00Z"
                ),
            ]
        )

        let selected = CodexMonitorStore.selectDisplayPackage(from: package.packages)

        #expect(selected?.packageType == "sooner_pack")
    }

    @Test
    func buildsPackageSummaryItemsForActivePackages() {
        let package = PackagePayload(
            totalQuota: nil,
            weeklyQuota: nil,
            packages: [
                PackageItem(
                    packageType: "codex_pro",
                    packageStatus: "active",
                    startAt: "2099-04-01T00:00:00Z",
                    expiresAt: "2099-04-30T23:59:00Z"
                ),
                PackageItem(
                    packageType: "expired_pack",
                    packageStatus: "expired",
                    startAt: "2025-01-01T00:00:00Z",
                    expiresAt: "2025-01-31T23:59:00Z"
                ),
            ]
        )

        let items = CodexMonitorStore.buildPackageSummaryItems(package: package)

        #expect(items.count == 1)
        #expect(items.first?.title == "codex pro")
    }

    @Test
    func decodesAGIPackagePayload() throws {
        let json = """
        {
          "code": 200,
          "message": "获取成功",
          "data": {
            "packages": [
              {
                "pkg_id": "69e6c40f32b046b97b22ee05",
                "order_class": "Pro",
                "level": 4,
                "byte_total": 8000000,
                "byte_remaining": 7981726,
                "byte_used": 18274,
                "day": 93,
                "expireTime": "2026-07-23T00:25:51.494Z",
                "createTime": "2026-04-21T00:25:51.494Z",
                "reason": "stripe支付",
                "type": "pay"
              }
            ],
            "summary": {
              "pkg_id": "69e6c40f32b046b97b22ee05",
              "total_packages": 1,
              "total_byte": 8000000,
              "remaining_byte": 7981726,
              "used_byte": 18274,
              "highest_level": 4,
              "user_type": "Pro",
              "latest_expire_time": "2026-07-23T00:25:51.494Z"
            }
          }
        }
        """

        let decoded = try JSONDecoder().decode(AGIPackageEnvelope.self, from: Data(json.utf8))

        #expect(decoded.code == 200)
        #expect(decoded.data?.packages?.count == 1)
        #expect(decoded.data?.summary?.userType == "Pro")
        #expect(decoded.data?.summary?.remainingByte?.doubleValue == 7_981_726)
    }

    @Test
    func resolvesAGIProgressAndPackageItems() {
        let packages = [
            AGIPackageItem(
                pkgID: "pkg_1",
                orderClass: "Pro",
                level: 4,
                byteTotal: .int(8_000_000),
                byteRemaining: .int(7_981_726),
                byteUsed: .int(18_274),
                day: 93,
                expireTime: "2099-07-23T00:25:51.494Z",
                createTime: "2099-04-21T00:25:51.494Z",
                reason: "stripe支付",
                type: "pay"
            ),
        ]

        let percent = CodexMonitorStore.resolveUsedPercentage(total: 8_000_000, used: 18_274)
        let items = CodexMonitorStore.buildAGIPackageSummaryItems(packages: packages)

        #expect(percent != nil)
        #expect((percent ?? 0) > 0)
        #expect(items.count == 1)
        #expect(items.first?.title == "Pro Lv4")
    }
}
