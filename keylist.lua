-- keylist.lua — 10X GAMING VIP Keys
-- Expiry date YYYY-MM-DD format mein
-- max_devices: kitne phones pe chalegi

return {
    -- ═══════════════════════════════════════════════
    -- VIP KEYS (Full access, long duration)
    -- ═══════════════════════════════════════════════
    ["VIP-3MONTH-A01"] = {
        type = "VIP",
        expiry = "2027-03-31",
        valid = true,
        max_devices = 1,
        note = "3 month single device"
    },
    ["VIP-6MONTH-B02"] = {
        type = "VIP",
        expiry = "2027-06-30",
        valid = true,
        max_devices = 2,
        note = "6 month 2 devices"
    },
    ["VIP-1YEAR-C03"] = {
        type = "VIP",
        expiry = "2027-12-31",
        valid = true,
        max_devices = 3,
        note = "1 year 3 devices"
    },

    -- ═══════════════════════════════════════════════
    -- TEST / DEMO KEYS
    -- ═══════════════════════════════════════════════
    ["VIP-TEST-001"] = {
        type = "DEMO",
        expiry = "2027-12-31",
        valid = true,
        max_devices = 1,
        note = "Testing key"
    },
    ["VIP-TEST-002"] = {
        type = "DEMO",
        expiry = "2027-12-31",
        valid = true,
        max_devices = 3,
        note = "Testing multi-device"
    },

    -- ═══════════════════════════════════════════════
    -- CUSTOMER KEYS (Rename kar sakte ho)
    -- ═══════════════════════════════════════════════
    ["CUSTOMER-RAHUL-01"] = {
        type = "VIP",
        expiry = "2026-12-31",
        valid = true,
        max_devices = 1,
        note = "Customer: Rahul"
    },
    ["CUSTOMER-AMIT-02"] = {
        type = "VIP",
        expiry = "2026-12-31",
        valid = true,
        max_devices = 2,
        note = "Customer: Amit"
    },

    -- ═══════════════════════════════════════════════
    -- BLOCKED KEYS (For testing revoke)
    -- ═══════════════════════════════════════════════
    ["BLOCKED-OLD-KEY"] = {
        type = "BLOCKED",
        expiry = "2027-12-31",
        valid = false,
        max_devices = 0,
        note = "Revoked"
    },
}
