-- 10xkey.lua (ya keylist.lua) — TESLA 10X GAMING VIP Keys
-- Expiry date YYYY-MM-DD format mein
-- max_devices: kitne phones pe chalegi
-- script: kaunsa lua payload load karega (GitHub repo me file ka naam, .lua ke bina)

return {
    -- ═══════════════════════════════════════════════
    -- VIP KEYS (Full access, long duration)
    -- ═══════════════════════════════════════════════
    ["VIP-3MONTH-A01"] = {
        type = "VIP",
        expiry = "2026-03-31",
        valid = true,
        max_devices = 1,
        script = "payload",
        note = "3 month single device"
    },
    ["VIP-6MONTH-B02"] = {
        type = "VIP",
        expiry = "2027-06-30",
        valid = true,
        max_devices = 2,
        script = "payload",
        note = "6 month 2 devices"
    },
    ["VIP-1YEAR-C03"] = {
        type = "VIP",
        expiry = "2027-12-31",
        valid = true,
        max_devices = 3,
        script = "payload",
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
        script = "payload65",
        note = "Testing key"
    },
    ["VIP-TEST-002"] = {
        type = "DEMO",
        expiry = "2027-12-31",
        valid = true,
        max_devices = 3,
        script = "payload44",
        note = "Testing multi-device"
    },

    -- ═══════════════════════════════════════════════
    -- CUSTOMER KEYS (Rename kar sakte ho)
    -- ═══════════════════════════════════════════════
    ["CUSTOMER-Django-01"] = {
        type = "VIP",
        expiry = "2026-12-31",
        valid = true,
        max_devices = 1,
        script = "payload",
        note = "Customer: Rahul"
    },
    ["CUSTOMER-AMIT-02"] = {
        type = "VIP",
        expiry = "2026-12-31",
        valid = true,
        max_devices = 2,
        script = "payload",
        note = "Customer: Amit"
    },

    -- ═══════════════════════════════════════════════
    -- NAYA LUA KEYS (example — jab tum alag lua add karo)
    -- ═══════════════════════════════════════════════
    -- Jab GitHub pe payload_sniper.lua daalo, tab aisi key banao:
    -- ["SNIPER-VIP-001"] = {
    --     type = "VIP",
    --     expiry = "2027-12-31",
    --     valid = true,
    --     max_devices = 2,
    --     script = "payload_sniper",
    --     note = "Sniper-only lua"
    -- },

    -- ═══════════════════════════════════════════════
    -- BLOCKED KEYS (For testing revoke)
    -- ═══════════════════════════════════════════════
    ["BLOCKED-OLD-KEY"] = {
        type = "BLOCKED",
        expiry = "2027-12-31",
        valid = false,
        max_devices = 0,
        script = "payload",
        note = "Revoked"
    },
}
