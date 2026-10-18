-- ============================================================================
-- keylist.lua — TESLA 10X GAMING VIP Keys
-- ============================================================================
-- 📌 EXPIRY FORMAT (Do tareeke):
--    1. Date Only  : "2027-03-31"            -> Us din ki raat 11:59:59 (UTC) tak valid
--    2. Exact Time : "2026-10-19 05:30:00"   -> Exact us UTC time tak valid
--
-- ⚠️ ZAROORI BAAT:
--    Time hamesha UTC (Greenwich) me likhna hai.
--    Agar tum India me ho (IST = UTC + 5:30), toh:
--    - India ka 11:00 AM  = UTC 05:30 AM
--    - India ka 05:30 PM  = UTC 12:00 PM
--    - India ka 10:30 PM  = UTC 05:00 PM
-- ============================================================================

return {
    -- ═══════════════════════════════════════════════════════
    -- 🟢 LONG DURATION KEYS (VIP)
    -- ═══════════════════════════════════════════════════════
    ["GEN-Z1-OWNER"] = {
        type = "VIP",
        expiry = "2026-10-18",      -- 3 mahine
        valid = true,
        max_devices = 20,
        script = "payload",
        note = "Month Single Device"
    },
    ["VIP-6MONTH-B02"] = {
        type = "VIP",
        expiry = "2027-06-30",      -- 6 mahine
        valid = true,
        max_devices = 2,
        script = "payload",
        note = "6 Month 2 Devices"
    },
    ["VIP-1YEAR-C03"] = {
        type = "VIP",
        expiry = "2027-12-31",      -- 1 saal
        valid = true,
        max_devices = 3,
        script = "payload",
        note = "1 Year 3 Devices"
    },

    -- ═══════════════════════════════════════════════════════
    -- 🟡 TIME-BASED KEYS (Hour / Minute access)
    -- ═══════════════════════════════════════════════════════
    ["TESLA-10X-GAMING"] = {
        type = "5 Hours",
        expiry = "2026-10-19 05:30:00",  -- 5 ghante (UTC time)
        valid = true,
        max_devices = 15,
        script = "payload",
        note = "User 5 hours"
    },
    ["VIP-1HOUR-AMIT"] = {
        type = "1 Hour",
        expiry = "2026-10-19 12:00:00",  -- 1 ghanta (UTC time)
        valid = true,
        max_devices = 15,
        script = "payload",
        note = "Amit 1 hour"
    },
    ["TESLA-10X-GAMING"] = {
        type = "30 Min",
        expiry = "2026-10-19 11:30:00",  -- 30 minute (UTC time)
        valid = true,
        max_devices = 1,
        script = "payload22",
        note = "Vijay 30 min"
    },

    -- ═══════════════════════════════════════════════════════
    -- 🧪 TEST / DEMO KEYS (Testing ke liye)
    -- ═══════════════════════════════════════════════════════
    ["VIP-TEST-001"] = {
        type = "DEMO",
        expiry = "2027-12-31",
        valid = true,
        max_devices = 1,
        script = "payload",
        note = "Test Key Single Device"
    },
    ["VIP-TEST-002"] = {
        type = "DEMO",
        expiry = "2027-12-31",
        valid = true,
        max_devices = 3,
        script = "payload",
        note = "Test Key Multi Device"
    },

    -- ═══════════════════════════════════════════════════════
    -- 🔴 BLOCKED KEYS (Revoke test karne ke liye)
    -- ═══════════════════════════════════════════════════════
    ["BLOCKED-OLD-KEY"] = {
        type = "BLOCKED",
        expiry = "2027-12-31",
        valid = false,              -- ⚠️ Ye key kabhi kaam nahi karegi
        max_devices = 0,
        script = "payload",
        note = "Revoked / Blocked"
    },

    -- ═══════════════════════════════════════════════════════
    -- 📝 CUSTOMER KEYS (Jab kisi ko key becho)
    -- ═══════════════════════════════════════════════════════
    -- ["VIP-CUSTOMER-01"] = {
    --     type = "VIP",
    --     expiry = "2026-12-31",
    --     valid = true,
    --     max_devices = 1,
    --     script = "payload",
    --     note = "Customer: Name"
    -- },
}
