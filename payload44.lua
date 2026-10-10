-- ============================================================================
-- BRPlayerCharacterBase.lua
-- Fixed build: ESP Toggle Sync + Master Kill Switch
-- + ESP VIP (Marker) from ASHI X SKINS LEAK
-- + IPAD VIEW
-- + On/Off toggles for Aimbot, ESP Box, HP Bar, Enemy Counter
-- + SETTINGS MENU UI (NEXT9MODZZ) - On/Off buttons in-game
-- + FIXED: All ESP features now properly respect Off state
-- + NEW: Wallhack (Green/Red) with On/Off toggle
-- + NEW: AIMBOT RANGE 280° with On/Off toggle  -- ✅ FIXED & ENHANCED
-- + NEW: Full Bypass Layers from @INDIAN_ROHIT_YT
-- + FIXED: Wallhack now properly cleans up when turned OFF
-- + FIXED: Aimbot 280° proper cone math + stronger aim assist
-- + FIXED: ESP Health Bar OFF state - NOW FULLY HIDDEN WHEN DISABLED ✅✅✅
-- + FIXED: Native HP Bar marks properly removed on toggle OFF ✅✅✅
-- + FIXED: RedBoxOverlay complete cleanup ✅✅✅
-- + OPTIMIZED: Reduced redundant checks, better cache usage, less GC pressure
-- ============================================================================

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local KismetMathLibrary = import("KismetMathLibrary")
local GameplayStatics = import("GameplayStatics")
local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

local EXPIRY_TIMESTAMP = os.time({ year = 2027, month = 10, day = 11, hour = 15, min = 59, sec = 59 })

-- ✅ OPTIMIZATION: Cache commonly used values
local math_random = math.random
local math_floor = math.floor
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_deg = math.deg
local math_rad = math.rad
local math_atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local os_clock = os.clock
local os_time = os.time
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

local function FormatTimeRemaining(sec)
    if sec <= 0 then return "0d 0h 0m 0s" end
    local days = math_floor(sec / 86400); sec = sec % 86400
    local hours = math_floor(sec / 3600); sec = sec % 3600
    local minutes = math_floor(sec / 60)
    local seconds = sec % 60
    return string_format("%dd %dh %dm %ds", days, hours, minutes, seconds)
end

function CheckExpiration()
    local now = os_time()
    local remaining = EXPIRY_TIMESTAMP - now
    if remaining <= 0 then
        _G._MOD_EXPIRED = true
        return false
    end
    _G._MOD_EXPIRED = false
    _G._MOD_REMAINING_SECONDS = remaining
    return true
end

local function ShowExpiryPopup(expired)
    pcall(function()
        local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"]
            or require("client.slua.logic.common.logic_common_msg_box")
        local function onClick() end
        if expired then
            local expiresAt = os.date("!%Y-%m-%d %H:%M:%S UTC", EXPIRY_TIMESTAMP)
            Msg.Show(4, "MOD EXPIRED",
                "THIS MOD HAS EXPIRED.\n\nEXPIRED ON: " .. expiresAt .. "\n\nTEXT Me to buy @INDIAN_ROHIT_YT", onClick)
        else
            local remaining = _G._MOD_REMAINING_SECONDS or (EXPIRY_TIMESTAMP - os_time())
            local formatted = FormatTimeRemaining(remaining)
            local expiresAt = os.date("!%Y-%m-%d %H:%M:%S UTC", EXPIRY_TIMESTAMP)
            Msg.Show(4, "NOTIFICATION",
                "MOD VALIDITY: " .. formatted .. "\nEXPIRES AT: " .. expiresAt .. "\n\nFOR RENEWAL DM @INDIAN_ROHIT_YT", onClick)
        end
    end)
end

function _G.TryShowWelcome()
    if _G.WelcomeShown then return end
    if not CheckExpiration() then
        ShowExpiryPopup(true)
        return
    end
    ShowExpiryPopup(false)
    _G.WelcomeShown = true
end

-- ============================================================================
-- FEATURE TOGGLES
-- ============================================================================
_G.AK_Features = {
    { id = "ESP_HP",        name = "ESP Health Bar",  val = 1, type = "toggle" },
    { id = "ESP_BOX",       name = "ESP Box",         val = 1, type = "toggle" },
    { id = "ESP_MAP",       name = "Mini Map ESP",    val = 1, type = "toggle" },
    { id = "AIMBOT",        name = "Aimbot",          val = 1, type = "toggle" },
    { id = "AIMBOT_280",    name = "AIMBOT RANGE 280°", val = 0, type = "toggle" },
    { id = "ENEMY_COUNTER", name = "Enemy Counter",   val = 1, type = "toggle" },
    { id = "ESP_VIP_MARKER",name = "ESP VIP Marker",  val = 0, type = "toggle" },
    { id = "IPAD_VIEW",     name = "IPad View",       val = 0, type = "toggle" },
    { id = "WALLHACK_GR",   name = "Wallhack (Green/Red)", val = 0, type = "toggle" },
    { id = "WALLHACK_AIM",  name = "Wallhack + Aimbot", val = 0, type = "toggle" },
}

-- ✅ OPTIMIZATION: Cache feature lookups
local _AK_FeatureCache = {}
function _G.AK_GetVal(featureId)
    local cached = _AK_FeatureCache[featureId]
    if cached ~= nil then return cached end
    for _, feature in ipairs(_G.AK_Features) do
        if feature.id == featureId then
            _AK_FeatureCache[featureId] = feature.val
            return feature.val
        end
    end
    return 0
end

function _G.AK_SetVal(featureId, val)
    for _, feature in ipairs(_G.AK_Features) do
        if feature.id == featureId then
            feature.val = val
            _AK_FeatureCache[featureId] = val  -- ✅ Update cache
            _G.AK_SyncFeatureToConfig(featureId, val)
            return true
        end
    end
    return false
end

function _G.AK_SyncFeatureToConfig(featureId, val)
    if not _G.LexusConfig then return end
    local bVal = (val == 1)
    local map = {
        ESP_HP         = "Esp9_HP",
        ESP_BOX        = "Esp9_Line",
        ESP_MAP        = "EspLoai9",
        ESP_VIP_MARKER = "ESP_VIP_MARKER",
        ENEMY_COUNTER  = "Esp9_Count",
        IPAD_VIEW      = "IpadView",
        AIMBOT         = "AimbotEnabled",
        AIMBOT_280     = "Aimbot280Enabled",
        WALLHACK_GR    = "WallhackGreenRed",
        WALLHACK_AIM   = "WallhackAimbot",
    }
    local cfgKey = map[featureId]
    if cfgKey and _G.LexusConfig[cfgKey] ~= nil then
        _G.LexusConfig[cfgKey] = bVal
    end
    if featureId == "ESP_BOX" then
        _G.LexusConfig.Esp9_Skeleton = bVal
    end
    if featureId == "ESP_HP" then
        _G.LexusConfig.Esp9_HP = bVal
    end
end

function _G.AK_IsESPActive()
    if _G._MOD_EXPIRED then return false end
    if not _G._WHA_BYPASS_ACTIVE then return false end
    return (_G.AK_GetVal("ESP_HP") == 1) or (_G.AK_GetVal("ESP_BOX") == 1)
        or (_G.AK_GetVal("ESP_MAP") == 1) or (_G.AK_GetVal("ESP_VIP_MARKER") == 1)
        or (_G.AK_GetVal("ENEMY_COUNTER") == 1) or (_G.AK_GetVal("WALLHACK_GR") == 1)
        or (_G.AK_GetVal("WALLHACK_AIM") == 1)
end

function _G.AK_IsWallhackActive()
    if _G._MOD_EXPIRED then return false end
    if not _G._WHA_BYPASS_ACTIVE then return false end
    return (_G.AK_GetVal("WALLHACK_GR") == 1) or (_G.AK_GetVal("WALLHACK_AIM") == 1)
end

function _G.AK_IsAimbotActive()
    if _G._MOD_EXPIRED then return false end
    if not _G._WHA_BYPASS_ACTIVE then return false end
    return (_G.AK_GetVal("AIMBOT") == 1) or (_G.AK_GetVal("AIMBOT_280") == 1)
end

-- ============================================================================
-- LEVIATHAN CONFIG TABLES
-- ============================================================================
_G.LexusConfig = _G.LexusConfig or {
    FakeHWID          = true,
    SkinBypass        = true,
    VehicleSkin       = true,
    PetSkin           = true,
    DeadBoxSkin       = true,
    CharacterAvatar   = true,
    ColorBody         = true,
    KillCounterUI     = true,
    ESPCanvas         = true,
    ModMenuInjection  = true,
    ConfigPersistence = true,
    EmulatorDetect    = true,
    JNIAntiCheat      = true,
    CRCBypass         = true,
    RacingAntiCheat   = true,
    ChargeJump        = true,
    OperationalStats  = true,
    EspLoai9          = false,
    Esp9_Count        = true,
    Esp9_Name         = true,
    Esp9_HP           = true,
    Esp9_Team         = true,
    Esp9_Weapon       = true,
    Esp9_Distance     = true,
    Esp9_Line         = true,
    Esp9_Skeleton     = false,
    IpadView          = false,
    IpadViewFOV       = 120,
    AimbotEnabled     = true,
    Aimbot280Enabled  = false,
    AimbotRange       = 280,
    WallhackGreenRed  = false,
    WallhackAimbot    = false,
}

_G.LexusState = _G.LexusState or {
    LoopToken         = 0,
    NativeESPReady    = false,
    EnemyMarks        = {},
    CustomTextData    = {},
    ESPWidgets        = {},
    ESPWidgetPtrs     = {},
    LastConfigSaveStr = "",
    ModConfigLoaded   = false,
    SkinWasApplied    = false,
    TDSkinLoopStarted = false,
    WallhackStarted   = false,
    Aimbot280Started  = false,
}

-- ============================================================================
-- LEVIATHAN INSTALLER
-- ============================================================================
function _G.InstallAllLeviathanLayers()
    if _G._LeviathanInstalled then return end
    _G._LeviathanInstalled = true

    local nop      = function() end
    local retTrue  = function() return true end
    local retFalse = function() return false end
    local retZero  = function() return 0 end
    local retEmpty = function() return {} end

    local function safeRequire(p)
        local ok, m = pcall(require, p)
        return ok and m or nil
    end

    -- ── STATIC STUBS ───────────────────────────────────────────────────────
    pcall(function()
        local M = safeRequire("GameLua.Mod.BaseMod.Client.Security.OperationalStatsSubsystem")
        if M then for k, v in pairs(M) do if type(v) == "function" then M[k] = nop end end end
        if _G.OperationalStatsSubsystem then
            for k, v in pairs(_G.OperationalStatsSubsystem) do if type(v) == "function" then _G.OperationalStatsSubsystem[k] = nop end end
        end
    end)

    pcall(function()
        if _G.JNI then
            _G.JNI.CheckIntegrity = retTrue
            _G.JNI.VerifySignature = retTrue
            _G.JNI.ScanMemory = retEmpty
            _G.JNI.IsRooted = retFalse
            _G.JNI.IsEmulator = retFalse
        end
        if _G.JNIAntiCheat then
            for k, v in pairs(_G.JNIAntiCheat) do if type(v) == "function" then _G.JNIAntiCheat[k] = nop end end
        end
    end)

    pcall(function()
        if _G.TssSdk then
            _G.TssSdk.GetModuleHash = function() return "82918E1FE1BE4186CFD2F1286951B2A0" end
            _G.TssSdk.VerifyModule = retTrue
            _G.TssSdk.ScanProcess = retEmpty
            _G.TssSdk.CheckKernel = function() return true, { status = "verified", tampered = false } end
            _G.TssSdk.VerifyBoot = function() return true, { locked = true, verified = true } end
            _G.TssSdk.IsRooted = retFalse
            _G.TssSdk.GetFileMD5 = function() return "7b1c7b5608da3083097816106fc331f9" end
            _G.TssSdk.VerifyFileSignature = retTrue
            _G.TssSdk.OnRecvData = nop
        end
    end)

    pcall(function()
        if _G.Client then _G.Client.IsInReplayState = retFalse end
        local uiCommon = safeRequire("client.slua.logic.common.logic_common_utils")
        if uiCommon and uiCommon.IsInReplayState then uiCommon.IsInReplayState = retFalse end
    end)

    pcall(function()
        if _G.NetManager then
            _G.NetManager.isLogMsgAfterLogin = retFalse
            _G.NetManager.logMsgMap = {}
        end
    end)

    pcall(function()
        if _G.Kernel32 then
            _G.Kernel32.IsDebuggerPresent = retFalse
            _G.Kernel32.CheckRemoteDebuggerPresent = retFalse
        end
    end)

    pcall(function()
        local ED = safeRequire("client.logic.login.emulator_detect")
        if ED then ED.IsEmulator = retFalse; ED.Detect = retFalse; ED.ReportEmulator = nop end
        if _G.EmulatorDetect then
            _G.EmulatorDetect.IsEmulator = retFalse
            _G.EmulatorDetect.Detect = retFalse
        end
    end)

    pcall(function()
        if _G.CRCChecker then
            _G.CRCChecker.Check = retTrue
            _G.CRCChecker.Verify = retTrue
            _G.CRCChecker.Calculate = retZero
        end
        if _G.CRC32 then _G.CRC32 = retZero end
    end)

    pcall(function()
        local SN = safeRequire("GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature")
        if SN then
            SN.ClientRPC_SyncBanID = nop
            SN.ClientRPC_StrongTips = nop
            SN.ClientRPC_NormalTips = nop
            SN.ClientRPC_NotifyBan = nop
            SN.ClientRPC_NotifyPunish = nop
            SN.ClientRPC_NotifyIllegalProgram = nop
            SN.Notify = nop
        end
    end)

    pcall(function()
        local RAC = safeRequire("GameLua.Mod.Racing.Client.Security.RacingAntiCheatLogic")
        if RAC then
            for k, v in pairs(RAC) do
                if type(v) == "function" and (k:find("Report") or k:find("Check") or k:find("Verify") or k:find("Detect")) then
                    RAC[k] = nop
                end
            end
        end
    end)

    pcall(function()
        local H = safeRequire("GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem")
        if H then
            for _, fn in ipairs({"_OnHawkSync","_OnHawkReportSuccess","_StartExitGameTimer","_OnRecvInspectorBroadcastCount","SendReportTLog","ReportCheat"}) do
                if H[fn] then H[fn] = nop end
            end
            H.CanInspectorBroadcast = retFalse
        end
    end)

    pcall(function()
        local B = safeRequire("client.slua.logic.ban.ClientBanLogic")
        if B then
            B.OnSyncBanInfo = nop
            B.OnVoiceBanNotify = nop
            B.OnRealTimeVoiceBanNotify = nop
            B.OnVoiceBanSuccess = nop
            B.OnSyncMicSuspicious = nop
            B.OnSyncMicPreFilter = nop
            B.OnNotifyWarningTips = nop
            B.ReqBanInfo = nop
        end
    end)

    pcall(function()
        for _, p in ipairs({
            "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"
        }) do
            local M = safeRequire(p)
            if M then
                for k, v in pairs(M) do
                    if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload")) then
                        M[k] = nop
                    end
                end
            end
        end
    end)

    pcall(function()
        local T = safeRequire("client.slua.config.tlog.tlog_report_utils")
        if T then T.ReportTLogEvent = nop; T.FlushEvents = nop; T.Send = nop end
        local TR = safeRequire("client.slua.logic.report.ToolReportUtil")
        if TR then TR.IsReleaseVersion = retFalse; TR.IsWhite = retFalse; TR.GetReportSwitch = retFalse end
    end)

    pcall(function()
        local M = safeRequire("GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem")
        if M then for k, v in pairs(M) do if type(v) == "function" then M[k] = nop end end end
    end)

    pcall(function()
        local C = _G.ChargeJumpComponent
        if C then C.ReportCharge = nop; C.ValidateCharge = retTrue end
    end)

    pcall(function()
        if _G.LocalMain then
            _G.LocalMain.ReportError = nop
            _G.LocalMain.SendCrash = nop
        end
        if slua_GameFrontendHUD and slua_GameFrontendHUD.HiggsBosonComponent then
            slua_GameFrontendHUD.HiggsBosonComponent.bMHActive = false
        end
    end)

    pcall(function()
        local L = safeRequire("client.logic.battle.logic_complaint")
        if L then
            L.SendComplaintReq = nop
            L.Submit = nop
            L.ReportPlayer = nop
            L.ShowComplaint = nop
            L.ShowHandle = nop
        end
        local U = safeRequire("client.slua.logic.complaint.ui_complaint")
        if U then
            for k, v in pairs(U) do
                if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Submit")) then
                    U[k] = nop
                end
            end
        end
    end)

    pcall(function()
        local SubMgr = safeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({
                "DSHawkEyePatrolSubsystem",
                "CDSIllegalTeamUpSystem",
                "CGetOnEnemyVehicleSystem"
            }) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" then sub[k] = nop end end end
            end
        end
    end)

    pcall(function()
        for _, p in ipairs({
            "GameLua.Mod.BaseMod.DS.Security.DSCreditTLogSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSGlueHiaSystem",
            "GameLua.Mod.BaseMod.DS.Security.DSMaliciousTeammateDetectionSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSQuickReportMaliciousTeammate",
            "GameLua.Mod.BaseMod.DS.Security.DSPVSSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSSecurityNotifySystem",
            "GameLua.Mod.BaseMod.DS.Security.KillFrequencyLimiter",
            "GameLua.Mod.BaseMod.DS.Security.DSChatPlayerSubsystem",
            "GameLua.Mod.BaseMod.DS.Security.DSBanLogic",
            "GameLua.Mod.BaseMod.DS.Security.DSAITLogSubsystem"
        }) do
            local M = safeRequire(p)
            if M then for k, v in pairs(M) do if type(v) == "function" then M[k] = nop end end end
        end
    end)

    pcall(function()
        local L = safeRequire("client.logic.login.login_module")
        if L then L.ReportLogin = nop; L.ReportDevice = nop end
    end)

    pcall(function()
        if _G.Gokuba then for k, v in pairs(_G.Gokuba) do if type(v) == "function" then _G.Gokuba[k] = nop end end end
        if _G.RealTimeBan then
            _G.RealTimeBan.Check = retFalse
            _G.RealTimeBan.Report = nop
            _G.RealTimeBan.IsBanned = retFalse
        end
        if _G.BanSystem then
            _G.BanSystem.CheckBanStatus = retFalse
            _G.BanSystem.GetBanTime = retZero
            _G.BanSystem.IsBanForever = retFalse
        end
    end)

    -- ── FAKE HWID ──────────────────────────────────────────────────────────
    pcall(function()
        local function genHex(len)
            local chars = "0123456789ABCDEF"
            local s = ""
            for i = 1, len do
                s = s .. chars:sub(math_random(1, #chars), math_random(1, #chars))
            end
            return s
        end

        local FAKE_HWID = genHex(32)
        _G._FakeHWID_String = FAKE_HWID

        local KSL = import("KismetSystemLibrary")
        if KSL and KSL.GetDeviceId then
            local orig = KSL.GetDeviceId
            KSL.GetDeviceId = function(self, ...)
                if _G.LexusConfig.FakeHWID and not _G._MOD_EXPIRED then return FAKE_HWID end
                return orig(self, ...)
            end
        end

        local SI = import("SystemInfo")
        if SI then
            if SI.GetDeviceID then
                local orig = SI.GetDeviceID
                SI.GetDeviceID = function()
                    if _G.LexusConfig.FakeHWID and not _G._MOD_EXPIRED then return FAKE_HWID end
                    return orig()
                end
            end
            if SI.GetUniqueDeviceId then
                local orig = SI.GetUniqueDeviceId
                SI.GetUniqueDeviceId = function()
                    if _G.LexusConfig.FakeHWID and not _G._MOD_EXPIRED then return FAKE_HWID end
                    return orig()
                end
            end
        end

        _G._FakeHWID_Hooked = true
    end)

    -- ── KILL COUNTER UI ────────────────────────────────────────────────────
    pcall(function()
        if _G.KillCounterUISubsystem then
            for k, v in pairs(_G.KillCounterUISubsystem) do
                if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Verify")) then
                    _G.KillCounterUISubsystem[k] = nop
                end
            end
        end
        if _G.LogicKillCounter then
            for k, v in pairs(_G.LogicKillCounter) do
                if type(v) == "function" and (k:find("Report") or k:find("Send")) then
                    _G.LogicKillCounter[k] = nop
                end
            end
        end
        if _G.KillInfo then
            _G.KillInfo.ReportKill = nop
            _G.KillInfo.ReportDeath = nop
        end
        if _G.SwitchWeaponSlotMode2 then
            local orig = _G.SwitchWeaponSlotMode2
            _G.SwitchWeaponSlotMode2 = function(...)
                if _G.LexusConfig.KillCounterUI and not _G._MOD_EXPIRED then return end
                return orig(...)
            end
        end
        _G.KCUISystemHacked2 = true
        _G.KCLogicHacked2 = true
        _G.KillInfoCounterHacked = true
        _G.SlotBaseHacked = true
    end)

    -- ── SKIN SUITE ─────────────────────────────────────────────────────────
    local SkinSuite = _G.SkinSuite or {}
    function SkinSuite.get_skin_id(weaponId) return weaponId end
    function SkinSuite.get_muzzleid(weaponId) return weaponId end
    function SkinSuite.get_forgripid(weaponId) return weaponId end
    function SkinSuite.get_magazinesid(weaponId) return weaponId end
    function SkinSuite.get_scopeid(weaponId) return weaponId end
    function SkinSuite.get_stockid(weaponId) return weaponId end

    function SkinSuite.apply_attachment(synData, attachmentId)
        pcall(function()
            if synData and synData.Set then synData:Set(attachmentId, attachmentId) end
        end)
    end

    function SkinSuite.ApplyWeaponSkins(synData)
        if not _G.LexusConfig.SkinBypass or _G._MOD_EXPIRED then return end
        pcall(function()
            if synData and synData.Get and synData.Set then
                local currentSkin = synData:Get(7)
                if currentSkin then synData:Set(7, currentSkin) end
            end
        end)
    end

    function SkinSuite.ApplyVehicleSkins(vehicleAvatar, skinId)
        if not _G.LexusConfig.VehicleSkin or _G._MOD_EXPIRED then return end
        pcall(function()
            if vehicleAvatar and vehicleAvatar.ChangeItemAvatar then
                vehicleAvatar:ChangeItemAvatar(skinId)
            end
        end)
    end

    function SkinSuite.HandlePetLogic(logicPet, petId)
        if not _G.LexusConfig.PetSkin or _G._MOD_EXPIRED then return end
        pcall(function()
            if logicPet then
                if logicPet.SetCurPetID then logicPet:SetCurPetID(petId) end
                if logicPet.EquipPet then logicPet:EquipPet(petId) end
            end
        end)
    end

    function SkinSuite.DeadBox_TemperRequest(deadBoxComp, itemId)
        if not _G.LexusConfig.DeadBoxSkin or _G._MOD_EXPIRED then return end
        pcall(function()
            if deadBoxComp then
                if deadBoxComp.PreChangeItemAvatar then deadBoxComp:PreChangeItemAvatar(itemId) end
                if deadBoxComp.SyncChangeItemAvatar then deadBoxComp:SyncChangeItemAvatar(itemId) end
            end
        end)
    end

    function SkinSuite.equip_character_avatar(slotSyncData, slotId, itemId)
        if not _G.LexusConfig.CharacterAvatar or _G._MOD_EXPIRED then return end
        pcall(function()
            if slotSyncData and slotSyncData.Set then slotSyncData:Set(slotId, itemId) end
            if _G.OnRep_BodySlotStateChanged then _G.OnRep_BodySlotStateChanged() end
        end)
    end

    function SkinSuite.ForceRefreshSkinMaps()
        pcall(function()
            if _G.WeaponSkinMap then for k in pairs(_G.WeaponSkinMap) do _G.WeaponSkinMap[k] = nil end end
            if _G.VehicleSkinMap then for k in pairs(_G.VehicleSkinMap) do _G.VehicleSkinMap[k] = nil end end
            if _G.OutfitMap then for k in pairs(_G.OutfitMap) do _G.OutfitMap[k] = nil end end
        end)
    end

    function SkinSuite.ApplyColorBodyNew(targetMesh, color)
        if not _G.LexusConfig.ColorBody or _G._MOD_EXPIRED then return end
        pcall(function()
            if not targetMesh then return end
            local KSL = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if KSL and world then
                KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
                KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
            end
            if targetMesh.SetDrawDyeing then targetMesh:SetDrawDyeing(true) end
            if targetMesh.SetDrawIdeaOutline then targetMesh:SetDrawIdeaOutline(true) end
            if color and targetMesh.SetVisibleDyeingColor then targetMesh:SetVisibleDyeingColor(color) end
        end)
    end

    function SkinSuite.UndoColorBodyNew(targetMesh)
        pcall(function()
            if not targetMesh then return end
            if targetMesh.SetDrawDyeing then targetMesh:SetDrawDyeing(false) end
            if targetMesh.SetDrawIdeaOutline then targetMesh:SetDrawIdeaOutline(false) end
        end)
    end

    _G.SkinSuite = SkinSuite

    -- ── ESP CANVAS ─────────────────────────────────────────────────────────
    pcall(function()
        local PMM = _G.PlayerMapMarker
        if PMM and PMM.InitESPCanvas then
            local orig = PMM.InitESPCanvas
            PMM.InitESPCanvas = function(self, ...)
                local res = orig(self, ...)
                if _G.LexusConfig.ESPCanvas and not _G._MOD_EXPIRED then
                    pcall(function()
                        local widgets = self.ESPWidgets or _G.LexusState.ESPWidgets
                        if widgets then
                            local canvas0 = self.CanvasPanel_0
                            local canvas42 = self.CanvasPanel_42
                            if canvas0 and canvas0.AddChild then
                                for _, w in pairs(widgets) do if w then canvas0:AddChild(w) end end
                            end
                            if canvas42 and canvas42.AddChild then
                                for _, w in pairs(widgets) do if w then canvas42:AddChild(w) end end
                            end
                        end
                    end)
                end
                return res
            end
        end
    end)

    pcall(function()
        local gameplayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local cfg = gameplayTools.GetCurrentConfig("ScreenMarkConfig")
        if cfg then
            local baseCfg = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99,
                MaxShowDistance = 6000000,
                bBindOutScreen = true,
                bBindBlocked = true,
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true,
                Priority = 2,
            }
            cfg[1006] = cfg[1006] or baseCfg
            cfg[1007] = cfg[1007] or baseCfg
            cfg[8888] = cfg[8888] or baseCfg
            cfg[9999] = cfg[9999] or baseCfg
        end
    end)

    _G.LexusState.NativeESPReady = true

    -- ── MOD MENU ───────────────────────────────────────────────────────────
    pcall(function()
        if _G.LocUtil and _G.LocUtil.AddLocText then
            _G.LocUtil.AddLocText("Lexus_Menu_Title", "INDIAN ROHIT YT ELITE")
        end
        if _G.SettingPageDefine then
            _G.SettingPageDefine.LexusMenuPage = {
                id = "LexusMenu",
                title = "INDIAN ROHIT YT ELITE",
                catalog = "LexusCatalog",
            }
        end
        if _G.UIManager and _G.UIManager.ShowUI then
            local orig = _G.UIManager.ShowUI
            _G.UIManager.ShowUI = function(self, name, ...)
                if name == "LexusMenuPage" then
                    if _G.ShowLexusVIPMenu then _G.ShowLexusVIPMenu() end
                    return
                end
                return orig(self, name, ...)
            end
        end
    end)
    _G.ModMenuInitialized = true
    _G.LexusMenuAlreadyShown = false

    -- ── CONFIG PERSISTENCE ─────────────────────────────────────────────────
    pcall(function()
        local FileHelper = import("FFileHelper")
        if FileHelper and FileHelper.LoadStringFromFile then
            local ok, data = pcall(FileHelper.LoadStringFromFile, "LeviathanCheats.txt")
            if ok and data and #data > 0 then
                for pair in string.gmatch(data, "[^;]+") do
                    local k, v = pair:match("([^=]+)=(.+)")
                    if k and v and _G.LexusConfig[k] ~= nil then
                        if v == "true" then _G.LexusConfig[k] = true
                        elseif v == "false" then _G.LexusConfig[k] = false
                        else _G.LexusConfig[k] = v end
                    end
                end
                _G.LexusState.LastConfigSaveStr = data
            end
        end
    end)

    function _G.SaveLexusConfig()
        pcall(function()
            local FileHelper = import("FFileHelper")
            if not FileHelper or not FileHelper.SaveStringToFile then return end
            local parts = {}
            for k, v in pairs(_G.LexusConfig) do
                table_insert(parts, k .. "=" .. tostring(v))
            end
            local data = table.concat(parts, ";")
            if data ~= _G.LexusState.LastConfigSaveStr then
                FileHelper.SaveStringToFile(data, "LeviathanCheats.txt", "utf-8", true)
                _G.LexusState.LastConfigSaveStr = data
            end
        end)
    end
    _G.LexusState.ModConfigLoaded = true

    -- ── CONSOLE INJECTION ──────────────────────────────────────────────────
    _G.ConsoleNewWallReady = function()
        if not CheckExpiration() then return end
        local world = slua.getWorld()
        local KSL = import("KismetSystemLibrary")
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
    end

    -- ── SKIN LOOP ──────────────────────────────────────────────────────────
    function _G.StartTDSkinLoop()
        if _G.LexusState.TDSkinLoopStarted then return end
        _G.LexusState.TDSkinLoopStarted = true
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not slua.isValid(pc) then return end
            pc:AddGameTimer(15.0, true, function()
                if not _G.LexusConfig.SkinBypass or _G._MOD_EXPIRED then return end
                pcall(function()
                    if not _G.LexusState.SkinWasApplied then
                        _G.SkinSuite.ForceRefreshSkinMaps()
                        _G.LexusState.SkinWasApplied = true
                    end
                end)
            end)
        end)
    end

    print("✅ Leviathan Extended Bypass Layers Installed (runtime)")
end

-- ============================================================================
-- ULTIMATE WALLHACK BYPASS
-- ============================================================================
local function InstallUltimateWallhackBypass()
    if _G.__ULTIMATE_WH_BYPASS_LOADED then return end

    local nop = function() end
    local retTrue = function() return true end
    local retFalse = function() return false end
    local retZero = function() return 0 end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    pcall(function()
        local FPSP = import("PrimitiveSceneProxy")
        if FPSP then
            local origGetViewRelevance = FPSP.GetViewRelevance
            FPSP.GetViewRelevance = function(self, View)
                local VR = origGetViewRelevance(self, View)
                if isBypassActive() and VR then
                    VR.bRenderCustomDepth = false
                    VR.bUsesSceneDepth = false
                end
                return VR
            end
            local origDepthPriority = FPSP.GetDepthPriorityGroup
            FPSP.GetDepthPriorityGroup = function(self)
                if not isBypassActive() then return origDepthPriority(self) end
                return 0
            end
        end
    end)

    pcall(function()
        local UMesh = import("MeshComponent")
        if UMesh then
            UMesh.GetRenderCustomDepth = function(self)
                if not isBypassActive() then return UMesh.__origGRCD(self) end return false end
            UMesh.__origGRCD = UMesh.GetRenderCustomDepth
            UMesh.IsRenderedOnCustomDepth = function(self)
                if not isBypassActive() then return UMesh.__origIRCD(self) end return false end
            UMesh.__origIRCD = UMesh.IsRenderedOnCustomDepth
            UMesh.GetCustomDepthStencilValue = function(self)
                if not isBypassActive() then return UMesh.__origGCDSV(self) end return 0 end
            UMesh.__origGCDSV = UMesh.GetCustomDepthStencilValue
            UMesh.ShouldRender = function(self)
                if not isBypassActive() then return UMesh.__origSR(self) end return true end
            UMesh.__origSR = UMesh.ShouldRender
            UMesh.IsVisible = function(self)
                if not isBypassActive() then return UMesh.__origIV(self) end return true end
            UMesh.__origIV = UMesh.IsVisible
        end
        local UPrim = import("PrimitiveComponent")
        if UPrim then
            for _, fn in ipairs({"IsRenderedOnCustomDepth","GetRenderCustomDepth","GetCustomDepthStencilValue","GetCustomDepthStencilWriteMask","GetVisibleFlag"}) do
                local orig = UPrim[fn]
                UPrim["__orig_"..fn] = orig
                UPrim[fn] = function(self, ...)
                    if not isBypassActive() then return orig(self, ...) end
                    if fn == "GetVisibleFlag" then return true end
                    if fn == "GetCustomDepthStencilValue" then return 0 end
                    return false
                end
            end
        end
    end)

    pcall(function()
        local FRHI = import("RHICommandList")
        if FRHI and FRHI.SetDepthState then
            local origSetDepth = FRHI.SetDepthState
            FRHI.SetDepthState = function(self, State)
                if isBypassActive() and type(State) == "table" and State.DepthEnable ~= nil then
                    State.DepthEnable = true
                end
                return origSetDepth(self, State)
            end
        end
    end)

    pcall(function()
        local UGVC = import("GameViewportClient")
        if UGVC and UGVC.Draw then
            local origDraw = UGVC.Draw
            UGVC.Draw = function(self, ...)
                origDraw(self, ...)
                if isBypassActive() and _G.AK_DrawWallhackOverlay then
                    pcall(_G.AK_DrawWallhackOverlay)
                end
            end
        end
    end)

    pcall(function()
        local UMat = import("Material")
        local UMatInst = import("MaterialInstance")
        local UMatDyn = import("MaterialInstanceDynamic")

        if UMat then
            UMat.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMat.__origDDT(self) end return false end
            UMat.__origDDT = UMat.GetDisableDepthTest
            UMat.GetBlendMode = function(self)
                if not isBypassActive() then return UMat.__origBM(self) end return 0 end
            UMat.__origBM = UMat.GetBlendMode
            UMat.GetMaterialHash = function(self)
                if not isBypassActive() then return UMat.__origHash(self) end return "FAKE_HASH" end
            UMat.__origHash = UMat.GetMaterialHash
            UMat.VerifyMaterial = function(self)
                if not isBypassActive() then return UMat.__origVM(self) end return true end
            UMat.__origVM = UMat.VerifyMaterial
        end
        if UMatInst then
            UMatInst.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMatInst.__origDDT(self) end return false end
            UMatInst.__origDDT = UMatInst.GetDisableDepthTest
            UMatInst.GetBlendMode = function(self)
                if not isBypassActive() then return UMatInst.__origBM(self) end return 0 end
            UMatInst.__origBM = UMatInst.GetBlendMode
            UMatInst.GetBaseMaterial = function(self)
                if not isBypassActive() then return UMatInst.__origBM2(self) end return nil end
            UMatInst.__origBM2 = UMatInst.GetBaseMaterial
        end
        if UMatDyn then
            local oldGetVec = UMatDyn.K2_GetVectorParameterValue
            UMatDyn.K2_GetVectorParameterValue = function(self, name)
                if not isBypassActive() then return oldGetVec(self, name) end
                local n = tostring(name or "")
                if n:find("Color") or n:find("Emissive") or n:find("Tint") then
                    return {R=255,G=255,B=255,A=255}
                end
                return oldGetVec(self, name)
            end
            local oldGetScal = UMatDyn.K2_GetScalarParameterValue
            UMatDyn.K2_GetScalarParameterValue = function(self, name)
                if not isBypassActive() then return oldGetScal(self, name) end
                if tostring(name):find("Emissive") then return 0.0 end
                return oldGetScal(self, name)
            end
        end
    end)

    pcall(function()
        local UObj = import("Object")
        if UObj and UObj.GetObjectsOfClass then
            local oldGet = UObj.GetObjectsOfClass
            UObj.GetObjectsOfClass = function(Class, IncludeDerived)
                if isBypassActive() and Class and tostring(Class):find("MaterialInstanceDynamic") then
                    return {}
                end
                return oldGet(Class, IncludeDerived)
            end
        end
    end)

    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local kc = SubMgr:Get("ClientKernelCheckSubsystem")
            if kc and not kc.__akhooked then
                local origIKC = kc.IsKernelClean
                kc.IsKernelClean = function(self)
                    if not isBypassActive() then return origIKC(self) end
                    return true, { code = 0, message = "clean" }
                end
                local origGKV = kc.GetKernelVersion
                kc.GetKernelVersion = function(self)
                    if not isBypassActive() then return origGKV(self) end
                    return "5.4.0-generic"
                end
                kc.__akhooked = true
            end
            local mg = SubMgr:Get("ClientMemoryGuardSubsystem")
            if mg and not mg.__akhooked then
                local origIMC = mg.IsMemoryClean
                mg.IsMemoryClean = function(self)
                    if not isBypassActive() then return origIMC(self) end
                    return true, {code=0}
                end
                local origSR = mg.ScanResult
                mg.ScanResult = function(self)
                    if not isBypassActive() then return origSR(self) end
                    return "clean"
                end
                mg.__akhooked = true
            end
        end
    end)

    local ourMarkGroups = {1006, 9999}

    pcall(function()
        local MarkMgr = InGameMarkTools and InGameMarkTools.ScreenMarkManager
        if MarkMgr then
            if MarkMgr.GetAllActiveMarks then
                local orig = MarkMgr.GetAllActiveMarks
                MarkMgr.GetAllActiveMarks = function(self, ...)
                    local marks = orig(self, ...)
                    if not isBypassActive() or not marks then return marks end
                    local filtered = {}
                    for _, m in ipairs(marks) do
                        if m.MarkGroupID and not table.contains(ourMarkGroups, m.MarkGroupID) then
                            table_insert(filtered, m)
                        end
                    end
                    return filtered
                end
            end
            if MarkMgr.GetMarkCount then
                local orig = MarkMgr.GetMarkCount
                MarkMgr.GetMarkCount = function(self, ...)
                    local count = orig(self, ...)
                    if isBypassActive() then count = math.max(0, count - #ourMarkGroups) end
                    return count
                end
            end
            if MarkMgr.GetMarksByGroup then
                local orig = MarkMgr.GetMarksByGroup
                MarkMgr.GetMarksByGroup = function(self, groupId)
                    if isBypassActive() and table.contains(ourMarkGroups, groupId) then return {} end
                    return orig(self, groupId)
                end
            end
            if MarkMgr.OnAddMark then MarkMgr.OnAddMark = nop end
            if MarkMgr.OnRemoveMark then MarkMgr.OnRemoveMark = nop end
        end
    end)

    pcall(function()
        if _G.Replay_IsEnemyFrameUIExisted then
            local orig = _G.Replay_IsEnemyFrameUIExisted
            _G.Replay_IsEnemyFrameUIExisted = function(...)
                if isBypassActive() then return false end
                return orig(...)
            end
        end
        if _G.Replay_CreateEnemyFrameUI then
            local orig = _G.Replay_CreateEnemyFrameUI
            _G.Replay_CreateEnemyFrameUI = function(...)
                if isBypassActive() then
                    local backup = _G.ReportEnemyFrameUI or nop
                    _G.ReportEnemyFrameUI = nop
                    local res = orig(...)
                    _G.ReportEnemyFrameUI = backup
                    return res
                end
                return orig(...)
            end
        end
    end)

    pcall(function()
        local Actor = import("Actor")
        if Actor then
            local mt = getmetatable(Actor) or {}
            local oldIndex = mt.__index or function() end
            mt.__index = function(t, k)
                if isBypassActive() then
                    local sk = tostring(k)
                    if sk:find("ESP") or sk:find("bHasAKNative") or sk:find("NativeDistMark") or
                       sk:find("_wh_") or sk:find("WH_") then
                        return nil
                    end
                end
                return oldIndex(t, k)
            end
            setmetatable(Actor, mt)
        end
    end)

    pcall(function()
        local UIHelper = import("UIHelper") or _G.UIHelper
        if UIHelper and UIHelper.GetAllWidgetsOfClass then
            UIHelper.GetAllWidgetsOfClass = function(...) return {} end
        end
        local UUserWidget = import("UserWidget")
        if UUserWidget and UUserWidget.AddToViewport then
            local orig = UUserWidget.AddToViewport
            UUserWidget.AddToViewport = function(self, ...)
                if isBypassActive() and self.ESPWidget then return end
                return orig(self, ...)
            end
        end
    end)

    pcall(function()
        local espReports = {
            "ReportESPBox","ReportESPHealth","ReportMiniMapESP","ReportEnemyFrameUI",
            "ReportMarkCreated","ReportMarkDestroyed","MarkSuspiciousESP",
            "OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
            "ReportWallhackESP","SendESPData","UploadESPInfo"
        }
        for _, fn in ipairs(espReports) do
            if _G[fn] then _G[fn] = nop end
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" and mod[fn] and type(mod[fn]) == "function" then
                    mod[fn] = nop
                end
            end
        end
    end)

    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname and tostring(pname):lower():match("esp") then return nil end
                return orig(pname, ...)
            end
        end
        if _G.SendRPC then
            local orig = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if isBypassActive() and rpcName and tostring(rpcName):lower():match("esp") then return end
                return orig(rpcName, ...)
            end
        end
    end)

    _G.__ULTIMATE_WH_BYPASS_LOADED = true
    print("✅ Ultimate Wallhack + ESP Detection Bypass Installed")
end

InstallUltimateWallhackBypass()

-- ============================================================================
-- AIMBOT & RECOIL BYPASS
-- ============================================================================
local function InstallAimbotRecoilBypass()
    if _G.__AIMBOT_BYPASS_LOADED then return end

    local nop = function() end
    local retTrue = function() return true end
    local retFalse = function() return false end
    local retZero = function() return 0 end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    pcall(function()
        local ShootWeaponEntity = import("ShootWeaponEntity") or import("ShootWeaponEntityComp")
        if ShootWeaponEntity then
            local mt = getmetatable(ShootWeaponEntity) or {}
            local oldIndex = mt.__index or function(t, k) return rawget(t, k) end
            mt.__index = function(self, key)
                local k = tostring(key)
                if isBypassActive() then
                    if k == "RecoilKickADS" or k == "GameDeviationFactor" or k == "GameDeviationAccuracy" then
                        return 1.0
                    elseif k == "AutoAimingConfig" then
                        local orig = oldIndex(self, key)
                        if type(orig) == "table" then
                            local fakeConfig = {}
                            for range, data in pairs(orig) do
                                fakeConfig[range] = {}
                                for cKey, cVal in pairs(data) do
                                    if type(cVal) == "number" then
                                        fakeConfig[range][cKey] = 1.0
                                    else
                                        fakeConfig[range][cKey] = cVal
                                    end
                                end
                            end
                            return fakeConfig
                        end
                        return orig
                    end
                end
                return oldIndex(self, key)
            end
            mt.__newindex = function(self, key, value)
                rawset(self, key, value)
            end
            setmetatable(ShootWeaponEntity, mt)
        end
    end)

    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local aimSub = SubMgr:Get("ClientAimTrackingSubsystem")
            if aimSub then
                local origGetAim = aimSub.GetAimData
                aimSub.GetAimData = function(self)
                    if not isBypassActive() then return origGetAim(self) end
                    return {
                        accuracy = math_random(40, 60),
                        headshotRate = math_random(10, 25),
                        trackingTime = math_random(100, 300),
                        aimLockCount = 0
                    }
                end
                for _, fn in ipairs({"ReportAimData","SendAimStats","UploadAimInfo"}) do
                    if aimSub[fn] then aimSub[fn] = nop end
                end
            end
        end
    end)

    pcall(function()
        local PlayerController = import("PlayerController")
        if PlayerController then
            local origAddYaw = PlayerController.AddYawInput
            PlayerController.AddYawInput = function(self, Val)
                if isBypassActive() and self == slua_GameFrontendHUD:GetPlayerController() then
                    Val = Val + (math_random() - 0.5) * 0.5
                end
                return origAddYaw(self, Val)
            end
            local origAddPitch = PlayerController.AddPitchInput
            PlayerController.AddPitchInput = function(self, Val)
                if isBypassActive() and self == slua_GameFrontendHUD:GetPlayerController() then
                    Val = Val + (math_random() - 0.5) * 0.5
                end
                return origAddPitch(self, Val)
            end
        end
        local GS = import("GameplayStatics")
        if GS and GS.IsInputKeyDown then
            local origKeyDown = GS.IsInputKeyDown
            GS.IsInputKeyDown = function(self, Key)
                if isBypassActive() and Key == "LeftMouseButton" then
                    if math_random() < 0.1 then return false end
                end
                return origKeyDown(self, Key)
            end
        end
    end)

    pcall(function()
        local ShootVerify = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if ShootVerify then
            local origVerify = ShootVerify.VerifyShot
            ShootVerify.VerifyShot = function(self, ...)
                if not isBypassActive() then return origVerify(self, ...) end
                local args = {...}
                if args[1] and type(args[1]) == "table" and args[1].hitLocation then
                    args[1].hitLocation.X = args[1].hitLocation.X + (math_random()-0.5)*2
                    args[1].hitLocation.Y = args[1].hitLocation.Y + (math_random()-0.5)*2
                end
                return true
            end
        end
    end)

    pcall(function()
        local Actor = import("Actor")
        if Actor and Actor.GetBoneName then
            local origGetBone = Actor.GetBoneName
            Actor.GetBoneName = function(self, index)
                local name = origGetBone(self, index)
                if isBypassActive() and tostring(name):find("neck") then
                    local rand = math_random(1,3)
                    if rand == 1 then return "head_01"
                    elseif rand == 2 then return "spine_02"
                    end
                end
                return name
            end
        end
    end)

    pcall(function()
        local aimReports = {
            "ReportAimFlow","ReportRecoil","ReportAimData","SendAimStats",
            "UploadAimInfo","ReportHeadshotRate","ReportAccuracy","ReportFireRate",
            "ReportRecoilKick","ReportAutoAim","ReportWeaponModification",
            "ReportWeaponStats","ReportShootVerifyFail","ReportHitIntegrity",
            "OnAimAssistDetected","OnRecoilAnomaly","OnFireRateAnomaly",
            "ClientAimTrackingUpdate","ServerAimValidation"
        }
        for _, fn in ipairs(aimReports) do
            if _G[fn] then _G[fn] = nop end
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" and mod[fn] and type(mod[fn]) == "function" then
                    mod[fn] = nop
                end
            end
        end
    end)

    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname and (tostring(pname):lower():match("aim") or tostring(pname):lower():match("recoil") or tostring(pname):lower():match("shoot")) then
                    return nil
                end
                return orig(pname, ...)
            end
        end
        if _G.SendRPC then
            local orig = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if isBypassActive() and rpcName and (tostring(rpcName):lower():match("aim") or tostring(rpcName):lower():match("recoil") or tostring(rpcName):lower():match("shoot")) then
                    return
                end
                return orig(rpcName, ...)
            end
        end
    end)

    _G.__AIMBOT_BYPASS_LOADED = true
    print("✅ Global Aimbot & Recoil Bypass Installed")
end

InstallAimbotRecoilBypass()

-- ============================================================================
-- ADVANCED DETECTION BYPASS
-- ============================================================================
local function InstallAdvancedDetectionBypass()
    if _G.__ADVANCED_BYPASS_LOADED then return end

    local nop = function() end
    local retTrue = function() return true end
    local retFalse = function() return false end
    local retZero = function() return 0 end
    local retEmpty = function() return {} end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    pcall(function()
        local ShootWeaponEntity = import("ShootWeaponEntity") or import("ShootWeaponEntityComp")
        if ShootWeaponEntity and ShootWeaponEntity.Fire then
            local origFire = ShootWeaponEntity.Fire
            ShootWeaponEntity.Fire = function(self, ...)
                return origFire(self, ...)
            end
        end
        local Actor = import("Actor")
        if Actor and Actor.TakeDamage then
            local origTakeDamage = Actor.TakeDamage
            Actor.TakeDamage = function(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
                if isBypassActive() and DamageEvent and DamageEvent.HitInfo then
                    if DamageEvent.HitInfo.BoneName and tostring(DamageEvent.HitInfo.BoneName):find("head") then
                        if math_random() < 0.3 then
                            DamageEvent.HitInfo.BoneName = "neck_01"
                        end
                    end
                    DamageEvent.HitInfo.Location = {
                        X = DamageEvent.HitInfo.Location.X + (math_random()-0.5)*2,
                        Y = DamageEvent.HitInfo.Location.Y + (math_random()-0.5)*2,
                        Z = DamageEvent.HitInfo.Location.Z + (math_random()-0.5)*2
                    }
                end
                return origTakeDamage(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
            end
        end
    end)

    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname then
                    local p = tostring(pname):lower()
                    if p:match("position") or p:match("location") or p:match("coord") or
                       p:match("playerpos") or p:match("move") or p:match("teleport") then
                        return nil
                    end
                end
                return orig(pname, ...)
            end
        end
        if _G.SendRPC then
            local orig = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if isBypassActive() and rpcName then
                    local r = tostring(rpcName):lower()
                    if r:match("position") or r:match("location") or r:match("coord") then
                        return
                    end
                end
                return orig(rpcName, ...)
            end
        end
    end)

    local matchStats = { totalShots = 0, totalHits = 0, headshots = 0, kills = 0 }
    pcall(function()
        local Weapon = import("ShootWeaponEntity") or import("ShootWeaponEntityComp")
        if Weapon and Weapon.Fire then
            local origFire = Weapon.Fire
            Weapon.Fire = function(self, ...)
                if isBypassActive() then matchStats.totalShots = matchStats.totalShots + 1 end
                return origFire(self, ...)
            end
        end
        local Actor = import("Actor")
        if Actor and Actor.TakeDamage then
            local origTakeDamage2 = Actor.TakeDamage
            Actor.TakeDamage = function(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
                if isBypassActive() and EventInstigator == slua_GameFrontendHUD:GetPlayerController() then
                    matchStats.totalHits = matchStats.totalHits + 1
                    if DamageEvent and DamageEvent.HitInfo and DamageEvent.HitInfo.BoneName and
                       tostring(DamageEvent.HitInfo.BoneName):find("head") then
                        matchStats.headshots = matchStats.headshots + 1
                    end
                    if self:IsDead() then matchStats.kills = matchStats.kills + 1 end
                end
                return origTakeDamage2(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
            end
        end
        local GameReportUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GameReportUtils and GameReportUtils.ReportGameResult then
            local origReport = GameReportUtils.ReportGameResult
            GameReportUtils.ReportGameResult = function(self, data)
                if isBypassActive() and data then
                    local shots = math.max(matchStats.totalShots, 1)
                    data.accuracy = math.min(0.65, 0.35 + math_random()*0.15)
                    data.headshotRate = math.min(0.30, 0.10 + math_random()*0.10)
                    data.totalKills = matchStats.kills
                    data.totalShots = shots
                    data.totalHits = math_floor(shots * data.accuracy)
                end
                return origReport(self, data)
            end
        end
        local ShowResult = package.loaded["GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.BattleResultShowResultLogic"]
        if ShowResult and ShowResult.ReceiveData then
            local origReceive = ShowResult.ReceiveData
            ShowResult.ReceiveData = function(self, resultData)
                if isBypassActive() and resultData then
                    resultData.Accuracy = math_random(35,50)/100
                    resultData.HeadShotRate = math_random(10,20)/100
                end
                return origReceive(self, resultData)
            end
        end
    end)

    pcall(function()
        if rawget(_G, "IsDebuggerPresent") then _G.IsDebuggerPresent = retFalse end
        local ok, Kernel32 = pcall(import, "Kernel32")
        if ok and Kernel32 then
            Kernel32.IsDebuggerPresent = retFalse
            Kernel32.CheckRemoteDebuggerPresent = retFalse
        end
        if _G.TssSdk then
            _G.TssSdk.GetModuleHash = function() return "82918E1FE1BE4186CFD2F1286951B2A0" end
            _G.TssSdk.VerifyModule = retTrue
            _G.TssSdk.ScanProcess = retEmpty
        end
        local FMemory = import("FMemory")
        if FMemory and FMemory.Memcpy then
            local origMemcpy = FMemory.Memcpy
            FMemory.Memcpy = function(dest, src, count)
                if isBypassActive() then return end
                return origMemcpy(dest, src, count)
            end
        end
    end)

    pcall(function()
        local FileHelper = import("FFileHelper")
        if FileHelper then
            if FileHelper.GetFileSize then
                local orig = FileHelper.GetFileSize
                FileHelper.GetFileSize = function(path)
                    local size = orig(path)
                    if isBypassActive() and path and tostring(path):lower():match(".pak") then
                        return 2000000000
                    end
                    return size
                end
            end
            if FileHelper.SaveStringToFile then
                local origSave = FileHelper.SaveStringToFile
                FileHelper.SaveStringToFile = function(str, path, ...)
                    if isBypassActive() and path and tostring(path):lower():match(".pak") then
                        return true
                    end
                    return origSave(str, path, ...)
                end
            end
        end
        local ok, PakSubsystem = pcall(require, "GameLua.GameCore.Module.Subsystem.PakFileSubsystem")
        if ok and PakSubsystem then
            PakSubsystem.CheckPakIntegrity = nop
            PakSubsystem.ReportPakMismatch = nop
        end
    end)

    pcall(function()
        local CharacterMovement = import("CharacterMovementComponent")
        if CharacterMovement then
            local origGetMaxSpeed = CharacterMovement.GetMaxSpeed
            CharacterMovement.GetMaxSpeed = function(self)
                local speed = origGetMaxSpeed(self)
                if isBypassActive() then return 600.0 end
                return speed
            end
            local origGetMaxAcceleration = CharacterMovement.GetMaxAcceleration
            CharacterMovement.GetMaxAcceleration = function(self)
                local acc = origGetMaxAcceleration(self)
                if isBypassActive() then return 2048.0 end
                return acc
            end
        end
    end)

    pcall(function()
        local UMat = import("Material")
        local UMatInst = import("MaterialInstance")
        if UMat then
            UMat.GetShaderMap = function(self) return nil end
            UMat.GetShaderPlatform = function(self) return 0 end
        end
        if UMatInst then
            UMatInst.GetShaderMap = function(self) return nil end
        end
        local FPakFile = import("FPakFile") or import("FPakPlatformFile")
        if FPakFile then
            FPakFile.GetPakEntries = function(...) return {} end
            FPakFile.GetPakFolders = function(...) return {} end
            FPakFile.FindFileInPakFiles = function(...) return false end
        end
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname and tostring(pname):lower():match("stat") then return nil end
                return orig(pname, ...)
            end
        end
        local SSMgr = import("ScreenshotManager")
        if SSMgr then
            SSMgr.RequestScreenshot = function(...) return false end
            SSMgr.HasPendingScreenshot = function(...) return false end
        end
    end)

    _G.__ADVANCED_BYPASS_LOADED = true
    print("✅ Advanced Detection Bypass Installed")
end

InstallAdvancedDetectionBypass()

-- ============================================================================
-- DEVICE ID / BAN BYPASS
-- ============================================================================
local function InstallDeviceBanBypass()
    if _G.__DEVICE_BAN_BYPASS_LOADED then return end

    local nop = function() end
    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    local function generateFakeId(length)
        local chars = "0123456789ABCDEF"
        local id = ""
        for i = 1, length do
            id = id .. chars:sub(math_random(1, #chars), math_random(1, #chars))
        end
        return id
    end
    local fakeDeviceID = generateFakeId(32)
    local fakeAndroidID = generateFakeId(16)
    local fakeMac = string_format("%02X:%02X:%02X:%02X:%02X:%02X",
        math_random(0,255), math_random(0,255), math_random(0,255),
        math_random(0,255), math_random(0,255), math_random(0,255))
    local fakeIMEI = "35" .. math_random(100000, 999999) .. math_random(100000, 999999)

    pcall(function()
        local SystemInfo = import("SystemInfo")
        if SystemInfo then
            if SystemInfo.GetDeviceID or SystemInfo.GetUniqueDeviceId then
                local orig = SystemInfo.GetDeviceID or SystemInfo.GetUniqueDeviceId
                if orig then
                    if SystemInfo.GetDeviceID then
                        SystemInfo.GetDeviceID = function()
                            if isBypassActive() then return fakeDeviceID end
                            return orig()
                        end
                    end
                    if SystemInfo.GetUniqueDeviceId then
                        SystemInfo.GetUniqueDeviceId = function()
                            if isBypassActive() then return fakeDeviceID end
                            return orig()
                        end
                    end
                end
            end
            if SystemInfo.GetMacAddress then
                local orig = SystemInfo.GetMacAddress
                SystemInfo.GetMacAddress = function()
                    if isBypassActive() then return fakeMac end
                    return orig()
                end
            end
            if SystemInfo.GetAndroidId then
                local orig = SystemInfo.GetAndroidId
                SystemInfo.GetAndroidId = function()
                    if isBypassActive() then return fakeAndroidID end
                    return orig()
                end
            end
            if SystemInfo.GetIMEI then
                local orig = SystemInfo.GetIMEI
                SystemInfo.GetIMEI = function()
                    if isBypassActive() then return fakeIMEI end
                    return orig()
                end
            end
            if SystemInfo.GetDeviceName then
                local orig = SystemInfo.GetDeviceName
                SystemInfo.GetDeviceName = function()
                    if isBypassActive() then return "Galaxy S21 Ultra 5G" end
                    return orig()
                end
            end
        end
    end)

    pcall(function()
        local Build = import("Build")
        if Build then
            local props = {"Fingerprint","Serial","Hardware","Brand","Model","Manufacturer","Product","Device","Board"}
            for _, prop in ipairs(props) do
                local orig = Build[prop]
                if orig then
                    Build[prop] = function()
                        if isBypassActive() then
                            if prop == "Fingerprint" then return "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys" end
                            if prop == "Serial" then return "R5CT1234567" end
                            if prop == "Hardware" then return "oriole" end
                            if prop == "Brand" then return "google" end
                            if prop == "Model" then return "Pixel 6" end
                            if prop == "Manufacturer" then return "Google" end
                            if prop == "Product" then return "oriole" end
                            if prop == "Device" then return "oriole" end
                            if prop == "Board" then return "gs101" end
                        end
                        return orig()
                    end
                end
            end
            if Build.VERSION and Build.VERSION.SDK_INT then
                local orig = Build.VERSION.SDK_INT
                Build.VERSION.SDK_INT = function()
                    if isBypassActive() then return 33 end
                    return orig()
                end
            end
        end
    end)

    pcall(function()
        local TssSdk = _G.TssSdk
        if TssSdk then
            if TssSdk.GetDeviceInfo then
                local orig = TssSdk.GetDeviceInfo
                TssSdk.GetDeviceInfo = function()
                    if not isBypassActive() then return orig() end
                    return {
                        deviceId = fakeDeviceID,
                        androidId = fakeAndroidID,
                        mac = fakeMac,
                        imei = fakeIMEI,
                        model = "Pixel 6",
                        brand = "google",
                        sdkInt = 33,
                        fingerprint = "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys"
                    }
                end
            end
            if TssSdk.GetFingerprint then
                local orig = TssSdk.GetFingerprint
                TssSdk.GetFingerprint = function()
                    if isBypassActive() then return "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys" end
                    return orig()
                end
            end
            if TssSdk.GetClientID then
                local orig = TssSdk.GetClientID
                TssSdk.GetClientID = function()
                    if isBypassActive() then return fakeDeviceID end
                    return orig()
                end
            end
        end
    end)

    pcall(function()
        if _G.DeviceID then _G.DeviceID = fakeDeviceID end
        if _G.AndroidID then _G.AndroidID = fakeAndroidID end
        if _G.MacAddress then _G.MacAddress = fakeMac end
        if _G.IMEI then _G.IMEI = fakeIMEI end
    end)

    _G.__DEVICE_BAN_BYPASS_LOADED = true
    print("✅ Device ID / Ban Bypass Installed")
end

InstallDeviceBanBypass()

-- ============================================================================
-- WALLHACK (GREEN/RED) SYSTEM  -- ✅ FULLY FIXED
-- ============================================================================
local WallhackSystem = {}
WallhackSystem.Active = false
WallhackSystem.Timer = nil
WallhackSystem.ProcessedPawns = {}
WallhackSystem.TickCount = 0
WallhackSystem.ConsoleReady = false

local WH_TICK_INTERVAL = 0.3
local WH_MAX_PAWNS_PER_TICK = 25
local WH_RESET_PROCESSED_EVERY = 6
local WH_AVATAR_SLOTS = {0,1,2,3,4,5,6,7}

local WH_COLORS = {
    vis = nil,
    occ = nil,
    bVis = nil,
    bOcc = nil,
}

function WallhackSystem.InitColors()
    pcall(function()
        local LinearColor = import("LinearColor")
        if LinearColor then
            WH_COLORS.vis = LinearColor(0, 255, 0, 255)
            WH_COLORS.occ = LinearColor(255, 0, 0, 255)
            WH_COLORS.bVis = LinearColor(0, 200, 0, 255)
            WH_COLORS.bOcc = LinearColor(200, 0, 0, 255)
        end
    end)
    return WH_COLORS.vis ~= nil
end

function WallhackSystem.SetupConsole()
    if WallhackSystem.ConsoleReady then return end
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        WallhackSystem.ConsoleReady = true
    end)
end

function WallhackSystem.ApplyToMesh(mesh, visColor, occColor)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visColor)
        mesh:SetIdeaOutlineOcclusionColor(occColor)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

function WallhackSystem.RemoveFromMesh(mesh)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetDrawDyeingMode(0)
        mesh:SetDrawIdeaOutline(false)
        mesh:SetIdeaOutlineNew(false)
        mesh:SetDrawHighlight(false)
        mesh:SetHighlightCanBeOccluded(true)
        mesh:SetRenderCustomDepth(false)
        mesh:SetCustomDepthStencilValue(0)
        mesh:SetIdeaOutlineOcclusionHighlight(false)
        mesh:SetIdeaOverrideOutlineAndOcclusion(false)
    end)
end

function WallhackSystem.Tick()
    pcall(function()
        local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
        local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
        if not (whGR or whAim) then return end
        if _G._MOD_EXPIRED then return end
        if not _G._WHA_BYPASS_ACTIVE then return end

        local localPawn = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPawn) then return end

        WallhackSystem.SetupConsole()
        if not WH_COLORS.vis then
            if not WallhackSystem.InitColors() then return end
        end

        WallhackSystem.TickCount = WallhackSystem.TickCount + 1
        if WallhackSystem.TickCount % WH_RESET_PROCESSED_EVERY == 0 then
            WallhackSystem.ProcessedPawns = {}
        end

        local myTeamId = localPawn.TeamID or 0
        local allPawns = Game:GetAllPlayerPawns() or {}
        local processedCount = 0

        for _, pawn in pairs(allPawns) do
            if processedCount >= WH_MAX_PAWNS_PER_TICK then break end
            if not slua.isValid(pawn) or pawn == localPawn then goto continue end
            if pawn.PlayerKey and WallhackSystem.ProcessedPawns[pawn.PlayerKey] then goto continue end

            local isEnemy = (pawn.TeamID and pawn.TeamID ~= myTeamId)
            if not isEnemy then goto continue end

            local isAlive = false
            pcall(function()
                if pawn.Health and pawn.Health > 0 then isAlive = true
                elseif type(pawn.IsDead) == "function" then isAlive = not pawn:IsDead()
                else isAlive = true end
            end)
            if not isAlive then goto continue end

            local isAI = false
            pcall(function() isAI = Game:IsAI(pawn) end)

            local vis = isAI and WH_COLORS.bVis or WH_COLORS.vis
            local occ = isAI and WH_COLORS.bOcc or WH_COLORS.occ

            pcall(function()
                if slua.isValid(pawn.Mesh) then
                    WallhackSystem.ApplyToMesh(pawn.Mesh, vis, occ)
                end
                local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                if avatarComp and avatarComp.GetMeshCompBySlot then
                    for _, slot in ipairs(WH_AVATAR_SLOTS) do
                        local mesh = avatarComp:GetMeshCompBySlot(slot)
                        if slua.isValid(mesh) then
                            WallhackSystem.ApplyToMesh(mesh, vis, occ)
                        end
                    end
                end
                pcall(function()
                    local SkeletalMeshComponent = import("SkeletalMeshComponent")
                    if SkeletalMeshComponent then
                        local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                        if skComps then
                            for i = 0, skComps:Num() - 1 do
                                local comp = skComps:Get(i)
                                if slua.isValid(comp) and comp ~= pawn.Mesh then
                                    WallhackSystem.ApplyToMesh(comp, vis, occ)
                                end
                            end
                        end
                    end
                end)
                pcall(function()
                    local StaticMeshComponent = import("StaticMeshComponent")
                    if StaticMeshComponent then
                        local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                        if stComps then
                            for i = 0, stComps:Num() - 1 do
                                local comp = stComps:Get(i)
                                if slua.isValid(comp) then
                                    WallhackSystem.ApplyToMesh(comp, vis, occ)
                                end
                            end
                        end
                    end
                end)
                local weapon = pawn:GetCurrentWeapon()
                if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                    WallhackSystem.ApplyToMesh(weapon.Mesh, vis, occ)
                end
            end)

            if pawn.PlayerKey then
                WallhackSystem.ProcessedPawns[pawn.PlayerKey] = true
            end
            processedCount = processedCount + 1

            ::continue::
        end
    end)
end

function WallhackSystem.Start()
    if WallhackSystem.Active then return true end
    local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
    local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
    if not (whGR or whAim) then return false end
    if _G._MOD_EXPIRED then return false end
    if not _G._WHA_BYPASS_ACTIVE then return false end
    if not WallhackSystem.InitColors() then
        print("[WALLHACK] Failed to init colors")
        return false
    end

    WallhackSystem.SetupConsole()

    if WallhackSystem.Timer then
        pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WallhackSystem.Timer) end end)
        WallhackSystem.Timer = nil
    end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        WallhackSystem.Timer = pc:AddGameTimer(WH_TICK_INTERVAL, true, function()
            pcall(WallhackSystem.Tick)
        end)
        WallhackSystem.Active = true
        print("[WALLHACK] ✅ Started (Green/Red)")
        return true
    end

    if _G.Game and _G.Game.AddGameTimer then
        WallhackSystem.Timer = _G.Game:AddGameTimer(WH_TICK_INTERVAL, true, function()
            pcall(WallhackSystem.Tick)
        end)
        WallhackSystem.Active = true
        print("[WALLHACK] ✅ Started (Game timer)")
        return true
    end

    print("[WALLHACK] ❌ Could not start timer")
    return false
end

function WallhackSystem.Stop()
    WallhackSystem.Active = false
    if WallhackSystem.Timer then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(WallhackSystem.Timer) end
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then pcall(function() pc:RemoveGameTimer(WallhackSystem.Timer) end) end
        end)
        WallhackSystem.Timer = nil
    end

    -- Remove wallhack from all pawns
    pcall(function()
        local allPawns = Game:GetAllPlayerPawns() or {}
        for _, pawn in pairs(allPawns) do
            if slua.isValid(pawn) then
                pcall(function()
                    if slua.isValid(pawn.Mesh) then WallhackSystem.RemoveFromMesh(pawn.Mesh) end
                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(WH_AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then WallhackSystem.RemoveFromMesh(mesh) end
                        end
                    end
                    pcall(function()
                        local SkeletalMeshComponent = import("SkeletalMeshComponent")
                        if SkeletalMeshComponent then
                            local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) then WallhackSystem.RemoveFromMesh(comp) end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local StaticMeshComponent = import("StaticMeshComponent")
                        if StaticMeshComponent then
                            local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then WallhackSystem.RemoveFromMesh(comp) end
                                end
                            end
                        end
                    end)
                    local weapon = pawn:GetCurrentWeapon()
                    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                        WallhackSystem.RemoveFromMesh(weapon.Mesh)
                    end
                end)
            end
        end
    end)

    WallhackSystem.ProcessedPawns = {}
    WallhackSystem.ConsoleReady = false
    print("[WALLHACK] Stopped & Cleaned")
end

_G.WallhackSystem = WallhackSystem

-- ============================================================================
-- AIMBOT RANGE 280° SYSTEM - ✅ FULLY REWRITTEN & FIXED
-- ============================================================================
local Aimbot280System = {}
Aimbot280System.Active = false
Aimbot280System.Timer = nil
Aimbot280System.LastTargetTime = 0
Aimbot280System.CurrentTarget = nil

local AIMBOT_280_CONFIG = {
    Range = 280,
    LockSpeed = 12.0,
    MaxDistance = 15000,
    MinDistance = 0,
    Smoothness = 0.35,
    HeadOffsetZ = 65,
    NeckOffsetZ = 55,
    TargetBones = {"head", "neck_01", "spine_03", "pelvis"},
    PredictionScale = 0.25,
    FOV = 280,
    AimStrength = 0.85,
    RequireLineOfSight = false,
    OnlyWhenAiming = false,
}

local function IsPlayerAiming(localPawn)
    if not slua.isValid(localPawn) then return false end
    local aiming = false
    pcall(function()
        if localPawn.bIsAiming == true then aiming = true end
        if localPawn.IsAiming and localPawn:IsAiming() then aiming = true end
        if localPawn.bIsFiring == true then aiming = true end
        if localPawn.IsFiring and localPawn:IsFiring() then aiming = true end
        local weapon = localPawn:GetCurrentWeapon()
        if slua.isValid(weapon) then
            if weapon.bIsAiming == true then aiming = true end
            if weapon.bIsADS == true then aiming = true end
            if weapon.IsAiming and weapon:IsAiming() then aiming = true end
        end
    end)
    return aiming
end

function Aimbot280System.FindBestTarget(localPawn, pc)
    if not slua.isValid(localPawn) or not slua.isValid(pc) then return nil, nil end

    local allPawns = Game:GetAllPlayerPawns() or {}
    local myTeamId = localPawn.TeamID or 0
    local myLoc = localPawn:K2_GetActorLocation()
    if not myLoc then return nil, nil end

    local camLoc = myLoc
    local camRot = nil
    pcall(function()
        local camMgr = nil
        local GS = import("GameplayStatics")
        if GS and GS.GetPlayerCameraManager then
            camMgr = GS.GetPlayerCameraManager(pc, 0)
        end
        if camMgr then
            camLoc = camMgr:GetCameraLocation() or myLoc
            camRot = camMgr:GetCameraRotation()
        end
    end)

    local controlRot = nil
    pcall(function()
        if pc.GetControlRotation then controlRot = pc:GetControlRotation() end
    end)

    local useRot = camRot or controlRot
    if not useRot then return nil, nil end

    local forwardVec = nil
    pcall(function()
        if KismetMathLibrary and KismetMathLibrary.GetForwardVector then
            forwardVec = KismetMathLibrary.GetForwardVector(useRot)
        end
    end)
    if not forwardVec then return nil, nil end

    local halfFovRad = math_rad(AIMBOT_280_CONFIG.FOV / 2)
    local cosHalfFov = math.cos(halfFovRad)

    local bestTarget = nil
    local bestScore = -math.huge
    local bestBoneLoc = nil

    for _, pawn in pairs(allPawns) do
        if not slua.isValid(pawn) or pawn == localPawn then goto continue end

        local pawnTeam = pawn.TeamID or 0
        if pawnTeam == myTeamId then goto continue end

        local isAlive = false
        pcall(function()
            if pawn.Health and pawn.Health > 0 then isAlive = true
            elseif type(pawn.IsDead) == "function" then isAlive = not pawn:IsDead()
            elseif pawn.bIsDead == false then isAlive = true
            else isAlive = true end
        end)
        if not isAlive then goto continue end

        local pawnLoc = pawn:K2_GetActorLocation()
        if not pawnLoc then goto continue end

        local dx = pawnLoc.X - camLoc.X
        local dy = pawnLoc.Y - camLoc.Y
        local dz = pawnLoc.Z - camLoc.Z
        local dist = math_sqrt(dx*dx + dy*dy + dz*dz)

        if dist > AIMBOT_280_CONFIG.MaxDistance or dist < AIMBOT_280_CONFIG.MinDistance then
            goto continue
        end

        local toTargetLen = math_sqrt(dx*dx + dy*dy + dz*dz)
        if toTargetLen < 0.001 then goto continue end

        local toTargetX = dx / toTargetLen
        local toTargetY = dy / toTargetLen
        local toTargetZ = dz / toTargetLen

        local dot = forwardVec.X * toTargetX + forwardVec.Y * toTargetY + forwardVec.Z * toTargetZ

        if dot < cosHalfFov then goto continue end

        local angleFactor = (dot - cosHalfFov) / (1.0 - cosHalfFov)
        if angleFactor < 0 then angleFactor = 0 end

        local distanceFactor = 1.0 - (dist / AIMBOT_280_CONFIG.MaxDistance)
        if distanceFactor < 0 then distanceFactor = 0 end

        local score = (angleFactor * 0.7) + (distanceFactor * 0.3)

        local isAI = false
        pcall(function() isAI = Game:IsAI(pawn) end)
        if isAI then score = score + 0.05 end

        if AIMBOT_280_CONFIG.RequireLineOfSight then
            local hasLOS = false
            pcall(function()
                if pc.LineOfSightTo then hasLOS = pc:LineOfSightTo(pawn, nil, false) end
            end)
            if hasLOS then score = score + 0.15 else goto continue end
        end

        if score > bestScore then
            local boneLoc = nil
            local mesh = nil
            pcall(function()
                if pawn.Mesh and slua.isValid(pawn.Mesh) then mesh = pawn.Mesh end
            end)

            if mesh then
                for _, boneName in ipairs(AIMBOT_280_CONFIG.TargetBones) do
                    pcall(function()
                        if mesh.GetSocketLocation then
                            boneLoc = mesh:GetSocketLocation(boneName)
                        elseif mesh.GetBoneLocation then
                            boneLoc = mesh:GetBoneLocation(boneName)
                        end
                    end)
                    if boneLoc then break end
                end
            end

            if not boneLoc then
                boneLoc = {
                    X = pawnLoc.X,
                    Y = pawnLoc.Y,
                    Z = pawnLoc.Z + AIMBOT_280_CONFIG.HeadOffsetZ
                }
            end

            bestTarget = pawn
            bestScore = score
            bestBoneLoc = boneLoc
        end

        ::continue::
    end

    return bestTarget, bestBoneLoc
end

function Aimbot280System.Tick()
    pcall(function()
        if _G.AK_GetVal("AIMBOT_280") ~= 1 then return end
        if _G._MOD_EXPIRED then return end
        if not _G._WHA_BYPASS_ACTIVE then return end

        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end

        local localPawn = nil
        pcall(function()
            if pc.GetPlayerCharacterSafety then localPawn = pc:GetPlayerCharacterSafety() end
            if not slua.isValid(localPawn) then localPawn = GameplayData.GetPlayerCharacter() end
        end)
        if not slua.isValid(localPawn) then return end

        if AIMBOT_280_CONFIG.OnlyWhenAiming then
            if not IsPlayerAiming(localPawn) then return end
        end

        local isAlive = false
        pcall(function()
            if localPawn.Health and localPawn.Health > 0 then isAlive = true
            elseif type(localPawn.IsDead) == "function" then isAlive = not localPawn:IsDead()
            else isAlive = true end
        end)
        if not isAlive then return end

        local target, targetLoc = Aimbot280System.FindBestTarget(localPawn, pc)
        if not target or not targetLoc then
            Aimbot280System.CurrentTarget = nil
            return
        end

        Aimbot280System.CurrentTarget = target

        local camLoc = localPawn:K2_GetActorLocation()
        pcall(function()
            local camMgr = nil
            local GS = import("GameplayStatics")
            if GS and GS.GetPlayerCameraManager then
                camMgr = GS.GetPlayerCameraManager(pc, 0)
            end
            if camMgr and camMgr.GetCameraLocation then
                camLoc = camMgr:GetCameraLocation()
            end
        end)

        local dx = targetLoc.X - camLoc.X
        local dy = targetLoc.Y - camLoc.Y
        local dz = targetLoc.Z - camLoc.Z

        local horizontalDist = math_sqrt(dx*dx + dy*dy)
        local targetYaw = math_deg(math_atan2(dy, dx))
        local targetPitch = math_deg(math_atan2(dz, horizontalDist))

        local currentRot = nil
        pcall(function()
            if pc.GetControlRotation then currentRot = pc:GetControlRotation() end
        end)
        if not currentRot then return end

        local currentYaw = currentRot.Yaw or 0
        local currentPitch = currentRot.Pitch or 0

        local yawDiff = targetYaw - currentYaw
        while yawDiff > 180 do yawDiff = yawDiff - 360 end
        while yawDiff < -180 do yawDiff = yawDiff + 360 end

        local pitchDiff = targetPitch - currentPitch
        while pitchDiff > 180 do pitchDiff = pitchDiff - 360 end
        while pitchDiff < -180 do pitchDiff = pitchDiff + 360 end

        local smooth = AIMBOT_280_CONFIG.Smoothness
        local strength = AIMBOT_280_CONFIG.AimStrength
        local alpha = (1.0 - smooth) * strength

        local newYaw = currentYaw + (yawDiff * alpha)
        local newPitch = currentPitch + (pitchDiff * alpha)

        newPitch = math.max(-89.9, math.min(89.9, newPitch))
        while newYaw > 180 do newYaw = newYaw - 360 end
        while newYaw < -180 do newYaw = newYaw + 360 end

        pcall(function()
            if pc.SetControlRotation then
                local newRot = {Pitch = newPitch, Yaw = newYaw, Roll = 0}
                pc:SetControlRotation(newRot)
            end
        end)

        pcall(function()
            local wm = localPawn.WeaponManagerComponent
            if slua.isValid(wm) then
                local weapon = wm.CurrentWeaponReplicated
                if slua.isValid(weapon) then
                    local entity = weapon.ShootWeaponEntityComp
                    if slua.isValid(entity) then
                        entity.RecoilKickADS = 0.001
                        entity.GameDeviationFactor = 0.001
                        entity.GameDeviationAccuracy = 0.001
                    end
                end
            end
        end)

        Aimbot280System.LastTargetTime = os_clock()
    end)
end

function Aimbot280System.Start()
    if Aimbot280System.Active then return true end
    if _G.AK_GetVal("AIMBOT_280") ~= 1 then return false end
    if _G._MOD_EXPIRED then return false end
    if not _G._WHA_BYPASS_ACTIVE then return false end

    if Aimbot280System.Timer then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(Aimbot280System.Timer) end
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then pcall(function() pc:RemoveGameTimer(Aimbot280System.Timer) end) end
        end)
        Aimbot280System.Timer = nil
    end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        Aimbot280System.Timer = pc:AddGameTimer(0.008, true, function()
            pcall(Aimbot280System.Tick)
        end)
        Aimbot280System.Active = true
        print("[AIMBOT 280°] ✅ Started (PC timer, 120Hz)")
        return true
    end

    if _G.Game and _G.Game.AddGameTimer then
        Aimbot280System.Timer = _G.Game:AddGameTimer(0.008, true, function()
            pcall(Aimbot280System.Tick)
        end)
        Aimbot280System.Active = true
        print("[AIMBOT 280°] ✅ Started (Game timer, 120Hz)")
        return true
    end

    print("[AIMBOT 280°] ❌ Could not start timer")
    return false
end

function Aimbot280System.Stop()
    Aimbot280System.Active = false
    if Aimbot280System.Timer then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(Aimbot280System.Timer) end
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then pcall(function() pc:RemoveGameTimer(Aimbot280System.Timer) end) end
        end)
        Aimbot280System.Timer = nil
    end
    Aimbot280System.CurrentTarget = nil
    print("[AIMBOT 280°] Stopped")
end

_G.Aimbot280System = Aimbot280System

-- ============================================================================
-- ENEMY COUNTER
-- ============================================================================
_G.ENEMY_COUNTER_TIMER = nil

function _G.EnemyCounterLoop()
    if _G._MOD_EXPIRED then return end
    if not _G._WHA_BYPASS_ACTIVE then return end
    if _G.AK_GetVal("ENEMY_COUNTER") ~= 1 then return end

    local player = GameplayData and GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then return end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not slua.isValid(pc) then return end

    local hud = pc:GetHUD()
    if not slua.isValid(hud) then return end

    local myTeamId = player.TeamID or 0
    local myPos = player:K2_GetActorLocation()
    if not myPos then return end

    local totalEnemies = 0
    local botCount = 0
    local realCount = 0
    local MAX_DIST_SQ = 900000000

    local allPawns = Game:GetAllPlayerPawns() or {}
    for _, pawn in pairs(allPawns) do
        if slua.isValid(pawn) and pawn ~= player then
            local pawnTeam = pawn.TeamID or 0
            if pawnTeam ~= myTeamId then
                local pos = pawn:K2_GetActorLocation()
                if pos then
                    local dx = pos.X - myPos.X
                    local dy = pos.Y - myPos.Y
                    local dz = pos.Z - myPos.Z
                    if dx*dx + dy*dy + dz*dz <= MAX_DIST_SQ then
                        totalEnemies = totalEnemies + 1
                        local isBot = false
                        pcall(function() isBot = Game:IsAI(pawn) end)
                        if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
                    end
                end
            end
        end
    end

    local text = ""
    local COLOR_SAFE   = { R = 0,   G = 255, B = 200, A = 255 }
    local COLOR_WARN   = { R = 255, G = 150, B = 0,   A = 255 }
    local COLOR_DANGER = { R = 255, G = 20,  B = 60,  A = 255 }
    local color = COLOR_SAFE

    if totalEnemies == 0 then
        text = "[ AREA SECURE ]"
        color = COLOR_SAFE
    else
        text = string_format("ENEMIES: %d  (Bots: %d | Real: %d)", totalEnemies, botCount, realCount)
        color = (totalEnemies == 1) and COLOR_WARN or COLOR_DANGER
    end

    if _G.AK_GetVal("ENEMY_COUNTER") == 1 then
        text = text .. "\n✦ REAL DEV INDIAN ROHIT YT ✦"
    end

    if text ~= "" then
        local OFFSET = { X = 0, Y = 0, Z = 35 }
        hud:AddDebugText(text, player, 1.1, OFFSET, OFFSET, color, true, false, true, nil, 1.2, true)
    end
end

function _G.StartEnemyCounter()
    if _G.ENEMY_COUNTER_TIMER then
        pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_G.ENEMY_COUNTER_TIMER) end end)
        _G.ENEMY_COUNTER_TIMER = nil
    end
    if _G._MOD_EXPIRED then return false end
    if not _G._WHA_BYPASS_ACTIVE then return false end
    if _G.AK_GetVal("ENEMY_COUNTER") ~= 1 then return false end
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        _G.ENEMY_COUNTER_TIMER = pc:AddGameTimer(1.0, true, function()
            pcall(_G.EnemyCounterLoop)
        end)
        print("[ENEMY COUNTER] ✅ Started")
        return true
    end
    return false
end

function _G.StopEnemyCounter()
    if _G.ENEMY_COUNTER_TIMER then
        pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_G.ENEMY_COUNTER_TIMER) end end)
        _G.ENEMY_COUNTER_TIMER = nil
        print("[ENEMY COUNTER] Stopped")
    end
end

-- ============================================================================
-- DISTANCE MARKER SYSTEM
-- ============================================================================
local distanceMarkerConfig = {
    UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
    MaxWidgetNum = 99,
    MaxShowDistance = 6000000,
    bBindOutScreen = true,
    bBindBlocked = true,
    bIsBindingActor = true,
    BindSocketName = "head",
    bUseLuaWorldSocketName = true,
    WorldPositionOffset = FVector(0, 0, 50),
    bNeedPreLoad = true,
    Priority = 2
}

local function InitDistanceMarkerSystem()
    pcall(function()
        if InGameMarkTools and InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.OnInitMarkGroupData then
            InGameMarkTools.ScreenMarkManager:OnInitMarkGroupData(9999)
        end
        local gameplayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local screenMarkConfig = gameplayTools.GetCurrentConfig("ScreenMarkConfig")
        if screenMarkConfig then
            screenMarkConfig[9999] = distanceMarkerConfig
        end
        for moduleName, moduleData in pairs(package.loaded) do
            if type(moduleName) == "string" and string.find(moduleName, "ScreenMarkConfig") then
                if type(moduleData) == "table" then
                    moduleData[9999] = distanceMarkerConfig
                end
            end
        end
    end)
end

if not _G.AK_Active_Marks_Cache then _G.AK_Active_Marks_Cache = {} end

local function createDistanceMarker(enemy)
    if _G._MOD_EXPIRED then return end
    pcall(function()
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            enemy.NativeDistMark = InGameMarkTools.ClientAddMapMark(9999, FVector(0,0,0), 0, "", 4, enemy)
            _G.AK_Active_Marks_Cache[tostring(enemy)] = { actor = enemy, distMark = enemy.NativeDistMark }
        end
    end)
end

local function removeDistanceMarker(enemy)
    pcall(function()
        if InGameMarkTools then
            if InGameMarkTools.ClientRemoveMapMark then
                InGameMarkTools.ClientRemoveMapMark(enemy.NativeDistMark)
            elseif InGameMarkTools.HideMapMark then
                InGameMarkTools.HideMapMark(enemy.NativeDistMark)
            end
        end
        enemy.NativeDistMark = nil
        _G.AK_Active_Marks_Cache[tostring(enemy)] = nil
    end)
end

local function cleanupDeadEnemyMarks()
    for cacheKey, cacheData in pairs(_G.AK_Active_Marks_Cache) do
        local shouldRemove = false
        if not slua.isValid(cacheData.actor) then
            shouldRemove = true
        else
            pcall(function()
                local actor = cacheData.actor
                if actor.bHidden or (actor.Mesh and actor.Mesh.bHidden) then shouldRemove = true end
                if type(actor.IsDead) == "function" and actor:IsDead() then shouldRemove = true
                elseif actor.bIsDead == true or actor.bIsDeadFlag == true then shouldRemove = true end
            end)
        end
        if shouldRemove then
            pcall(function()
                if InGameMarkTools and InGameMarkTools.ClientRemoveMapMark then
                    InGameMarkTools.ClientRemoveMapMark(cacheData.distMark)
                end
            end)
            _G.AK_Active_Marks_Cache[cacheKey] = nil
        end
    end
end

-- ✅ FIXED: Native HP Bar remove function - for cleanup when OFF
local function removeNativeHPBarMark(enemy)
    if not slua.isValid(enemy) then return end
    pcall(function()
        if enemy.NativeHPBarMark then
            if InGameMarkTools and InGameMarkTools.ClientRemoveMapMark then
                InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
            end
        end
        enemy.NativeHPBarMark = nil
        enemy.bHasAKNativeHPBar = false
    end)
end

local function processEnemyMapESP(enemy, localPlayer, isMapESPEnabled)
    if _G._MOD_EXPIRED then return end
    if not slua.isValid(enemy) or enemy == localPlayer or enemy.TeamID == localPlayer.TeamID then return end
    local isDead = false
    pcall(function()
        if type(enemy.IsDead) == "function" then isDead = enemy:IsDead()
        elseif enemy.bIsDead then isDead = true end
        if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then isDead = true end
    end)
    if not isDead then
        if isMapESPEnabled == 1 then
            if not enemy.bHasAKNativeMapMarker then
                createDistanceMarker(enemy)
                enemy.bHasAKNativeMapMarker = true
            end
        else
            if enemy.bHasAKNativeMapMarker then
                removeDistanceMarker(enemy)
                enemy.bHasAKNativeMapMarker = false
            end
        end
    else
        if enemy.bHasAKNativeMapMarker then
            removeDistanceMarker(enemy)
            enemy.bHasAKNativeMapMarker = false
        end
    end
end

function ApplyHardAimbot()
    if not CheckExpiration() then return end
    if _G._MOD_EXPIRED then return end
    if not _G._WHA_BYPASS_ACTIVE then return end
    if not _G.AK_IsAimbotActive() then return end
    pcall(function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not slua.isValid(char) then return end
        local wm = char.WeaponManagerComponent
        if not slua.isValid(wm) then return end
        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end
        local entity = weapon.ShootWeaponEntityComp
        if not slua.isValid(entity) then return end

        entity.RecoilKickADS = 0.001
        entity.RecoilKick = 0.001
        entity.RecoilKickFactor = 0.0
        entity.GameDeviationFactor = 0.001
        entity.GameDeviationAccuracy = 0.001
        entity.Spread = 0.0
        entity.BaseSpread = 0.0
        entity.SpreadScale = 0.0
        entity.BulletSpread = 0.0

        if entity.AutoAimingConfig then
            for _, range in ipairs({"OuterRange", "InnerRange"}) do
                local cfg = entity.AutoAimingConfig[range]
                if cfg then
                    cfg.Speed = 20.0
                    cfg.RangeRate = 8.0
                    cfg.SpeedRate = 8.0
                    cfg.RangeRateSight = 8.0
                    cfg.SpeedRateSight = 8.0
                    cfg.CrouchRate = 6.0
                    cfg.ProneRate = 8.0
                    cfg.DyingRate = 0
                    cfg.adsorbMaxRange = 500
                    cfg.adsorbMinRange = 0
                    cfg.adsorbMinAttenuationDis = 0
                    cfg.adsorbMaxAttenuationDis = 15000
                    cfg.adsorbActiveMinRange = 0
                end
            end
            entity.AutoAimingConfig = entity.AutoAimingConfig
        end
        pcall(function()
            local aimComp = char.BP_AutoAimingComponent_C or char.BP_AutoAimingComponent or char.AutoAimingComponent
            if slua.isValid(aimComp) then
                if aimComp.Bones then
                    pcall(function() aimComp.Bones[0] = "head" end)
                    pcall(function() aimComp.Bones[1] = "head" end)
                    pcall(function() aimComp.Bones[2] = "head" end)
                    pcall(function() aimComp.Bones:Set(0, "head") end)
                    pcall(function() aimComp.Bones:Set(1, "head") end)
                    pcall(function() aimComp.Bones:Set(2, "head") end)
                end
                if aimComp.AimSpeed then aimComp.AimSpeed = 20.0 end
                if aimComp.AimRange then aimComp.AimRange = 15000 end
                if aimComp.AimFOV then aimComp.AimFOV = 280 end
                if aimComp.bAutoAimHead then aimComp.bAutoAimHead = true end
            end
        end)
        pcall(function()
            if char.CharacterMovement then
                char.CharacterMovement.bOrientToMovement = true
            end
        end)
        pcall(function()
            if weapon.SetSpread then weapon:SetSpread(0.0) end
            if weapon.SetRecoilFactor then weapon:SetRecoilFactor(0.0) end
            if weapon.SetAimAssistStrength then weapon:SetAimAssistStrength(1.0) end
        end)
    end)
end

-- ============================================================================
-- ESP VIP (Marker) SYSTEM
-- ============================================================================
local PlayerMapMarker = {}

local RedBoxOverlay = {
    bActive = false,
    MainContainer = nil,
    WidgetSlot = nil,
    TextBlockPlayer = nil,
    TextBlockBot = nil,
    Width = 260,
    Height = 28,
    OffsetY = 10,
    PlayerCount = 0,
    BotCount = 0,
    FontSize = 14,
    TextScaleValue = 1.0,
    NumLayers = 50,
    Red = 1.0,
    Green = 0.0,
    Blue = 0.0,
    LayerAlpha = 0.038,
    _CachedTextPlayer = "",
    _CachedTextBot = "",
    _CachedPosVec = nil
}

function RedBoxOverlay.Create()
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return true end
    if not _G.LexusConfig.Esp9_Count then return false end
    if _G._MOD_EXPIRED then return false end

    local ParentCanvas = PlayerMapMarker.ESPCanvas
    if not ParentCanvas or not slua.isValid(ParentCanvas) then 
        if not PlayerMapMarker.InitESPCanvas() then return false end
        ParentCanvas = PlayerMapMarker.ESPCanvas
    end
    if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end

    local Container = nil
    pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas) end)
    if not Container or not slua.isValid(Container) then return false end

    local FLinearColor = import("LinearColor") or FLinearColor
    local FVector2D = import("Vector2D") or FVector2D
    local color = FLinearColor(RedBoxOverlay.Red, RedBoxOverlay.Green, RedBoxOverlay.Blue, RedBoxOverlay.LayerAlpha)

    local numLayers = RedBoxOverlay.NumLayers
    local totalWidth = RedBoxOverlay.Width

    for i = 1, numLayers do
        local progress = (i / numLayers) ^ 1.15
        local layerWidth = progress * totalWidth
        local layerX = (totalWidth - layerWidth) / 2.0

        local border = nil
        pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)

        if border and slua.isValid(border) then
            pcall(function()
                border:SetBrushColor(color)
                border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)

            local slot = Container:AddChildToCanvas(border)
            if slot then
                slot:SetPosition(FVector2D(layerX, 0))
                slot:SetSize(FVector2D(layerWidth, RedBoxOverlay.Height))
            end
        end
    end

    local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    
    local txtPlayer = nil
    pcall(function() txtPlayer = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtPlayer and slua.isValid(txtPlayer) then
        pcall(function()
            local strText = string_format("Player: %d", RedBoxOverlay.PlayerCount)
            txtPlayer:SetText(strText)
            RedBoxOverlay._CachedTextPlayer = strText

            local whiteLinear = FLinearColor(1.0, 1.0, 1.0, 1.0)
            if FSlateColor then txtPlayer:SetColorAndOpacity(FSlateColor(whiteLinear)) else txtPlayer:SetColorAndOpacity(whiteLinear) end

            if txtPlayer.Font then
                local font = txtPlayer.Font
                font.Size = RedBoxOverlay.FontSize
                txtPlayer.Font = font
            end
            txtPlayer:SetRenderScale(FVector2D(RedBoxOverlay.TextScaleValue, RedBoxOverlay.TextScaleValue))
            txtPlayer:SetRenderTransformPivot(FVector2D(0.5, 0.5))
            txtPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local txtSlot1 = Container:AddChildToCanvas(txtPlayer)
        if txtSlot1 then
            pcall(function()
                txtSlot1:SetAutoSize(true)
                txtSlot1:SetAlignment(FVector2D(0.5, 0.5))
                txtSlot1:SetPosition(FVector2D(totalWidth * 0.35, RedBoxOverlay.Height * 0.5))
                txtSlot1:SetZOrder(1000)
            end)
        end
        RedBoxOverlay.TextBlockPlayer = txtPlayer
    end

    local txtBot = nil
    pcall(function() txtBot = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtBot and slua.isValid(txtBot) then
        pcall(function()
            local strText = string_format("Bot: %d", RedBoxOverlay.BotCount)
            txtBot:SetText(strText)
            RedBoxOverlay._CachedTextBot = strText

            local whiteLinear = FLinearColor(1.0, 1.0, 1.0, 1.0)
            if FSlateColor then txtBot:SetColorAndOpacity(FSlateColor(whiteLinear)) else txtBot:SetColorAndOpacity(whiteLinear) end

            if txtBot.Font then
                local font = txtBot.Font
                font.Size = RedBoxOverlay.FontSize
                txtBot.Font = font
            end
            txtBot:SetRenderScale(FVector2D(RedBoxOverlay.TextScaleValue, RedBoxOverlay.TextScaleValue))
            txtBot:SetRenderTransformPivot(FVector2D(0.5, 0.5))
            txtBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local txtSlot2 = Container:AddChildToCanvas(txtBot)
        if txtSlot2 then
            pcall(function()
                txtSlot2:SetAutoSize(true)
                txtSlot2:SetAlignment(FVector2D(0.5, 0.5))
                txtSlot2:SetPosition(FVector2D(totalWidth * 0.65, RedBoxOverlay.Height * 0.5))
                txtSlot2:SetZOrder(1000)
            end)
        end
        RedBoxOverlay.TextBlockBot = txtBot
    end

    local MainSlot = nil
    pcall(function() MainSlot = ParentCanvas:AddChildToCanvas(Container) end)
    if not MainSlot then return false end

    RedBoxOverlay.MainContainer = Container
    RedBoxOverlay.WidgetSlot = MainSlot
    
    pcall(function()
        MainSlot:SetAutoSize(false)
        MainSlot:SetZOrder(999)
        MainSlot:SetAlignment(FVector2D(0.5, 0.0))
        MainSlot:SetSize(FVector2D(RedBoxOverlay.Width, RedBoxOverlay.Height))
    end)

    RedBoxOverlay.UpdatePosition()
    return true
end

function RedBoxOverlay.SetCounts(players, bots)
    if RedBoxOverlay.PlayerCount == players and RedBoxOverlay.BotCount == bots then return end
    RedBoxOverlay.PlayerCount = players or 0
    RedBoxOverlay.BotCount = bots or 0
    
    if RedBoxOverlay.TextBlockPlayer and slua.isValid(RedBoxOverlay.TextBlockPlayer) then
        pcall(function()
            local strP = string_format("Player: %d", RedBoxOverlay.PlayerCount)
            if RedBoxOverlay._CachedTextPlayer ~= strP then
                RedBoxOverlay.TextBlockPlayer:SetText(strP)
                RedBoxOverlay._CachedTextPlayer = strP
            end
        end)
    end
    if RedBoxOverlay.TextBlockBot and slua.isValid(RedBoxOverlay.TextBlockBot) then
        pcall(function()
            local strB = string_format("Bot: %d", RedBoxOverlay.BotCount)
            if RedBoxOverlay._CachedTextBot ~= strB then
                RedBoxOverlay.TextBlockBot:SetText(strB)
                RedBoxOverlay._CachedTextBot = strB
            end
        end)
    end
end

function RedBoxOverlay.UpdatePosition()
    local Slot = RedBoxOverlay.WidgetSlot
    if not Slot or not slua.isValid(Slot) then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not slua.isValid(PC) then return end

    local fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
    local FVector2D = import("Vector2D") or FVector2D
    pcall(function()
        if not RedBoxOverlay._CachedPosVec then
            RedBoxOverlay._CachedPosVec = FVector2D(fromX, fromY)
        else
            RedBoxOverlay._CachedPosVec.X = fromX
            RedBoxOverlay._CachedPosVec.Y = fromY
        end
        Slot:SetPosition(RedBoxOverlay._CachedPosVec)
    end)
end

function RedBoxOverlay.Start()
    if not _G.LexusConfig.Esp9_Count then return end
    if _G._MOD_EXPIRED then return end
    if not _G._WHA_BYPASS_ACTIVE then return end
    if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return end
    if RedBoxOverlay.Create() then
        RedBoxOverlay.bActive = true
        pcall(function() RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    end
end

-- ✅ FIXED: Complete RedBoxOverlay cleanup
function RedBoxOverlay.Stop()
    RedBoxOverlay.bActive = false
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
        pcall(function()
            RedBoxOverlay.MainContainer:RemoveFromParent()
            RedBoxOverlay.MainContainer:ConditionalBeginDestroy()
        end)
    end
    RedBoxOverlay.MainContainer = nil
    RedBoxOverlay.WidgetSlot = nil
    RedBoxOverlay.TextBlockPlayer = nil
    RedBoxOverlay.TextBlockBot = nil
    RedBoxOverlay._CachedPosVec = nil
    RedBoxOverlay._CachedTextPlayer = ""
    RedBoxOverlay._CachedTextBot = ""
    RedBoxOverlay.PlayerCount = 0
    RedBoxOverlay.BotCount = 0
end

_G.RedBoxOverlay = RedBoxOverlay

local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local KismetMathLibrary2 = nil
local KismetSystemLibrary = nil

pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)
pcall(function() KismetMathLibrary2 = import("KismetMathLibrary") end)
pcall(function() KismetSystemLibrary = import("KismetSystemLibrary") end)

local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local FVector = _G.FVector or import("Vector")

PlayerMapMarker.MarkTypeID = 1007
PlayerMapMarker.bUseScreenESP = true
PlayerMapMarker.bUseScreenMark = false
PlayerMapMarker.bUseQuickSign = false
PlayerMapMarker.bUseNavigator = false
PlayerMapMarker.bUseWidgetComponent = false
PlayerMapMarker.QuickSignConfigKey = "C_MarkPos"

PlayerMapMarker.WidgetCompUIPath = "/Game/BluePrints/ControlInput/NewbieItem/NewbieTips_ConsumeTips.NewbieTips_ConsumeTips"
PlayerMapMarker.WidgetCompBoneName = "head"
PlayerMapMarker.WidgetCompOffset = FVector and FVector(0, 0, 80) or {X=0, Y=0, Z=80}
PlayerMapMarker.WidgetCompDrawSize = FVector2D and FVector2D(210, 35) or {X=210, Y=35}

PlayerMapMarker.ESPBoneName = "head"
PlayerMapMarker.ESPWorldOffsetZ = 0
PlayerMapMarker.ESPScreenOffsetY = 0
PlayerMapMarker.ESPAnchorOffsetX = 35
PlayerMapMarker.ESPAnchorOffsetY = 0
PlayerMapMarker.ESPTextOffsetX = 0
PlayerMapMarker.ESPTextOffsetY = 0

PlayerMapMarker.ESPWidgetAlignment = FVector2D and FVector2D(0.5, 1.0) or {X=0.5, Y=1.0}
PlayerMapMarker.ESPWidgetSize = FVector2D and FVector2D(70, 21) or {X=70, Y=21}
PlayerMapMarker.ESPWidgetAutoSize = true
PlayerMapMarker.ESPWidgetZOrder = 2

PlayerMapMarker.bShowDistance = true
PlayerMapMarker.DistanceUnit = "m"
PlayerMapMarker.WeaponIconBrushW = 96
PlayerMapMarker.WeaponIconBrushH = 48
PlayerMapMarker.HPWidgetSwitcherTypeIndex = 0
PlayerMapMarker.HPWidgetSwitcherType2Index = 0
PlayerMapMarker.bForceSwitcherIndexEveryUpdate = true

PlayerMapMarker.bUseSnapLines = true
PlayerMapMarker.SnapLineThickness = 1.0
PlayerMapMarker.SnapLineOriginY = 50
PlayerMapMarker.SnapLineOriginOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetY = -14
PlayerMapMarker.SnapLineColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=255, G=255, B=255, A=255}
PlayerMapMarker.SnapLineOpacity = 0.7

PlayerMapMarker.bUseSkeleton = true
PlayerMapMarker.SkeletonThickness = 0.8
PlayerMapMarker.SkeletonColor = nil
PlayerMapMarker.SkeletonOpacity = 0.8
PlayerMapMarker.SkeletonMaxDistance = 100000
PlayerMapMarker.bUseVisibilityColor = true
PlayerMapMarker.SkeletonVisibleColor = FLinearColor and FLinearColor(0.0, 1.0, 0.0, 0.8) or {R=0,G=255,B=0,A=200}
PlayerMapMarker.SkeletonCoverColor = FLinearColor and FLinearColor(0.9, 0.0, 0.0, 0.6) or {R=230,G=0,B=0,A=150}

PlayerMapMarker.SkeletonWidgets = {}
PlayerMapMarker._StaticBoneLocCache = {}

PlayerMapMarker.SkeletonChains = {
    {"neck_01", "lowerarm_r", "hand_r"},
    {"neck_01", "lowerarm_l", "hand_l"},
    {"head", "neck_01", "pelvis"},
    {"pelvis", "calf_r", "foot_r"},
    {"pelvis", "calf_l", "foot_l"}
}

PlayerMapMarker.BoneNameFallbacks = {
    ["head"] = {"head", "Head", "head_socket"},
    ["neck_01"] = {"neck_01", "Neck_01", "neck", "Neck"},
    ["clavicle_r"] = {"clavicle_r", "Clavicle_R", "clavicle_R"},
    ["upperarm_r"] = {"upperarm_r", "UpperArm_R", "arm_r", "arm_r_01"},
    ["lowerarm_r"] = {"lowerarm_r", "LowerArm_R", "forearm_r"},
    ["hand_r"] = {"hand_r", "Hand_R", "hand_r_socket"},
    ["clavicle_l"] = {"clavicle_l", "Clavicle_L", "clavicle_l"},
    ["upperarm_l"] = {"upperarm_l", "UpperArm_L", "arm_l", "arm_l_01"},
    ["lowerarm_l"] = {"lowerarm_l", "LowerArm_L", "forearm_l"},
    ["hand_l"] = {"hand_l", "Hand_L", "hand_l_socket"},
    ["spine_03"] = {"spine_03", "Spine_03", "spine_02", "spine"},
    ["spine_02"] = {"spine_02", "Spine_02", "spine_01"},
    ["pelvis"] = {"pelvis", "Pelvis", "hip"},
    ["thigh_r"] = {"thigh_r", "Thigh_R", "leg_r"},
    ["calf_r"] = {"calf_r", "Calf_R", "shin_r"},
    ["foot_r"] = {"foot_r", "Foot_R", "foot_r_socket"},
    ["thigh_l"] = {"thigh_l", "Thigh_L", "leg_l"},
    ["calf_l"] = {"calf_l", "Calf_L", "shin_l"},
    ["foot_l"] = {"foot_l", "Foot_L", "foot_l_socket"},
}

PlayerMapMarker.MapAddedFlag = 4
PlayerMapMarker.nUpdateInterval = 0.5
PlayerMapMarker.bUseFrameTick = false
PlayerMapMarker.nHeavyScanFrameInterval = 15
PlayerMapMarker.nDistanceUpdateFrameInterval = 5
PlayerMapMarker.bIncludeMe = false
PlayerMapMarker.bIncludeAI = true
PlayerMapMarker.bUseServerMarks = false

PlayerMapMarker.bActive = false
PlayerMapMarker.MarkMap = {}
PlayerMapMarker.PlayerInfo = {}
PlayerMapMarker.ESPCanvas = nil
PlayerMapMarker.ESPWidgets = {}
PlayerMapMarker.ESPWidgetPtrs = {}
PlayerMapMarker.SnapLineWidgets = {}

PlayerMapMarker._cachedViewportW = 1920
PlayerMapMarker._cachedViewportH = 1080
PlayerMapMarker._FrameCount = 0
PlayerMapMarker._bTickRegistered = false
PlayerMapMarker._CachedAllChars = nil
PlayerMapMarker._CachedMyLoc = nil
PlayerMapMarker._CachedMyKey = nil
PlayerMapMarker.WidgetComps = {}
PlayerMapMarker._bAllPathsFailed = false
PlayerMapMarker._bLightUpdateScheduled = false
PlayerMapMarker._LightUpdateInterval = 0.02
PlayerMapMarker._bDistanceUpdateScheduled = false
PlayerMapMarker._DistanceUpdateInterval = 0.1
PlayerMapMarker._bScreenMarkConfigSetup = false

local function IsValid(obj)
    if obj == nil then return false end
    if slua and slua.isValid then return slua.isValid(obj) end
    return obj ~= nil
end

function PlayerMapMarker.SetupScreenMarkConfig()
    if PlayerMapMarker._bScreenMarkConfigSetup then return true end
    local bOK = false
    pcall(function()
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local ScreenMarkConfig = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
        if ScreenMarkConfig then
            ScreenMarkConfig[1007] = {
                UIPathName = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP_C",
                MaxWidgetNum = 100,
                MaxShowDistance = 6000000,
                bBindOutScreen = false,
                bBindBlocked = true,
                bNeedPreLoad = true,
                bIsBindingActor = true,
                BindSocketName = "HelmetSocket",
                WorldPositionOffset = FVector and FVector(0, 0, 80) or {X=0,Y=0,Z=80}
            }
            PlayerMapMarker._bScreenMarkConfigSetup = true
            bOK = true
        end
    end)
    return bOK
end

function PlayerMapMarker.GetGameplayData()
    if PlayerMapMarker._CachedGameplayData then return PlayerMapMarker._CachedGameplayData end
    local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
    if ok and GDP then PlayerMapMarker._CachedGameplayData = GDP return GDP end
    return nil
end

function PlayerMapMarker.GetMyPlayerController()
    local PC = PlayerMapMarker._CachedPC
    if PC and IsValid(PC) then return PC end
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end)
    if PC and IsValid(PC) then PlayerMapMarker._CachedPC = PC return PC end
    return nil
end

function PlayerMapMarker.GetCGameState()
    if CGameState and IsValid(CGameState) then return CGameState end
    if PlayerMapMarker._CachedCGameState and IsValid(PlayerMapMarker._CachedCGameState) then return PlayerMapMarker._CachedCGameState end
    local ok, GS = pcall(function() return require("GameLua.GameCore.Data.CGameState") end)
    if ok and GS then PlayerMapMarker._CachedCGameState = GS return GS end
    return nil
end

function PlayerMapMarker.GetAllCharacters()
    local AllChars = {}
    pcall(function()
        local Pawns = Game:GetAllPlayerPawns()
        if Pawns then
            for _, Pawn in pairs(Pawns) do
                if Pawn and slua.isValid(Pawn) then
                    local pKey = nil
                    if Pawn.GetPlayerKey then pKey = Pawn:GetPlayerKey() end
                    if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
                    if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
                    if pKey then AllChars[pKey] = Pawn end
                end
            end
        end
    end)
    if not next(AllChars) then
        local GS = PlayerMapMarker.GetCGameState()
        if GS and GS.GetAllCharacters then pcall(function() AllChars = GS:GetAllCharacters() end) end
    end
    return AllChars
end

function PlayerMapMarker.GetMyPlayerKey()
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return nil end
    local MyKey = nil
    pcall(function()
        if PC.GetPlayerKey then MyKey = PC:GetPlayerKey()
        elseif PC.PlayerState and PC.PlayerState.PlayerKey then MyKey = PC.PlayerState.PlayerKey end
    end)
    return MyKey
end

function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
    local bIsMe = false
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then
            local MyChar = GDP.GetLocalCharacter()
            if MyChar and Character == MyChar then bIsMe = true return end
        end
        local PC = PlayerMapMarker.GetMyPlayerController()
        if PC and PC.GetPawn then
            local Pawn = PC:GetPawn()
            if Pawn and Character == Pawn then bIsMe = true return end
        end
    end)
    if not bIsMe and MyKey ~= nil and PlayerKey ~= nil then bIsMe = (tostring(PlayerKey) == tostring(MyKey)) end
    return bIsMe
end

function PlayerMapMarker.GetCharacterLocation(Character)
    if not IsValid(Character) then return nil end
    local Loc = nil
    pcall(function() if Character.K2_GetActorLocation then Loc = Character:K2_GetActorLocation() end end)
    if not Loc then pcall(function() if Game and Game.GetActorLocation then Loc = Game:GetActorLocation(Character) end end) end
    return Loc
end

function PlayerMapMarker.CalcDistance(Loc1, Loc2)
    if not Loc1 or not Loc2 then return nil end
    local Dist = nil
    pcall(function() if FVector and FVector.Dist2D then Dist = FVector.Dist2D(Loc1, Loc2) end end)
    if not Dist then
        pcall(function()
            local DX = (Loc1.X or 0) - (Loc2.X or 0)
            local DY = (Loc1.Y or 0) - (Loc2.Y or 0)
            Dist = math_sqrt(DX * DX + DY * DY)
        end)
    end
    return Dist
end

function PlayerMapMarker.GetDistanceString(MyLoc, TargetLoc)
    if not PlayerMapMarker.bShowDistance then return "" end
    if not MyLoc or not TargetLoc then return "" end
    local Dist = PlayerMapMarker.CalcDistance(MyLoc, TargetLoc)
    if not Dist then return "" end
    local Meters = Dist / 100
    if Meters < 1000 then return string_format("%dm", math_floor(Meters))
    else return string_format("%.1fkm", Meters / 1000) end
end

function PlayerMapMarker.GetMyLocation()
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    local MyChar = nil
    pcall(function() MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
    if not IsValid(MyChar) then
        local PC = PlayerMapMarker.GetMyPlayerController()
        if IsValid(PC) then
            pcall(function()
                if PC.GetPawn then
                    local Pawn = PC:GetPawn()
                    if IsValid(Pawn) and Pawn.K2_GetActorLocation then return Pawn:K2_GetActorLocation() end
                end
            end)
        end
        return nil
    end
    return PlayerMapMarker.GetCharacterLocation(MyChar)
end

function PlayerMapMarker.GetPlayerName(Character)
    if not IsValid(Character) then return "Unknown" end
    local Name = nil
    pcall(function() if Character.GetPlayerNameSafety then Name = Character:GetPlayerNameSafety() end end)
    if not Name then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid(PS) and PS.GetPlayerName then Name = PS:GetPlayerName() end
        end)
    end
    return Name or "Unknown"
end

function PlayerMapMarker.IsAI(Character)
    local bAI = false
    pcall(function() if Game and Game.IsAI then bAI = Game:IsAI(Character) end end)
    return bAI
end

function PlayerMapMarker.IsAlive(Character)
    local bAlive = true
    pcall(function() if Character.IsAlive then bAlive = Character:IsAlive() end end)
    return bAlive
end

function PlayerMapMarker.IsOurESPWidget(w)
    if not w or not slua.isValid(w) then return false end
    local bIsOurs = false
    pcall(function()
        local wstr = tostring(w)
        for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
            if ESPData and ESPData.Widget and ESPData.Widget.Container then
                local cstr = tostring(ESPData.Widget.Container)
                if cstr == wstr then bIsOurs = true return end
            end
        end
    end)
    if bIsOurs then return true end
    pcall(function()
        if w.GetChildrenCount then
            local n = w:GetChildrenCount()
            for i = 0, n - 1 do
                local child = w:GetChildAt(i)
                if child and slua.isValid(child) then
                    local cstr = tostring(child)
                    if string.find(cstr, "Border") then bIsOurs = true break end
                end
            end
        end
    end)
    if not bIsOurs then
        pcall(function()
            local slot = w.Slot
            if slot and slot.GetPosition then
                local pos = slot:GetPosition()
                if pos and (math_abs(pos.X or 0) > 1 or math_abs(pos.Y or 0) > 1) then bIsOurs = true end
            end
        end)
    end
    return bIsOurs
end

function PlayerMapMarker.ApplyAnchorBasedPosition(Slot, ScreenPos, Canvas)
    if not Slot or not ScreenPos then return false end
    local sx = ScreenPos.X or 0
    local sy = ScreenPos.Y or 0
    local sz = PlayerMapMarker.ESPWidgetSize or (FVector2D and FVector2D(100, 30) or {X=100, Y=30})
    local align = PlayerMapMarker.ESPWidgetAlignment or (FVector2D and FVector2D(0.5, 1.0) or {X=0.5, Y=1.0})

    local canvasW, canvasH = 0, 0
    if PlayerMapMarker._cachedViewportW and PlayerMapMarker._cachedViewportW > 200 then
        canvasW = PlayerMapMarker._cachedViewportW
        canvasH = PlayerMapMarker._cachedViewportH
    end

    if canvasW < 200 then
        pcall(function()
            local PC = PlayerMapMarker.GetMyPlayerController()
            if IsValid(PC) and PC.GetViewportSize then
                local VS = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
                PC:GetViewportSize(VS)
                if VS and VS.X and VS.X > 200 then
                    canvasW = VS.X ; canvasH = VS.Y
                    PlayerMapMarker._cachedViewportW = canvasW ; PlayerMapMarker._cachedViewportH = canvasH
                end
            end
        end)
    end

    if canvasW > 200 and canvasH > 200 then
        local anchorX = (sx + (PlayerMapMarker.ESPAnchorOffsetX or 0)) / canvasW
        local anchorY = (sy + (PlayerMapMarker.ESPAnchorOffsetY or 0)) / canvasH
        anchorX = math.max(0, math.min(1, anchorX))
        anchorY = math.max(0, math.min(1, anchorY))

        local bSuccess = false
        pcall(function()
            local FAnchors = import("Anchors") or import("/Script/SlateCore.Anchors")
            if Slot.SetAnchors and FAnchors then
                local anchors = FAnchors(anchorX, anchorY, anchorX, anchorY)
                if anchors then Slot:SetAnchors(anchors) Slot:SetPosition(FVector2D and FVector2D(0, 0) or {X=0, Y=0}) bSuccess = true end
            end
        end)
        if not bSuccess then
            pcall(function()
                if Slot.SetAnchors then Slot:SetAnchors(anchorX, anchorY, anchorX, anchorY) Slot:SetPosition(FVector2D and FVector2D(0, 0) or {X=0, Y=0}) bSuccess = true end
            end)
        end
        if bSuccess then
            pcall(function() if Slot.SetOffsets and import("Margin") then Slot:SetOffsets(import("Margin")(0, 0, sz.X, sz.Y)) end end)
            pcall(function() Slot:SetSize(sz) end)
            pcall(function() Slot:SetAlignment(align) end)
            pcall(function() if Slot.SetAutoSize then Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true) end end)
            pcall(function() if Slot.SetZOrder then Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2) end end)
            return true
        end
    end

    pcall(function()
        Slot:SetPosition(FVector2D and FVector2D(sx, sy) or {X=sx, Y=sy})
        pcall(function() Slot:SetSize(sz) end)
        pcall(function() Slot:SetAlignment(align) end)
        pcall(function() if Slot.SetAutoSize then Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true) end end)
        pcall(function() if Slot.SetZOrder then Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2) end end)
    end)
    return false
end

function PlayerMapMarker.InitESPCanvas()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then return true end
    local InGameUITools = nil
    pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    if not InGameUITools then return false end
    local MainControlBaseUI = nil
    pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI() end)
    if not MainControlBaseUI or not Game:IsValid(MainControlBaseUI) then return false end

    local ParentCanvas = nil
    pcall(function()
        if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then ParentCanvas = MainControlBaseUI.CanvasPanel_0
        elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then ParentCanvas = MainControlBaseUI.CanvasPanel_42 end
    end)

    if not ParentCanvas then return false end
    PlayerMapMarker.ESPCanvas = ParentCanvas

    pcall(function()
        local nChildren = ParentCanvas:GetChildrenCount()
        for i = nChildren - 1, 0, -1 do
            local child = ParentCanvas:GetChildAt(i)
            if child and slua.isValid(child) then
                if PlayerMapMarker.IsOurESPWidget(child) then pcall(function() ParentCanvas:RemoveChild(child) end) end
            end
        end
    end)
    return true
end

function PlayerMapMarker.FindProgressBarInWidget(WidgetObj, Depth, MaxDepth)
    if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
    Depth = Depth or 0 ; MaxDepth = MaxDepth or 5
    if Depth > MaxDepth then return nil end

    local bIsPB = false
    pcall(function() if WidgetObj.SetPercent and WidgetObj.SetFillColorAndOpacity then bIsPB = true end end)
    if bIsPB then return WidgetObj end

    local nChildren = 0
    pcall(function() if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end end)

    for i = 0, math.max(nChildren - 1, 0) do
        local child = nil
        pcall(function() child = WidgetObj:GetChildAt(i) end)
        if child and slua.isValid(child) then
            local result = PlayerMapMarker.FindProgressBarInWidget(child, Depth + 1, MaxDepth)
            if result then return result end
        end
    end
    return nil
end

function PlayerMapMarker.GetTeamID(Character)
    if not IsValid(Character) then return nil end
    local TeamID = nil
    pcall(function() if Character.GetTeamID then TeamID = Character:GetTeamID() end end)
    if not TeamID then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid(PS) and PS.GetTeamID then TeamID = PS:GetTeamID()
            elseif IsValid(PS) and PS.TeamID then TeamID = PS.TeamID end
        end)
    end
    if not TeamID then pcall(function() if Character.TeamID then TeamID = Character.TeamID end end) end
    return TeamID
end

function PlayerMapMarker.GetTeamColor(TeamID)
    return FLinearColor and FLinearColor(0.1, 0.4, 1.0, 1.0) or {R=25,G=100,B=255,A=255}
end

local _WhiteTexture = nil
local _bWhiteTextureFailed = false
local function GetWhiteTexture()
    if _WhiteTexture then return _WhiteTexture end
    if _bWhiteTextureFailed then return nil end
    pcall(function()
        local paths = { "/Game/BluePrints/UI/Textures/White.White", "/Game/BluePrints/UI/Textures/Common/White.White", "/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture" }
        for _, path in ipairs(paths) do
            pcall(function() local tex = import(path); if tex and slua.isValid(tex) then _WhiteTexture = tex return end end)
            if _WhiteTexture then break end
        end
    end)
    if not _WhiteTexture then _bWhiteTextureFailed = true end
    return _WhiteTexture
end

local function SetImageColor(Image, color)
    if not Image or not slua.isValid(Image) then return false end
    local bOK = false
    pcall(function() if Image.SetBrushTintColor then Image:SetBrushTintColor(color); bOK = true end end)
    pcall(function() if Image.SetColorAndOpacity then Image:SetColorAndOpacity(color); bOK = true end end)
    pcall(function()
        if Image.SetBrushFromTexture then
            local whiteTex = GetWhiteTexture()
            if whiteTex then
                Image:SetBrushFromTexture(whiteTex, false)
                if Image.SetColorAndOpacity then Image:SetColorAndOpacity(color) end
                bOK = true
            end
        end
    end)
    pcall(function() Image:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible); Image:SetRenderOpacity(1.0) end)
    return bOK
end

function PlayerMapMarker._GetWidgetRoot(WidgetObj)
    if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
    local Root = nil
    pcall(function() if WidgetObj.GetRootWidget then Root = WidgetObj:GetRootWidget() end end)
    if Root and slua.isValid(Root) then return Root end
    pcall(function() if WidgetObj.WidgetTree and WidgetObj.WidgetTree.RootWidget then Root = WidgetObj.WidgetTree.RootWidget end end)
    if Root and slua.isValid(Root) then return Root end
    pcall(function() if WidgetObj.RootWidget and slua.isValid(WidgetObj.RootWidget) then Root = WidgetObj.RootWidget end end)
    return Root
end

function PlayerMapMarker._FindNamedWidgetInTree(WidgetObj, TargetName, MaxDepth)
    if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
    MaxDepth = MaxDepth or 8
    local wname = nil
    pcall(function() if WidgetObj.GetName then wname = WidgetObj:GetName() end end)
    if wname and wname == TargetName then return WidgetObj end

    local wstr = tostring(WidgetObj)
    if wstr and string.find(wstr, TargetName, 1, true) then
        if wname and wname == TargetName then return WidgetObj
        elseif not wname or wname == "" then
            local _, endPos = string.find(wstr, TargetName, 1, true)
            if endPos then
                local nextChar = string.sub(wstr, endPos + 1, endPos + 1)
                if nextChar ~= "_" and nextChar ~= "" then return WidgetObj end
            end
        end
    end

    local nChildren = 0
    pcall(function() if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end end)

    if nChildren > 0 then
        for i = 0, nChildren - 1 do
            local child = nil
            pcall(function() child = WidgetObj:GetChildAt(i) end)
            if child and slua.isValid(child) then
                local found = PlayerMapMarker._FindNamedWidgetInTree(child, TargetName, MaxDepth - 1)
                if found then return found end
            end
        end
    else
        local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
        if Root and slua.isValid(Root) and Root ~= WidgetObj then
            local found = PlayerMapMarker._FindNamedWidgetInTree(Root, TargetName, MaxDepth - 1)
            if found then return found end
        end
    end
    return nil
end

function PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
    if not Widget or not Widget.Container then return end
    
    if not _G.LexusConfig.Esp9_Team then
        pcall(function()
            local W = Widget.Container
            if W and slua.isValid(W) then
                local img1 = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamBG", 8)
                if img1 and slua.isValid(img1) then img1:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                local img2 = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamLogoBG", 8)
                if img2 and slua.isValid(img2) then img2:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                if Widget.TeamBgBorder and slua.isValid(Widget.TeamBgBorder) then Widget.TeamBgBorder:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
        end)
        return
    end

    local color = PlayerMapMarker.GetTeamColor(TeamID)
    if not color then return end

    pcall(function()
        local W = Widget.Container
        if not W or not slua.isValid(W) then return end

        local bBG = false
        local Image_TeamBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamBG", 8)
        if Image_TeamBG and slua.isValid(Image_TeamBG) then bBG = SetImageColor(Image_TeamBG, color) end

        local Image_TeamLogoBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamLogoBG", 8)
        if Image_TeamLogoBG and slua.isValid(Image_TeamLogoBG) then SetImageColor(Image_TeamLogoBG, color) end

        if W.SetTeamColor then pcall(function() W:SetTeamColor(TeamID) end) end
        
        if not Widget.TeamBgBorder or not slua.isValid(Widget.TeamBgBorder) then
            pcall(function()
                local Border = CGame:NewObjectFromPath("/Script/UMG.Border", W)
                if Border and slua.isValid(Border) then
                    pcall(function() Border:SetBrushColor(color) end)
                    pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    pcall(function() Border:SetRenderOpacity(0.7) end)
                    pcall(function() Border:SetDesiredSizeOverride(FVector2D and FVector2D(120, 20) or {X=120, Y=20}) end)
                    pcall(function() if W.AddChild then W:AddChild(Border) end end)
                    pcall(function() if Border.SetZOrder then Border:SetZOrder(-1) end end)
                    Widget.TeamBgBorder = Border
                end
            end)
        else
            pcall(function()
                Widget.TeamBgBorder:SetBrushColor(color)
                Widget.TeamBgBorder:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                Widget.TeamBgBorder:SetRenderOpacity(0.7)
            end)
        end
    end)
end

function PlayerMapMarker.GetCharacterMesh(Character)
    if not IsValid(Character) then return nil end
    local Mesh = nil
    pcall(function() if Character.Mesh and Game:IsValid(Character.Mesh) then Mesh = Character.Mesh end end)
    if not Mesh then pcall(function() local SkeletalMeshCompClass = import("/Script/Engine.SkeletalMeshComponent") Mesh = Character:GetComponentByClass(SkeletalMeshCompClass) end) end
    return Mesh
end

function PlayerMapMarker.GetESPLocation(Character)
    if not IsValid(Character) then return nil end
    local BoneLoc = PlayerMapMarker.GetCharacterLocation(Character)
    if BoneLoc then
        local heightOffset = 85
        pcall(function()
            if Character.bIsCrouched then heightOffset = 60 end
            if Character.IsProne and Character:IsProne() then heightOffset = 30 end
        end)
        pcall(function() BoneLoc.Z = BoneLoc.Z + heightOffset + (PlayerMapMarker.ESPWorldOffsetZ or 0) end)
    end
    return BoneLoc
end

function PlayerMapMarker.GetCharacterWeaponInfo(Character)
    if not IsValid(Character) then return nil end
    local WeaponID, WeaponName, WeaponIconPath, WeaponIconTexture, CurrentWeapon = nil, nil, nil, nil, nil

    pcall(function() if Character.GetCurrentWeapon then CurrentWeapon = Character:GetCurrentWeapon() end end)
    if not CurrentWeapon then pcall(function() CurrentWeapon = Character.CurrentWeapon end) end
    if not CurrentWeapon then pcall(function() if Character.GetWeaponManager then local WM = Character:GetWeaponManager() if WM and WM.GetCurrentWeapon then CurrentWeapon = WM:GetCurrentWeapon() end end end) end

    if CurrentWeapon and IsValid(CurrentWeapon) then
        pcall(function() if CurrentWeapon.GetWeaponID then WeaponID = CurrentWeapon:GetWeaponID() end end)
        if not WeaponID then pcall(function() WeaponID = CurrentWeapon.WeaponID end) end
        if not WeaponID then pcall(function() if CurrentWeapon.GetItemID then WeaponID = CurrentWeapon:GetItemID() end end) end
        pcall(function() if CurrentWeapon.GetWeaponName then WeaponName = CurrentWeapon:GetWeaponName() end end)
        pcall(function() if CurrentWeapon.GetWeaponIconPath then WeaponIconPath = CurrentWeapon:GetWeaponIconPath() end end)
        pcall(function() if CurrentWeapon.GetWeaponIcon then WeaponIconTexture = CurrentWeapon:GetWeaponIcon() end end)
    end

    if not WeaponID then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety() elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if PS and IsValid(PS) then
                if PS.GetCurrentWeaponID then WeaponID = PS:GetCurrentWeaponID() end
                if not WeaponID and PS.CurWeaponID then WeaponID = PS.CurWeaponID end
            end
        end)
    end
    return { WeaponID = WeaponID, WeaponName = WeaponName, WeaponIconPath = WeaponIconPath, WeaponIconTexture = WeaponIconTexture, CurrentWeapon = CurrentWeapon }
end

function PlayerMapMarker.FindWeaponIconInWidget(WidgetObj, Depth, MaxDepth)
    if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
    Depth = Depth or 0 ; MaxDepth = MaxDepth or 8
    local propNames = { "Image_Weapon", "Image_WeaponIcon", "Image_Gun", "Image_Icon", "WeaponIcon", "WeaponImage", "Image_Equip" }
    for _, pname in ipairs(propNames) do
        pcall(function()
            local prop = WidgetObj[pname]
            if prop and slua.isValid(prop) then
                local hasBrush = false
                pcall(function() if prop.Brush then hasBrush = true end end)
                if hasBrush then return prop end
            end
        end)
    end
    if Depth >= MaxDepth then return nil end
    local nChildren = 0
    pcall(function() if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end end)
    for i = 0, math.max(nChildren - 1, 0) do
        local child = nil
        pcall(function() child = WidgetObj:GetChildAt(i) end)
        if child and slua.isValid(child) then
            local result = PlayerMapMarker.FindWeaponIconInWidget(child, Depth + 1, MaxDepth)
            if result then return result end
        end
    end
    if nChildren == 0 then
        local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
        if Root and slua.isValid(Root) and Root ~= WidgetObj then
            local result = PlayerMapMarker.FindWeaponIconInWidget(Root, Depth + 1, MaxDepth)
            if result then return result end
        end
    end
    return nil
end

function PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, DefaultW, DefaultH)
    if not ImageWidget or not slua.isValid(ImageWidget) then return end
    DefaultW = DefaultW or 138 ; DefaultH = DefaultH or 69
    pcall(function()
        local brush = ImageWidget.Brush
        if brush then
            brush.ImageSize = FVector2D and FVector2D(DefaultW, DefaultH) or {X=DefaultW, Y=DefaultH}
            brush.DrawAs = 3
            brush.TintColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=1,G=1,B=1,A=1}
            if ImageWidget.SetBrush then ImageWidget:SetBrush(brush) end
        end
        if ImageWidget.SetDesiredSizeOverride then ImageWidget:SetDesiredSizeOverride(FVector2D and FVector2D(DefaultW, DefaultH) or {X=DefaultW, Y=DefaultH}) end
        local slot = ImageWidget.Slot
        if slot and slot.SetSize then slot:SetSize(FVector2D and FVector2D(DefaultW, DefaultH) or {X=DefaultW, Y=DefaultH}) end
        ImageWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        ImageWidget:SetRenderOpacity(1.0)
        ImageWidget:SetColorAndOpacity(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=1,G=1,B=1,A=1})
    end)
end

function PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
    local fullIcon = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=1,G=1,B=1,A=1}
    if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then return end
    pcall(function() if ourWeaponIcon.SetRenderOpacity then ourWeaponIcon:SetRenderOpacity(1.0) end end)
    pcall(function() if ourWeaponIcon.SetColorAndOpacity then ourWeaponIcon:SetColorAndOpacity(fullIcon) end end)
    pcall(function()
        local brush = ourWeaponIcon.Brush
        if brush then pcall(function() brush.TintColor = fullIcon end) if ourWeaponIcon.SetBrush then ourWeaponIcon:SetBrush(brush) end end
    end)
    local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon", "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
    for _, pname in ipairs(chainNames) do
        pcall(function()
            local node = Container and Container[pname]
            if node and slua.isValid(node) and node.SetRenderOpacity then node:SetRenderOpacity(1.0) end
            if node and slua.isValid(node) and node.SetColorAndOpacity then node:SetColorAndOpacity(fullIcon) end
        end)
    end
end

function PlayerMapMarker.ApplyWeaponIconToImage(ImageWidget, winfo)
    if not ImageWidget or not slua.isValid(ImageWidget) then return false, "no_widget" end
    if not winfo or not winfo.WeaponID then return false, "no_weapon_id" end

    local iconPath = nil
    local method = "none"
    local bHasAddKnownMissing = false
    local defaultW = 138
    local defaultH = 69

    pcall(function()
        local itemRecord = CDataTable.GetTableData("Item", winfo.WeaponID)
        if itemRecord and itemRecord.KillWhiteIcon and itemRecord.KillWhiteIcon ~= "" then iconPath = itemRecord.KillWhiteIcon method = "KillWhiteIcon" end
        if (not iconPath or iconPath == "") and winfo.WeaponIconPath and winfo.WeaponIconPath ~= "" then iconPath = winfo.WeaponIconPath method = "WeaponIconPath" end
        if (not iconPath or iconPath == "") and winfo.WeaponIconTexture and slua.isValid(winfo.WeaponIconTexture) then
            if ImageWidget.SetBrushFromTexture then ImageWidget:SetBrushFromTexture(winfo.WeaponIconTexture, true) method = "WeaponIconTexture" return end
        end
        if not iconPath or iconPath == "" then
            local UIUtil = require("client.common.ui_util")
            iconPath, bHasAddKnownMissing = UIUtil.GetItemBigIcon(winfo.WeaponID, ImageWidget)
            if iconPath and iconPath ~= "" then method = "GetItemBigIcon" end
        end
        if not iconPath or iconPath == "" then
            local UIUtil = require("client.common.ui_util")
            iconPath = UIUtil.GetItemSmallIcon(winfo.WeaponID, ImageWidget, bHasAddKnownMissing)
            if iconPath and iconPath ~= "" then method = "GetItemSmallIcon" end
        end
    end)

    if method == "WeaponIconTexture" then PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH) return true, method end
    if not iconPath or iconPath == "" then return false, "no_path" end

    local bOK = false
    pcall(function()
        if ImageWidget.SetBrushResourceFromPathSync then ImageWidget:SetBrushResourceFromPathSync(iconPath, true) bOK = true end
        if not bOK then
            local util = require("client.slua_ui_framework.util")
            local result = util.SetTexture(ImageWidget, iconPath, { sync = true, bMatchSize = true, bIsInCombatState = true, bHasAddKnownMissing = bHasAddKnownMissing })
            bOK = result ~= nil
        end
        if not bOK then
            local tex = import(iconPath)
            if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then ImageWidget:SetBrushFromTexture(tex, true) bOK = true end
        end
        if not bOK then
            local LoadObject = import("LoadObject")
            if LoadObject then
                local tex = LoadObject(iconPath)
                if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then ImageWidget:SetBrushFromTexture(tex, true) bOK = true end
            end
        end
    end)

    if bOK then PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH) end
    return bOK, method .. ":" .. tostring(iconPath)
end

function PlayerMapMarker.CopyWeaponIconBrushFromNative(ourWeaponIcon, nativeWeaponIcon)
    if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then return false end
    if not nativeWeaponIcon or not slua.isValid(nativeWeaponIcon) then return false end

    local bCopied = false
    pcall(function()
        local nBrush = nativeWeaponIcon.Brush
        if nBrush then
            local resObj = nil
            pcall(function() resObj = nBrush.ResourceObject end)
            if resObj and slua.isValid(resObj) and ourWeaponIcon.SetBrushFromTexture then
                ourWeaponIcon:SetBrushFromTexture(resObj, true)
                bCopied = true
            end
            if bCopied then
                local imgSize = nil
                pcall(function() imgSize = nBrush.ImageSize end)
                if imgSize then
                    local oBrush = ourWeaponIcon.Brush
                    if oBrush then oBrush.ImageSize = imgSize if ourWeaponIcon.SetBrush then ourWeaponIcon:SetBrush(oBrush) end end
                end
            end
        end
    end)
    return bCopied
end

function PlayerMapMarker.AddWeaponIconToESP(WidgetData, Character)
    if not WidgetData or not WidgetData.Container then return end
    local Container = WidgetData.Container
    if not slua.isValid(Container) then return end

    if not _G.LexusConfig.Esp9_Weapon then
        pcall(function()
            local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon", "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
            for _, pname in ipairs(chainNames) do
                local node = Container[pname]
                if node and slua.isValid(node) and node.SetWidgetVisibility then node:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
            local ourWeaponIcon = Container.WeaponIcon or PlayerMapMarker.FindWeaponIconInWidget(Container, 0, 8)
            if ourWeaponIcon and slua.isValid(ourWeaponIcon) then ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        end)
        WidgetData._LastWeaponID = 0
        WidgetData._WeaponIconApplied = false
        return
    end

    pcall(function()
        local ourWeaponIcon = Container.WeaponIcon
        if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then ourWeaponIcon = PlayerMapMarker.FindWeaponIconInWidget(Container, 0, 8) end
        if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then return end

        local winfo = Character and PlayerMapMarker.GetCharacterWeaponInfo(Character) or nil

        if not winfo or not winfo.WeaponID or winfo.WeaponID == 0 then
            pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon", "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
            for _, pname in ipairs(chainNames) do
                pcall(function()
                    local node = Container and Container[pname]
                    if node and slua.isValid(node) and node.SetWidgetVisibility then node:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                end)
            end
            WidgetData._LastWeaponID = 0
            WidgetData._WeaponIconApplied = false
            return
        end

        if WidgetData._LastWeaponID == winfo.WeaponID and WidgetData._WeaponIconApplied then
            pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            pcall(function() ourWeaponIcon:SetRenderOpacity(1.0) end)
            local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon", "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
            for _, pname in ipairs(chainNames) do
                pcall(function()
                    local node = Container and Container[pname]
                    if node and slua.isValid(node) and node.SetWidgetVisibility then
                        node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                        pcall(function() if node.SetRenderOpacity then node:SetRenderOpacity(1.0) end end)
                    end
                end)
            end
            return
        end

        local chainNames = {"Border_WeaponColor", "Border_Weapon", "Border_WeaponIcon", "SizeBox_Weapon", "ScaleBox_Weapon", "Switcher_WeaponIcon"}
        for _, pname in ipairs(chainNames) do
            pcall(function()
                local node = Container and Container[pname]
                if node and slua.isValid(node) and node.SetWidgetVisibility then node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
            end)
        end

        local bCopied = false
        if winfo and winfo.WeaponID then
            local ok, method = PlayerMapMarker.ApplyWeaponIconToImage(ourWeaponIcon, winfo)
            if ok then bCopied = true end
        end

        local bWeaponIconSet = false
        if Character and winfo then
            if winfo and winfo.WeaponID then
                pcall(function() if Container.SetWeaponIcon then Container:SetWeaponIcon(winfo.WeaponID) bWeaponIconSet = true end end)
                if not bWeaponIconSet then pcall(function() if Container.SetWeaponIconByID then Container:SetWeaponIconByID(winfo.WeaponID) bWeaponIconSet = true end end) end
                if not bWeaponIconSet then pcall(function() if Container.UpdateWeaponIcon then Container:UpdateWeaponIcon(winfo.WeaponID) bWeaponIconSet = true end end) end
                if not bWeaponIconSet then pcall(function() if Container.SetWeaponID then Container:SetWeaponID(winfo.WeaponID) bWeaponIconSet = true end end) end
                pcall(function() if Container.SetData then Container:SetData(Character) end end)
                pcall(function() if Container.SetPlayerInfo then Container:SetPlayerInfo(Character) end end)
                if winfo.CurrentWeapon then pcall(function() if Container.SetCurrentWeapon then Container:SetCurrentWeapon(winfo.CurrentWeapon) end end) end
            end
        end

        if not bCopied then
            pcall(function()
                local brush = ourWeaponIcon.Brush
                if brush then
                    local resObj = nil
                    pcall(function() resObj = brush.ResourceObject end)
                    if resObj and slua.isValid(resObj) and ourWeaponIcon.SetBrushFromTexture then
                        ourWeaponIcon:SetBrushFromTexture(resObj)
                        bCopied = true
                    end
                end
            end)
        end

        if not bCopied then
            pcall(function()
                local brush = ourWeaponIcon.Brush
                if brush then
                    local imgSize = nil
                    pcall(function() imgSize = brush.ImageSize end)
                    local bZeroSize = false
                    if imgSize then
                        local sx, sy = nil, nil
                        pcall(function() sx = imgSize.X end)
                        pcall(function() sy = imgSize.Y end)
                        if (not sx or sx == 0) and (not sy or sy == 0) then bZeroSize = true end
                    end
                    if bZeroSize then
                        pcall(function() brush.ImageSize = FVector2D and FVector2D(PlayerMapMarker.WeaponIconBrushW or 138, PlayerMapMarker.WeaponIconBrushH or 69) or {X=138, Y=69} end)
                    end
                    pcall(function() brush.DrawAs = 3 end)
                    if ourWeaponIcon.SetBrush then ourWeaponIcon:SetBrush(brush) end
                end
            end)
        end

        pcall(function() ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
        PlayerMapMarker.FixWeaponIconBrushSize(ourWeaponIcon)

        pcall(function()
            local parent = ourWeaponIcon
            for depth = 0, 8 do
                pcall(function()
                    if parent.GetParent then
                        local p = parent:GetParent()
                        if p and slua.isValid(p) then
                            if p.SetWidgetVisibility then p:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
                            pcall(function() if p.SetRenderOpacity then p:SetRenderOpacity(1.0) end end)
                            pcall(function() if p.SetContentColorAndOpacity then p:SetContentColorAndOpacity(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=1,G=1,B=1,A=1}) end end)
                            pcall(function() if p.SetColorAndOpacity then p:SetColorAndOpacity(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=1,G=1,B=1,A=1}) end end)
                            pcall(function() if p.SetBrushTintColor then p:SetBrushTintColor(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=1,G=1,B=1,A=1}) end end)
                            pcall(function()
                                local pBrush = p.Brush
                                if pBrush and pBrush.TintColor then
                                    pBrush.TintColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=1,G=1,B=1,A=1}
                                    if p.SetBrush then p:SetBrush(pBrush) end
                                end
                            end)
                            pcall(function() if p.InvalidateLayout then p:InvalidateLayout() end end)
                            parent = p
                        end
                    end
                end)
            end
        end)
        pcall(function() if ourWeaponIcon.InvalidateLayout then ourWeaponIcon:InvalidateLayout() end end)

        pcall(function() if Container.UpdateWeapon then Container:UpdateWeapon() end end)
        pcall(function() if Container.RefreshWeapon then Container:RefreshWeapon() end end)
        
        WidgetData._LastWeaponID = winfo.WeaponID
        WidgetData._WeaponIconApplied = true
    end)
end

PlayerMapMarker._OBHeadWidgetClass = nil
PlayerMapMarker._OBHeadWidgetLoadFailed = false
PlayerMapMarker._bDumpedWidgetChildren = false

function PlayerMapMarker.CreateESPWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    if PlayerMapMarker._OBHeadWidgetLoadFailed then return nil end

    if not PlayerMapMarker._OBHeadWidgetClass then
        pcall(function()
            local Path = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP"
            local uClass = slua.loadClass(Path)
            if uClass then PlayerMapMarker._OBHeadWidgetClass = uClass end
        end)
        if not PlayerMapMarker._OBHeadWidgetClass then
            PlayerMapMarker._OBHeadWidgetLoadFailed = true
            return nil
        end
    else
        local bValid = false
        pcall(function() bValid = slua.isValid(PlayerMapMarker._OBHeadWidgetClass) end)
        if not bValid then
            PlayerMapMarker._OBHeadWidgetLoadFailed = true
            PlayerMapMarker._OBHeadWidgetClass = nil
            return nil
        end
    end

    local Widget = nil
    pcall(function()
        local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
        local PC = PlayerMapMarker.GetMyPlayerController()
        local OuterObj = IsValid(PC) and PC.Object or PlayerMapMarker.ESPCanvas
        Widget = STExtraBlueprintFunctionLibrary.CreateWidgetByClass(PlayerMapMarker._OBHeadWidgetClass, OuterObj)
    end)

    if not Widget then return nil end

    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Widget:SetRenderOpacity(1.0) end)

    local NameText = nil
    local HealthFill = nil
    local bIsOriginalProgressBar = false

    pcall(function()
        NameText = Widget.TextBlock_TeamName
        if NameText and slua.isValid(NameText) then pcall(function() NameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end) end
        if Widget.TextBlock_PlayerName and slua.isValid(Widget.TextBlock_PlayerName) then pcall(function() Widget.TextBlock_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end) end

        local WS_Type = Widget.WidgetSwitcher_Type
        local WS_Type2 = Widget.WidgetSwitcher_Type2
        
        -- ✅ FIX: Initially set visibility based on ESP_HP toggle state
        local bShowHP = _G.AK_GetVal("ESP_HP") == 1
        
        if WS_Type and slua.isValid(WS_Type) then 
            pcall(function() 
                if WS_Type.SetActiveWidgetIndex then 
                    WS_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex) 
                end
                if bShowHP then
                    WS_Type:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                else
                    WS_Type:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end
            end) 
        end
        if WS_Type2 and slua.isValid(WS_Type2) then 
            pcall(function() 
                if WS_Type2.SetActiveWidgetIndex then 
                    WS_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index) 
                end
                if bShowHP then
                    WS_Type2:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                else
                    WS_Type2:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end
            end) 
        end

        local SizeBox_HP = Widget.SizeBox_HP
        if SizeBox_HP and slua.isValid(SizeBox_HP) then
            -- ✅ FIX: Initially hidden if HP toggle OFF
            if bShowHP then
                pcall(function() SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            else
                pcall(function() SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
            pcall(function() SizeBox_HP:SetHeightOverride(6) end)
            pcall(function() SizeBox_HP:SetWidthOverride(100) end)

            local ExistingChild = nil
            pcall(function() if SizeBox_HP.GetContent then ExistingChild = SizeBox_HP:GetContent() end end)
            if not ExistingChild then pcall(function() if SizeBox_HP.GetChildAt then ExistingChild = SizeBox_HP:GetChildAt(0) end end) end

            if ExistingChild and slua.isValid(ExistingChild) then
                pcall(function() ExistingChild:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                pcall(function() ExistingChild:SetRenderOpacity(1.0) end)

                local FoundPB = PlayerMapMarker.FindProgressBarInWidget(ExistingChild, 0, 5)
                if FoundPB and slua.isValid(FoundPB) then
                    HealthFill = FoundPB
                    bIsOriginalProgressBar = true
                    pcall(function() FoundPB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    pcall(function() FoundPB:SetRenderOpacity(1.0) end)
                else
                    local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", ExistingChild)
                    if PB then
                        pcall(function() PB:SetFillColorAndOpacity(FLinearColor and FLinearColor(1, 1, 1, 1) or {R=1,G=1,B=1,A=1}) end)
                        pcall(function() PB:SetPercent(1.0) end)
                        pcall(function() PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        pcall(function() PB:SetRenderOpacity(1.0) end)
                        pcall(function() PB:SetDesiredSizeOverride(FVector2D and FVector2D(100, 6) or {X=100, Y=6}) end)
                        pcall(function() ExistingChild:AddChild(PB) end)
                        HealthFill = PB
                    end
                end
            else
                local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", SizeBox_HP)
                if PB then
                    pcall(function() PB:SetFillColorAndOpacity(FLinearColor and FLinearColor(1, 1, 1, 1) or {R=1,G=1,B=1,A=1}) end)
                    pcall(function() PB:SetPercent(1.0) end)
                    pcall(function() PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    pcall(function() PB:SetRenderOpacity(1.0) end)
                    pcall(function() PB:SetDesiredSizeOverride(FVector2D and FVector2D(100, 6) or {X=100, Y=6}) end)

                    local bUsedSetContent = false
                    pcall(function() if SizeBox_HP.SetContent then SizeBox_HP:SetContent(PB) bUsedSetContent = true end end)
                    if not bUsedSetContent then pcall(function() SizeBox_HP:AddChild(PB) end) end
                    HealthFill = PB
                end
            end
        end
    end)

    local WidgetData = {
        Container = Widget,
        NameText = NameText,
        HealthFill = HealthFill,
        IsGameWidget = true,
        IsOriginalProgressBar = bIsOriginalProgressBar,
        HasChildren = (NameText ~= nil)
    }
    return WidgetData
end

PlayerMapMarker._CanvasScaleX = 1.0
PlayerMapMarker._CanvasScaleY = 1.0
PlayerMapMarker._CanvasOffsetX = 0.0
PlayerMapMarker._CanvasOffsetY = 0.0

function PlayerMapMarker.UpdateCanvasTransform(PC)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local success = false
    pcall(function()
        local SBL = SlateBlueprintLibrary
        if SBL and SBL.AbsoluteToLocal then
            local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
            if cg then
                local pt0 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(0, 0) or {X=0, Y=0})
                local pt1 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(100, 100) or {X=100, Y=100})
                if pt0 and pt1 then
                    PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                    PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                    PlayerMapMarker._CanvasOffsetX = pt0.X
                    PlayerMapMarker._CanvasOffsetY = pt0.Y
                    success = true
                end
            end
        end
    end)

    if not success then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.ScreenToWidgetLocal then
                local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
                if cg then
                    local pt0 = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
                    local pt1 = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
                    WLL.ScreenToWidgetLocal(PC, cg, FVector2D and FVector2D(0, 0) or {X=0, Y=0}, pt0)
                    WLL.ScreenToWidgetLocal(PC, cg, FVector2D and FVector2D(100, 100) or {X=100, Y=100}, pt1)
                    PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                    PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                    PlayerMapMarker._CanvasOffsetX = pt0.X
                    PlayerMapMarker._CanvasOffsetY = pt0.Y
                    success = true
                end
            end
        end)
    end

    if not success then
        local scale = 1.0
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then scale = WLL.GetViewportScale(PC) or 1.0 end
        PlayerMapMarker._CanvasScaleX = 1.0 / scale
        PlayerMapMarker._CanvasScaleY = 1.0 / scale
        PlayerMapMarker._CanvasOffsetX = 0
        PlayerMapMarker._CanvasOffsetY = 0
    end
end

function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
    if not ScreenPixelPos then return FVector2D and FVector2D(0, 0) or {X=0, Y=0} end
    local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
    local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
    local offsetX = PlayerMapMarker._CanvasOffsetX or 0
    local offsetY = PlayerMapMarker._CanvasOffsetY or 0
    return (FVector2D and FVector2D(ScreenPixelPos.X * scaleX + offsetX, ScreenPixelPos.Y * scaleY + offsetY)) or {X = ScreenPixelPos.X * scaleX + offsetX, Y = ScreenPixelPos.Y * scaleY + offsetY}
end

function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    if not IsValid(PC) or not WorldLoc then return false, (FVector2D and FVector2D(0, 0) or {X=0, Y=0}) end
    local ScreenPixelPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, ScreenPixelPos, true)
        if res == true or res == 1 or (ScreenPixelPos and (ScreenPixelPos.X ~= 0 or ScreenPixelPos.Y ~= 0)) then bOK = true end
    end)
    if not bOK or not ScreenPixelPos or (ScreenPixelPos.X == 0 and ScreenPixelPos.Y == 0) then return false, (FVector2D and FVector2D(0, 0) or {X=0, Y=0}) end
    local CanvasLocalPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
    return true, CanvasLocalPos
end

function PlayerMapMarker.GetDynamicViewportSize(PC)
    local width, height = 0, 0
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
        pcall(function()
            local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
            if cg and cg.GetLocalSize then
                local sz = cg:GetLocalSize()
                if sz and sz.X and sz.X > 200 then width = sz.X height = sz.Y end
            end
        end)
    end
    if width > 200 then return width, height end
    pcall(function()
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportSize then
            local sz = WLL.GetViewportSize(PC or PlayerMapMarker.GetMyPlayerController())
            if sz and sz.X and sz.X > 200 then width = sz.X height = sz.Y end
        end
    end)
    if width > 200 then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportScale then
                local scale = WLL.GetViewportScale(PC or PlayerMapMarker.GetMyPlayerController())
                if scale and type(scale) == "number" and scale > 0 and scale ~= 1.0 then width = width / scale height = height / scale end
            end
        end)
        return width, height
    end
    return PlayerMapMarker._cachedViewportW or 1920, PlayerMapMarker._cachedViewportH or 1080
end

function PlayerMapMarker.UpdateESPPositionWithPC(Widget, WorldLoc, PC, CanvasPos)
    if not Widget or not IsValid(PC) then return false end
    local Container = Widget.Container or Widget
    local bOnScreen = true
    if not CanvasPos then
        if not WorldLoc then return false end
        bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    end

    if not bOnScreen then pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) return false end

    pcall(function()
        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            local ptr = tostring(Container)
            local Slot = PlayerMapMarker.ESPWidgetPtrs[ptr]

            if not Slot or not slua.isValid(Slot) or type(Slot) == "boolean" then
                local addedSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Container)
                if addedSlot and slua.isValid(addedSlot) then
                    Slot = addedSlot
                    PlayerMapMarker.ESPWidgetPtrs[ptr] = addedSlot
                    if type(Widget) == "table" then Widget.Slot = addedSlot end
                    pcall(function() Slot:SetAutoSize(true) end)
                    pcall(function() Slot.bAutoSize = true end)
                    local align = FVector2D and FVector2D(0.5, 1.0) or {X=0.5, Y=1.0}
                    pcall(function() Slot.Alignment = align end)
                    pcall(function() Slot:SetAlignment(align) end)
                    pcall(function() Slot:SetAlignment(0.5, 1.0) end)
                    pcall(function() Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 20) end)
                end
            end

            local bShowAnyUI = _G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP or _G.LexusConfig.Esp9_Team or _G.LexusConfig.Esp9_Weapon
            if _G.AK_GetVal("ESP_BOX") ~= 1 then bShowAnyUI = false end
            
            if bShowAnyUI then
                Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            else
                Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
            
            if not Widget._OffsetResetDone then
                pcall(function() Container:SetRenderTranslation(FVector2D and FVector2D(0.0, 0.0) or {X=0, Y=0}) end)
                pcall(function() Container:SetRenderScale(FVector2D and FVector2D(0.90, 0.90) or {X=0.90, Y=0.90}) end)
                if Widget and type(Widget) == "table" then
                    if Widget.NameText and slua.isValid(Widget.NameText) then pcall(function() Widget.NameText:SetRenderTranslation(FVector2D and FVector2D(0.0, 0.0) or {X=0, Y=0}) end) end
                    if Widget.HealthFill and slua.isValid(Widget.HealthFill) then pcall(function() Widget.HealthFill:SetRenderTranslation(FVector2D and FVector2D(0.0, 0.0) or {X=0, Y=0}) end) end
                end
                pcall(function() Container.RenderTransformPivot = FVector2D and FVector2D(0.5, 1.0) or {X=0.5, Y=1.0} end)
                pcall(function() Container:SetRenderTransformPivot(FVector2D and FVector2D(0.5, 1.0) or {X=0.5, Y=1.0}) end)
                Widget._OffsetResetDone = true
            end

            if not Slot or not slua.isValid(Slot) or Slot == PlayerMapMarker.ESPCanvas then
                if Widget and type(Widget) == "table" and Widget.Slot and slua.isValid(Widget.Slot) then Slot = Widget.Slot
                elseif Container.Slot and slua.isValid(Container.Slot) then Slot = Container.Slot end
            end

            if Slot and slua.isValid(Slot) and Slot ~= PlayerMapMarker.ESPCanvas then
                local finalX = CanvasPos.X + (PlayerMapMarker.ESPAnchorOffsetX or 0)
                local finalY = CanvasPos.Y + (PlayerMapMarker.ESPAnchorOffsetY or 0)
                if Widget and type(Widget) == "table" then
                    if not Widget._CachedPosVec then Widget._CachedPosVec = FVector2D and FVector2D(finalX, finalY) or {X=finalX, Y=finalY}
                    else Widget._CachedPosVec.X = finalX Widget._CachedPosVec.Y = finalY end
                    pcall(function() Slot:SetPosition(Widget._CachedPosVec) end)
                else
                    pcall(function() Slot:SetPosition(FVector2D and FVector2D(finalX, finalY) or {X=finalX, Y=finalY}) end)
                end
            end
        end
    end)
    return true
end

function PlayerMapMarker.UpdateESPText(Widget, Text)
    if not Widget then return end
    if Widget._LastESPText == Text then return end
    Widget._LastESPText = Text

    local function applyTextAndCenter(w, txt)
        if not w or not slua.isValid(w) then return end
        
        if txt == "" then
            pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            return
        else
            pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        end

        pcall(function() w:SetText(txt) end)
        pcall(function()
            local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
            local orangeColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=255, G=255, B=255, A=255}
            if w.SetColorAndOpacity then
                if FSlateColor then w:SetColorAndOpacity(FSlateColor(orangeColor)) else w:SetColorAndOpacity(orangeColor) end
            end
        end)
        pcall(function() if w.SetJustification then w:SetJustification(1) end end)
        pcall(function() local slot = w.Slot if slot and slot.SetHorizontalAlignment then slot:SetHorizontalAlignment(1) end end)
        pcall(function() w:SetRenderTranslation(FVector2D and FVector2D(PlayerMapMarker.ESPTextOffsetX or 0, PlayerMapMarker.ESPTextOffsetY or 0) or {X=PlayerMapMarker.ESPTextOffsetX or 0, Y=PlayerMapMarker.ESPTextOffsetY or 0}) end)
    end

    if Widget.NameText and slua.isValid(Widget.NameText) then applyTextAndCenter(Widget.NameText, Text) end
    if Widget.IsGameWidget and Widget.Container then
        pcall(function()
            local W = Widget.Container
            if W and slua.isValid(W) then
                if W.SetPlayerName then
                    local Name = Text
                    local idx = string.find(Text, " %[")
                    if idx then Name = string.sub(Text, 1, idx - 1) end
                    W:SetPlayerName(Name)
                end
                applyTextAndCenter(W.TextBlock_TeamName, Text)
                applyTextAndCenter(W.TextBlock_PlayerName, Text)

                pcall(function()
                    if not Widget._CachedVBChildren then
                        local list = {}
                        local VB = PlayerMapMarker._FindNamedWidgetInTree(W, "VerticalBox_0", 8)
                        if VB and slua.isValid(VB) and VB.GetChildrenCount then
                            local nChildren = VB:GetChildrenCount()
                            for i = 0, nChildren - 1 do
                                local child = VB:GetChildAt(i)
                                if child and slua.isValid(child) and child.SetText then table_insert(list, child) end
                            end
                        end
                        Widget._CachedVBChildren = list
                    end
                    for _, child in ipairs(Widget._CachedVBChildren) do applyTextAndCenter(child, Text) end
                end)

                pcall(function()
                    if not Widget._CachedHBChildren then
                        local list = {}
                        local HB = PlayerMapMarker._FindNamedWidgetInTree(W, "HorizontalBox_TeamName", 8)
                        if HB and slua.isValid(HB) and HB.GetChildrenCount then
                            local nChildren = HB:GetChildrenCount()
                            for i = 0, nChildren - 1 do
                                local child = HB:GetChildAt(i)
                                if child and slua.isValid(child) and child.SetText then table_insert(list, child) end
                            end
                        end
                        Widget._CachedHBChildren = list
                    end
                    for _, child in ipairs(Widget._CachedHBChildren) do applyTextAndCenter(child, Text) end
                end)
            end
        end)
    end
end

-- ✅✅✅ FULLY FIXED: UpdateESPHealth with complete ON/OFF handling
function PlayerMapMarker.UpdateESPHealth(Widget, pct)
    if not Widget then return end
    Widget.LastPct = pct

    local bShowHP = _G.AK_GetVal("ESP_HP") == 1

    -- ✅ FIX: Force refresh when toggle state changes
    if Widget._LastHPVisibleState ~= bShowHP then
        Widget._LastHPVisibleState = bShowHP

        -- ✅ Handle ALL HP-related widgets in Container
        if Widget.Container and slua.isValid(Widget.Container) then
            pcall(function()
                local W = Widget.Container
                if not W then return end
                
                -- ✅ WidgetSwitcher_Type - Hide/Show
                if W.WidgetSwitcher_Type and slua.isValid(W.WidgetSwitcher_Type) then
                    if bShowHP then
                        if W.WidgetSwitcher_Type.SetActiveWidgetIndex then
                            W.WidgetSwitcher_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex)
                        end
                        W.WidgetSwitcher_Type:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    else
                        W.WidgetSwitcher_Type:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
                
                -- ✅ WidgetSwitcher_Type2 - Hide/Show
                if W.WidgetSwitcher_Type2 and slua.isValid(W.WidgetSwitcher_Type2) then
                    if bShowHP then
                        if W.WidgetSwitcher_Type2.SetActiveWidgetIndex then
                            W.WidgetSwitcher_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index)
                        end
                        W.WidgetSwitcher_Type2:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    else
                        W.WidgetSwitcher_Type2:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
                
                -- ✅ SizeBox_HP - Hide/Show
                if W.SizeBox_HP and slua.isValid(W.SizeBox_HP) then 
                    if bShowHP then
                        W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                    else
                        W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
                
                -- ✅ Also hide any ProgressBar found when OFF
                if not bShowHP then
                    local PB = PlayerMapMarker.FindProgressBarInWidget(W, 0, 5)
                    if PB and slua.isValid(PB) then
                        PB:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end)
        end

        -- ✅ HealthFill visibility
        if Widget.HealthFill and slua.isValid(Widget.HealthFill) then
            if bShowHP then
                pcall(function() Widget.HealthFill:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            else
                pcall(function() Widget.HealthFill:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end

        -- ✅ IsGameWidget container's SizeBox_HP
        if Widget.IsGameWidget and Widget.Container and slua.isValid(Widget.Container) then
            local W = Widget.Container
            if W.SizeBox_HP and slua.isValid(W.SizeBox_HP) then
                if bShowHP then
                    W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                else
                    W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end
            end
        end
    end

    -- ✅ If HP is OFF, return early - no need to update percent
    if not bShowHP then return end

    -- ✅ Update HealthFill percent only if visible
    if Widget.HealthFill then
        local bValid = false
        pcall(function() bValid = slua.isValid(Widget.HealthFill) end)
        if bValid then
            local bHasSetPercent = false
            pcall(function() bHasSetPercent = (Widget.HealthFill.SetPercent ~= nil) end)
            if not bHasSetPercent then
                local PB = PlayerMapMarker.FindProgressBarInWidget(Widget.HealthFill, 0, 5)
                if PB and slua.isValid(PB) then Widget.HealthFill = PB else return end
            end

            pcall(function()
                if Widget.HealthFill.SetWidgetVisibility then 
                    Widget.HealthFill:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) 
                end
                if Widget.HealthFill.SetRenderOpacity then 
                    Widget.HealthFill:SetRenderOpacity(1.0) 
                end
                if Widget.HealthFill.SetPercent then
                    Widget.HealthFill:SetPercent(pct)
                    
                    local color = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {R=255,G=255,B=255,A=255}
                    
                    if Widget.HealthFill.SetFillColorAndOpacity then 
                        Widget.HealthFill:SetFillColorAndOpacity(color) 
                    end
                    
                    pcall(function()
                        if Widget.IsOriginalProgressBar then
                            local style = Widget.HealthFill.WidgetStyle
                            if style and style.FillImage then
                                style.FillImage.TintColor = color
                                Widget.HealthFill:SetWidgetStyle(style)
                            end
                        end
                    end)
                end
            end)
        end
    end
end

function PlayerMapMarker.RemoveESPWidget(Widget, KeyStr)
    if not Widget then return end
    local Container = Widget.Container or Widget
    pcall(function()
        local ptr = tostring(Container)
        PlayerMapMarker.ESPWidgetPtrs[ptr] = nil
        Container:RemoveFromParent()
        Container:ConditionalBeginDestroy()
    end)
    if KeyStr then
        PlayerMapMarker.RemoveSnapLine(KeyStr)
        if PlayerMapMarker.RemoveSkeletonLines then
            PlayerMapMarker.RemoveSkeletonLines(KeyStr)
        end
    end
end

function PlayerMapMarker.CreateSnapLine()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end

    local color = PlayerMapMarker.SnapLineColor or (FLinearColor and FLinearColor(1.0, 1.0, 1.0, PlayerMapMarker.SnapLineOpacity or 0.9) or {R=1,G=1,B=1,A=PlayerMapMarker.SnapLineOpacity or 0.9})
    pcall(function() Border:SetBrushColor(color) end)
    pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5} end)
    pcall(function() Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5}) end)

    local Slot = nil
    pcall(function()
        Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
        if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(1) end
    end)
    return { Widget = Border, Slot = Slot }
end

function PlayerMapMarker.GetSnapLineStartPos(PC)
    local screenPixelW, screenPixelH = 0, 0
    local scale = 1.0

    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D and FVector2D(0, 0) or {X=0,Y=0}
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
        end
    end)
    if screenPixelW <= 200 then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local vs = WLL.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
            end
        end)
    end
    pcall(function()
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then
            local s = WLL.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then scale = s end
        end
    end)
    if screenPixelW <= 200 then
        screenPixelW = (PlayerMapMarker._cachedViewportW or 1920) * scale
        screenPixelH = (PlayerMapMarker._cachedViewportH or 1080) * scale
    end

    if not PlayerMapMarker._CachedTopCenterPixel then PlayerMapMarker._CachedTopCenterPixel = FVector2D and FVector2D(0, 0) or {X=0,Y=0} end
    PlayerMapMarker._CachedTopCenterPixel.X = screenPixelW / 2.0
    PlayerMapMarker._CachedTopCenterPixel.Y = (PlayerMapMarker.SnapLineOriginY or 50) * scale

    local fromCanvasPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
    local fromX = fromCanvasPos.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0)
    local fromY = fromCanvasPos.Y

    return fromX, fromY
end

function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
    if not PlayerMapMarker.bUseSnapLines then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]

    if not bOnScreen or not CanvasPos then
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end

    local bIsNew = false
    if not LineData then
        LineData = PlayerMapMarker.CreateSnapLine()
        if not LineData or not LineData.Widget or not LineData.Slot then return end
        PlayerMapMarker.SnapLineWidgets[KeyStr] = LineData
        bIsNew = true
    end

    local Widget = LineData.Widget
    local Slot = LineData.Slot

    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    
    if not LineData._PivotSet then
        pcall(function() Widget.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5} end)
        pcall(function() Widget:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5}) end)
        LineData._PivotSet = true
    end

    local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
    local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)
    local dx = toX - fromX
    local dy = toY - fromY
    local length = math_sqrt(dx * dx + dy * dy)
    local thickness = PlayerMapMarker.SnapLineThickness or 1.65

    local angle_rad = 0
    if math_atan2 then angle_rad = math_atan2(dy, dx) else angle_rad = math.atan(dy, dx) end
    local angle = angle_rad * (180.0 / math.pi)

    if not LineData._CachedPosVec then
        LineData._CachedPosVec = FVector2D and FVector2D(fromX, fromY - thickness / 2.0) or {X=fromX, Y=fromY - thickness / 2.0}
        LineData._CachedSizeVec = FVector2D and FVector2D(length, thickness) or {X=length, Y=thickness}
    else
        LineData._CachedPosVec.X = fromX ; LineData._CachedPosVec.Y = fromY - thickness / 2.0
        LineData._CachedSizeVec.X = length ; LineData._CachedSizeVec.Y = thickness
    end

    pcall(function() 
        Slot:SetPosition(LineData._CachedPosVec) 
        Slot:SetSize(LineData._CachedSizeVec)
        if bIsNew then Slot:SetZOrder(1) end
    end)
    pcall(function() Widget:SetRenderAngle(angle) end)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
        pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllSnapLines()
    for KeyStr, LineData in pairs(PlayerMapMarker.SnapLineWidgets) do
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        end
    end
    PlayerMapMarker.SnapLineWidgets = {}
end

function PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, screenX, screenY)
    local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
    local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
    local offsetX = PlayerMapMarker._CanvasOffsetX or 0
    local offsetY = PlayerMapMarker._CanvasOffsetY or 0
    return screenX * scaleX + offsetX, screenY * scaleY + offsetY
end

function PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, WorldLoc)
    if not IsValid(PC) or not WorldLoc then return false, 0, 0 end
    if not PlayerMapMarker._tempScreenPixelPos then
        PlayerMapMarker._tempScreenPixelPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
    end
    local tempPos = PlayerMapMarker._tempScreenPixelPos
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, tempPos, true)
        if res == true or res == 1 then bOK = true end
    end)
    if not bOK or (tempPos.X == 0 and tempPos.Y == 0) then return false, 0, 0 end
    local canvasX, canvasY = PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, tempPos.X, tempPos.Y)
    return true, canvasX, canvasY
end

function PlayerMapMarker.GetBoneLocationWithFallback(Character, PrimaryBoneName)
    if not IsValid(Character) or not PrimaryBoneName then return nil end
    if Character._cachedBoneNames and Character._cachedBoneNames[PrimaryBoneName] then
        local cachedName = Character._cachedBoneNames[PrimaryBoneName]
        local loc = nil
        pcall(function()
            local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
            if Mesh and Game:IsValid(Mesh) then
                if Mesh.GetSocketLocation then loc = Mesh:GetSocketLocation(cachedName)
                elseif Mesh.GetBoneLocation then loc = Mesh:GetBoneLocation(cachedName) end
            end
        end)
        if loc then return loc end
    end
    local fallbacks = PlayerMapMarker.BoneNameFallbacks[PrimaryBoneName] or {PrimaryBoneName}
    for _, bname in ipairs(fallbacks) do
        local loc = nil
        pcall(function()
            local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
            if Mesh and Game:IsValid(Mesh) then
                if Mesh.GetSocketLocation then loc = Mesh:GetSocketLocation(bname)
                elseif Mesh.GetBoneLocation then loc = Mesh:GetBoneLocation(bname) end
            end
        end)
        if loc then
            if not Character._cachedBoneNames then Character._cachedBoneNames = {} end
            Character._cachedBoneNames[PrimaryBoneName] = bname
            return loc
        end
    end
    return nil
end

function PlayerMapMarker.IsPlayerVisible(PC, Character)
    if not IsValid(PC) or not IsValid(Character) then return false end
    local now = os_clock()
    if Character._lastVisTime and (now - Character._lastVisTime) < 0.15 then
        return Character._cachedIsVisible or false
    end
    Character._lastVisTime = now
    local bVis = false
    pcall(function()
        if PC.LineOfSightTo then
            if not PlayerMapMarker._ZeroVector then
                local VT = FVector or import("/Script/CoreUObject.Vector")
                if VT then PlayerMapMarker._ZeroVector = VT(0, 0, 0) end
            end
            bVis = PC:LineOfSightTo(Character, PlayerMapMarker._ZeroVector, false)
        end
    end)
    if not bVis then
        local KSL = import("KismetSystemLibrary")
        if KSL and KSL.LineTraceSingle then
            pcall(function()
                local camMgr = nil
                local GS = import("GameplayStatics")
                if GS and GS.GetPlayerCameraManager then
                    camMgr = GS.GetPlayerCameraManager(PC, 0)
                end
                local startLoc = camMgr and camMgr:GetCameraLocation() or PlayerMapMarker.GetMyLocation()
                local headLoc = PlayerMapMarker.GetBoneLocationWithFallback(Character, "head")
                if startLoc and headLoc then
                    if not PlayerMapMarker._CachedHitResult then
                        local HitResultClass = import("HitResult") or import("/Script/Engine.HitResult")
                        PlayerMapMarker._CachedHitResult = HitResultClass and HitResultClass() or {}
                    end
                    local bHit = KSL.LineTraceSingle(PC, startLoc, headLoc, 0, false, nil, 0, PlayerMapMarker._CachedHitResult, true)
                    if bHit then
                        local hitActor = nil
                        if type(PlayerMapMarker._CachedHitResult.GetActor) == "function" then hitActor = PlayerMapMarker._CachedHitResult:GetActor()
                        elseif PlayerMapMarker._CachedHitResult.Actor then hitActor = PlayerMapMarker._CachedHitResult.Actor end
                        if hitActor and (hitActor == Character or (type(hitActor.IsChildOf) == "function" and hitActor:IsChildOf(Character))) then
                            bVis = true
                        end
                    else
                        bVis = true
                    end
                end
            end)
        end
    end
    Character._cachedIsVisible = bVis
    return bVis
end

function PlayerMapMarker.CreateSkeletonLineWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end
    pcall(function() Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5} end)
    pcall(function() Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5}) end)
    local Slot = nil
    pcall(function()
        Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
        if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(5) end
    end)
    return { 
        Widget = Border, Slot = Slot,
        posVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0},
        sizeVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0},
        lastFromX = -99999, lastFromY = -99999,
        lastToX = -99999, lastToY = -99999
    }
end

function PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, bVisible, TeamColor, bPlayerOnScreen, charLoc)
    if not PlayerMapMarker.bUseSkeleton then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local PlayerBones = PlayerMapMarker.SkeletonWidgets[KeyStr]
    if not bVisible or not IsValid(Character) or not IsValid(PC) then
        if PlayerBones then
            for _, LineData in ipairs(PlayerBones) do
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                    LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    LineData.Widget._isSelfHitTestVisible = false
                end
            end
        end
        return
    end

    if not charLoc then charLoc = PlayerMapMarker.GetESPLocation(Character) end
    if not charLoc then return end

    if bPlayerOnScreen == nil then
        local bOnScreen, _, _ = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, charLoc)
        bPlayerOnScreen = bOnScreen
    end
    if not bPlayerOnScreen then
        if PlayerBones then
            for _, LineData in ipairs(PlayerBones) do
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                    LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    LineData.Widget._isSelfHitTestVisible = false
                end
            end
        end
        return
    end

    local dist = 0
    local myLoc = PlayerMapMarker._CachedMyLoc or PlayerMapMarker.GetMyLocation()
    if myLoc and charLoc then
        local dx = (charLoc.X or 0) - (myLoc.X or 0)
        local dy = (charLoc.Y or 0) - (myLoc.Y or 0)
        local dz = (charLoc.Z or 0) - (myLoc.Z or 0)
        dist = math_sqrt(dx * dx + dy * dy + dz * dz)
    end

    if PlayerMapMarker.SkeletonMaxDistance and PlayerMapMarker.SkeletonMaxDistance > 0 then
        if dist > PlayerMapMarker.SkeletonMaxDistance then
            if PlayerBones then
                for _, LineData in ipairs(PlayerBones) do
                    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                        LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        LineData.Widget._isSelfHitTestVisible = false
                    end
                end
            end
            return
        end
    end

    if not PlayerBones then
        PlayerBones = {}
        PlayerMapMarker.SkeletonWidgets[KeyStr] = PlayerBones
    end

    local lineColor = nil
    if PlayerMapMarker.bUseVisibilityColor then
        lineColor = FLinearColor(1.0, 1.0, 1.0, 0.9)
    else
        lineColor = FLinearColor(1.0, 1.0, 1.0, PlayerMapMarker.SkeletonOpacity or 0.9)
    end

    local cache = PlayerMapMarker._StaticBoneLocCache
    for k in pairs(cache) do cache[k] = nil end
    local lineIndex = 0
    local thickness = PlayerMapMarker.SkeletonThickness or 1.32
    if not Character._cachedBones3D then Character._cachedBones3D = {} end

    for _, chain in ipairs(PlayerMapMarker.SkeletonChains) do
        local lastCanvasX, lastCanvasY = nil, nil
        for _, boneName in ipairs(chain) do
            local boneWorldLoc = cache[boneName]
            if boneWorldLoc == nil then
                boneWorldLoc = PlayerMapMarker.GetBoneLocationWithFallback(Character, boneName) or false
                cache[boneName] = boneWorldLoc
            end
            if boneWorldLoc == false then boneWorldLoc = nil end

            local currentCanvasX, currentCanvasY = nil, nil
            if boneWorldLoc then
                local bOnScreen, cX, cY = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, boneWorldLoc)
                if bOnScreen then
                    currentCanvasX = cX
                    currentCanvasY = cY
                end
            end

            if lastCanvasX and currentCanvasX then
                lineIndex = lineIndex + 1
                local LineData = PlayerBones[lineIndex]
                if not LineData or not LineData.Widget or not slua.isValid(LineData.Widget) then
                    LineData = PlayerMapMarker.CreateSkeletonLineWidget()
                    if LineData then PlayerBones[lineIndex] = LineData end
                end

                if LineData and LineData.Widget and LineData.Slot then
                    local Widget = LineData.Widget
                    local Slot = LineData.Slot

                    if Widget._cachedColor ~= lineColor then
                        Widget:SetBrushColor(lineColor)
                        Widget._cachedColor = lineColor
                    end
                    if not Widget._isSelfHitTestVisible then
                        Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                        Widget._isSelfHitTestVisible = true
                    end

                    local fromX = lastCanvasX
                    local fromY = lastCanvasY
                    local toX = currentCanvasX
                    local toY = currentCanvasY

                    local threshold = 0.15
                    if dist > 8000 then threshold = 0.8 elseif dist > 4000 then threshold = 0.4 end

                    if math_abs(fromX - LineData.lastFromX) > threshold or
                       math_abs(fromY - LineData.lastFromY) > threshold or
                       math_abs(toX - LineData.lastToX) > threshold or
                       math_abs(toY - LineData.lastToY) > threshold then

                        LineData.lastFromX = fromX
                        LineData.lastFromY = fromY
                        LineData.lastToX = toX
                        LineData.lastToY = toY

                        local dx = toX - fromX
                        local dy = toY - fromY
                        local length = math_sqrt(dx * dx + dy * dy)
                        local angle_rad = (math_atan2 and math_atan2(dy, dx)) or math.atan(dy, dx)
                        local angle = angle_rad * 57.29577951308232

                        local pVec = LineData.posVec
                        pVec.X = fromX ; pVec.Y = fromY - thickness / 2.0
                        Slot:SetPosition(pVec)

                        local sVec = LineData.sizeVec
                        sVec.X = length ; sVec.Y = thickness
                        Slot:SetSize(sVec)
                        Widget:SetRenderAngle(angle)
                    end
                end
            end
            lastCanvasX = currentCanvasX
            lastCanvasY = currentCanvasY
        end
    end

    for i = lineIndex + 1, #PlayerBones do
        local LineData = PlayerBones[i]
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            LineData.Widget._isSelfHitTestVisible = false
        end
    end
end

function PlayerMapMarker.RemoveSkeletonLines(KeyStr)
    local PlayerBones = PlayerMapMarker.SkeletonWidgets[KeyStr]
    if PlayerBones then
        for _, LineData in ipairs(PlayerBones) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function()
                    LineData.Widget:RemoveFromParent()
                    LineData.Widget:ConditionalBeginDestroy()
                end)
            end
        end
        PlayerMapMarker.SkeletonWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllSkeletonLines()
    for KeyStr, PlayerBones in pairs(PlayerMapMarker.SkeletonWidgets) do
        for _, LineData in ipairs(PlayerBones) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function()
                    LineData.Widget:RemoveFromParent()
                    LineData.Widget:ConditionalBeginDestroy()
                end)
            end
        end
    end
    PlayerMapMarker.SkeletonWidgets = {}
end

function PlayerMapMarker.ClearAllESP()
    RedBoxOverlay.Stop()
    for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
        PlayerMapMarker.RemoveESPWidget(Data.Widget, KeyStr)
    end
    PlayerMapMarker.ESPWidgets = {}
    PlayerMapMarker.ESPWidgetPtrs = {}
    PlayerMapMarker.ClearAllSnapLines()
    PlayerMapMarker.ClearAllSkeletonLines()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
        pcall(function()
            local n = PlayerMapMarker.ESPCanvas:GetChildrenCount()
            for i = n - 1, 0, -1 do
                local child = PlayerMapMarker.ESPCanvas:GetChildAt(i)
                if child and slua.isValid(child) then
                    if PlayerMapMarker.IsOurESPWidget(child) then PlayerMapMarker.ESPCanvas:RemoveChild(child) end
                end
            end
        end)
    end
    PlayerMapMarker.ESPCanvas = nil
    PlayerMapMarker._OBHeadWidgetClass = nil
    PlayerMapMarker._OBHeadWidgetLoadFailed = false
    PlayerMapMarker._bDumpedWidgetChildren = false
    PlayerMapMarker._cachedViewportW = 1920
    PlayerMapMarker._cachedViewportH = 1080
end

function PlayerMapMarker.UpdateESP(AllPlayers, MyLoc)
    if not PlayerMapMarker.bUseScreenESP then return end
    
    if not _G.AK_IsESPActive() then
        if next(PlayerMapMarker.ESPWidgets) then
            PlayerMapMarker.ClearAllESP()
        end
        return
    end
    
    PlayerMapMarker.bUseSnapLines = _G.AK_GetVal("ESP_BOX") == 1 and _G.LexusConfig.Esp9_Line
    PlayerMapMarker.bUseSkeleton = _G.AK_GetVal("ESP_BOX") == 1 and _G.LexusConfig.Esp9_Skeleton

    if _G.AK_GetVal("ESP_BOX") ~= 1 and _G.AK_GetVal("ESP_HP") ~= 1 then
        return
    end

    if not PlayerMapMarker.InitESPCanvas() then
        return
    end

    if PlayerMapMarker._OBHeadWidgetLoadFailed then return end

    local PC = PlayerMapMarker.GetMyPlayerController()
    if IsValid(PC) then
        PlayerMapMarker.UpdateCanvasTransform(PC)
    end

    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines and IsValid(PC) then
        fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
    end

    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local SeenKeys = {}
    
    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then
            MyChar = GDP.GetLocalCharacter()
        else
            if PC and PC.GetPawn then MyChar = PC:GetPawn() end
        end
    end)
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

    for PlayerKey, Character in pairs(AllPlayers) do
        if IsValid(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Character)
            local KeyStr = tostring(PlayerKey)
            local Name = PlayerMapMarker.GetPlayerName(Character)

            local Loc = PlayerMapMarker.GetESPLocation(Character)

            local DistStr = ""
            if MyLoc and Loc then
                DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
            end

            local bSkip = false
            if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
            if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
            
            local TeamID = PlayerMapMarker.GetTeamID(Character)
            if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then
                bSkip = true
            end

            local bIsAlive = PlayerMapMarker.IsAlive(Character)

            if not bSkip and Loc then
                SeenKeys[KeyStr] = true
                local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]

                local Text = ""
                if _G.LexusConfig.Esp9_Name then Text = Name end
                if _G.LexusConfig.Esp9_Distance and DistStr and DistStr ~= "" then
                    if Text ~= "" then Text = string_format("%s [%s]", Text, DistStr) else Text = string_format("[%s]", DistStr) end
                end

                local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)

                if not ESPData then
                    local Widget = PlayerMapMarker.CreateESPWidget()
                    if Widget then
                        PlayerMapMarker.ESPWidgets[KeyStr] = {
                            Widget = Widget,
                            Character = Character,
                            Name = Name,
                            LastDistStr = DistStr,
                            TeamID = TeamID,
                        }
                        PlayerMapMarker.UpdateESPText(Widget, Text)
                        if bIsAlive then
                            PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                            PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
                            local HP = Character.Health or 0
                            local MaxHP = Character.MaxHealth or 120
                            local pct = 0
                            if HP > 0 and MaxHP > 0 then
                                pct = HP / MaxHP
                                if pct > 1 then pct = 1 end
                                if pct < 0 then pct = 0 end
                            end
                            PlayerMapMarker.UpdateESPHealth(Widget, pct)
                            PlayerMapMarker.AddWeaponIconToESP(Widget, Character)
                            
                            if PlayerMapMarker.bUseSnapLines then
                                PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                            else
                                PlayerMapMarker.RemoveSnapLine(KeyStr)
                            end

                            if PlayerMapMarker.bUseSkeleton then
                                PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(TeamID), bOnScreen, Loc)
                            else
                                PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                            end
                        else
                            local Container = Widget.Container or Widget
                            pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            PlayerMapMarker.UpdateESPHealth(Widget, 0)
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                            PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                        end
                    end
                else
                    ESPData.Character = Character
                    ESPData.Name = Name
                    ESPData.LastDistStr = DistStr
                    if bIsAlive then
                        ESPData.TeamID = TeamID
                        PlayerMapMarker.ApplyTeamColor(ESPData.Widget, TeamID)
                        
                        ESPData.Widget._LastESPText = nil
                        PlayerMapMarker.UpdateESPText(ESPData.Widget, Text)
                        PlayerMapMarker.UpdateESPPositionWithPC(ESPData.Widget, Loc, PC, CanvasPos)
                        local HP = Character.Health or 0
                        local MaxHP = Character.MaxHealth or 120
                        local pct = 0
                        if HP > 0 and MaxHP > 0 then
                            pct = HP / MaxHP
                            if pct > 1 then pct = 1 end
                            if pct < 0 then pct = 0 end
                        end
                        PlayerMapMarker.UpdateESPHealth(ESPData.Widget, pct)
                        PlayerMapMarker.AddWeaponIconToESP(ESPData.Widget, Character)
                        
                        if PlayerMapMarker.bUseSnapLines then
                            PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                        else
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                        end

                        if PlayerMapMarker.bUseSkeleton then
                            PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(TeamID), bOnScreen, Loc)
                        else
                            PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                        end
                    else
                        local Container = ESPData.Widget.Container or ESPData.Widget
                        pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                        PlayerMapMarker.UpdateESPHealth(ESPData.Widget, 0)
                        PlayerMapMarker.RemoveSnapLine(KeyStr)
                        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                    end
                end
            end
        end
    end

    for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
        if not SeenKeys[KeyStr] then
            PlayerMapMarker.RemoveESPWidget(Data.Widget, KeyStr)
            PlayerMapMarker.ESPWidgets[KeyStr] = nil
        end
    end
end

function PlayerMapMarker.UpdateESPLight()
    if RedBoxOverlay and RedBoxOverlay.bActive and _G.LexusConfig.Esp9_Count then 
        RedBoxOverlay.UpdatePosition() 
    end
    
    if not PlayerMapMarker.bUseScreenESP then return end
    
    if not _G.AK_IsESPActive() then
        if next(PlayerMapMarker.ESPWidgets) then
            PlayerMapMarker.ClearAllESP()
        end
        return
    end
    
    PlayerMapMarker.bUseSnapLines = _G.AK_GetVal("ESP_BOX") == 1 and _G.LexusConfig.Esp9_Line
    PlayerMapMarker.bUseSkeleton = _G.AK_GetVal("ESP_BOX") == 1 and _G.LexusConfig.Esp9_Skeleton
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end

    PlayerMapMarker.UpdateCanvasTransform(PC)

    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end

    for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
        local Widget = ESPData.Widget
        local Character = ESPData.Character
        local Container = Widget and (Widget.Container or Widget)
        local bWidgetValid = false
        pcall(function() bWidgetValid = Container and slua.isValid(Container) end)

        if Widget and bWidgetValid and Character and IsValid(Character) then
            local bIsAlive = PlayerMapMarker.IsAlive(Character)
            if not bIsAlive then
                pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                PlayerMapMarker.RemoveSnapLine(KeyStr)
                PlayerMapMarker.RemoveSkeletonLines(KeyStr)
            else
                local bShowAnyUI = (_G.AK_GetVal("ESP_BOX") == 1) and (_G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP or _G.LexusConfig.Esp9_Team or _G.LexusConfig.Esp9_Weapon)
                if bShowAnyUI then
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                else
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                end
                pcall(function() Container:SetRenderOpacity(1.0) end)

                local Loc = PlayerMapMarker.GetESPLocation(Character)
                if Loc then
                    local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                    PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                    if PlayerMapMarker.bUseSnapLines then PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                    else PlayerMapMarker.RemoveSnapLine(KeyStr) end

                    if PlayerMapMarker.bUseSkeleton then
                        PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(ESPData.TeamID), bOnScreen, Loc)
                    else
                        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                    end
                else 
                    PlayerMapMarker.RemoveSnapLine(KeyStr)
                    PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                end
            end
        end
    end
end

function PlayerMapMarker.UpdateESPDistances()
    if not PlayerMapMarker.bUseScreenESP then return end
    if not _G.AK_IsESPActive() then return end
    if _G.AK_GetVal("ESP_BOX") ~= 1 then return end
    
    local MyLoc = PlayerMapMarker.GetMyLocation()
    if not MyLoc then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    PlayerMapMarker.UpdateCanvasTransform(PC)

    for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
        local Character = ESPData.Character
        local Widget = ESPData.Widget
        local Container = Widget and (Widget.Container or Widget)
        local bWidgetValid = false
        pcall(function() bWidgetValid = Container and slua.isValid(Container) end)
        if Character and IsValid(Character) and Widget and bWidgetValid then
            local Loc = PlayerMapMarker.GetESPLocation(Character)
            if Loc then
                local Dist = PlayerMapMarker.CalcDistance(MyLoc, Loc)
                ESPData.LastDistance = Dist

                if PlayerMapMarker.bShowDistance then
                    local DistStr = ""
                    local Meters = 0
                    if Dist then
                        Meters = Dist / 100
                        if Meters < 1000 then DistStr = string_format("%dm", math_floor(Meters))
                        else DistStr = string_format("%.1fkm", Meters / 1000) end
                    end

                    local Name = ESPData.Name or "Unknown"
                    local Text = ""
                    
                    if _G.LexusConfig.Esp9_Name then Text = Name end
                    if _G.LexusConfig.Esp9_Distance and DistStr and DistStr ~= "" then
                        if Text ~= "" then Text = string_format("%s [%s]", Text, DistStr) else Text = string_format("[%s]", DistStr) end
                    end
                    
                    ESPData.LastDistStr = DistStr
                    Widget._LastESPText = nil 
                    PlayerMapMarker.UpdateESPText(Widget, Text)
                end
            end
        end
    end
end

function PlayerMapMarker.ScanAndUpdate()
    if not _G.AK_IsESPActive() then
        if RedBoxOverlay.bActive then RedBoxOverlay.Stop() end
        if next(PlayerMapMarker.ESPWidgets) then
            PlayerMapMarker.ClearAllESP()
        end
        return 0
    end
    
    local AllChars = PlayerMapMarker.GetAllCharacters()
    if not AllChars then RedBoxOverlay.SetCounts(0, 0) return 0 end

    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local MyLoc = PlayerMapMarker.GetMyLocation()

    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter()
        else local PC = PlayerMapMarker.GetMyPlayerController() if PC and PC.GetPawn then MyChar = PC:GetPawn() end end
    end)
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

    local realPlayers = 0
    local botPlayers = 0

    for PlayerKey, Character in pairs(AllChars) do
        if IsValid(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Character)
            local bIsAlive = PlayerMapMarker.IsAlive(Character)

            if bIsAlive and not bIsMe then
                local bIsMyTeam = false
                if MyTeamID ~= nil then
                    local targetTeamID = PlayerMapMarker.GetTeamID(Character)
                    if targetTeamID == MyTeamID then bIsMyTeam = true end
                end
                
                if not bIsMyTeam then
                    if bIsAI then botPlayers = botPlayers + 1
                    else realPlayers = realPlayers + 1 end
                end
            end
        end
    end

    local bShowCounter = _G.LexusConfig.Esp9_Count and (_G.AK_GetVal("ENEMY_COUNTER") == 1)
    if bShowCounter then
        if RedBoxOverlay.bActive then RedBoxOverlay.SetCounts(realPlayers, botPlayers)
        else RedBoxOverlay.Start() end
    else
        if RedBoxOverlay.bActive then RedBoxOverlay.Stop() end
    end

    if PlayerMapMarker.bUseScreenESP then
        PlayerMapMarker.UpdateESP(AllChars, MyLoc)
        return 0
    end
    return 0
end

function PlayerMapMarker.AttachTimers()
    pcall(function()
        local pc = PlayerMapMarker.GetMyPlayerController()
        if not slua.isValid(pc) or not pc.AddGameTimer then
            local now = os_time()
            if PlayerMapMarker._AttachPending then if PlayerMapMarker._AttachPendingTime and (now - PlayerMapMarker._AttachPendingTime) < 2 then return end end
            PlayerMapMarker._AttachPending = true ; PlayerMapMarker._AttachPendingTime = now
            pcall(function() require("timer").SetGameTimer(1.0, false, function() PlayerMapMarker._AttachPending = nil ; PlayerMapMarker._AttachPendingTime = nil ; PlayerMapMarker.AttachTimers() end) end)
            return
        end

        PlayerMapMarker._AttachPending = nil ; PlayerMapMarker._AttachPendingTime = nil
        local now = os_time()
        local lastPC = PlayerMapMarker._ActiveTimerPC
        local lastTick = PlayerMapMarker._ActiveTimerTick
        if lastPC and slua.isValid(lastPC) and lastPC == pc then if lastTick and (now - lastTick) < 5 then return end end

        PlayerMapMarker._ActiveTimerPC = pc ; PlayerMapMarker._ActiveTimerTick = now

        pcall(function() pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.5, true, function() PlayerMapMarker._ActiveTimerTick = os_time() if PlayerMapMarker.bActive then pcall(function() PlayerMapMarker.ScanAndUpdate() end) end end) end)
        pcall(function() pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.02, true, function() PlayerMapMarker._ActiveTimerTick = os_time() if PlayerMapMarker.bActive then pcall(function() PlayerMapMarker.UpdateESPLight() end) end end) end)
        pcall(function() pc:AddGameTimer(PlayerMapMarker._DistanceUpdateInterval or 0.1, true, function() PlayerMapMarker._ActiveTimerTick = os_time() if PlayerMapMarker.bActive and PlayerMapMarker.bUseScreenESP and PlayerMapMarker.bShowDistance then pcall(function() PlayerMapMarker.UpdateESPDistances() end) end end) end)
        pcall(function() require("timer").SetGameTimer(5.0, false, PlayerMapMarker.AttachTimers) end)
    end)
end

function PlayerMapMarker.Start()
    if PlayerMapMarker.bActive then return end
    if not _G.AK_GetVal("ESP_VIP_MARKER") == 1 then return end
    PlayerMapMarker.bActive = true
    PlayerMapMarker._FrameCount = 0
    PlayerMapMarker.ScanAndUpdate()
    PlayerMapMarker.AttachTimers()
end

function PlayerMapMarker.Stop()
    PlayerMapMarker.bActive = false
    PlayerMapMarker._FrameCount = 0
    PlayerMapMarker.ClearAllESP()
end

_G.PlayerMapMarker = PlayerMapMarker

-- ============================================================================
-- MATERIAL EVASION
-- ============================================================================
local function activate_material_evasion()
    if _G._MATERIAL_GETTERS_HOOKED then return end
    pcall(function()
        local UMaterial = import("Material")
        local UMaterialInstance = import("MaterialInstance")
        local UMaterialInstanceDynamic = import("MaterialInstanceDynamic")
        local UPrimitiveComponent = import("PrimitiveComponent")
        local UMeshComponent = import("MeshComponent")

        if UMaterial then
            UMaterial.GetDisableDepthTest = function() return false end
            UMaterial.GetBlendMode = function() return 0 end
            UMaterial.GetMaterialHash = function() return "FAKE_HASH" end
            UMaterial.VerifyMaterial = function() return true end
        end
        if UMaterialInstance then
            UMaterialInstance.GetDisableDepthTest = function() return false end
            UMaterialInstance.GetBlendMode = function() return 0 end
            UMaterialInstance.GetBaseMaterial = function() return nil end
        end
        if UMaterialInstanceDynamic then
            local oldVec = UMaterialInstanceDynamic.K2_GetVectorParameterValue
            UMaterialInstanceDynamic.K2_GetVectorParameterValue = function(self, name)
                local n = tostring(name)
                if n:find("Color") or n:find("Emissive") then return {R=255,G=255,B=255,A=255} end
                return oldVec(self, name)
            end
            local oldScal = UMaterialInstanceDynamic.K2_GetScalarParameterValue
            UMaterialInstanceDynamic.K2_GetScalarParameterValue = function(self, name)
                if tostring(name):find("Emissive") then return 0.0 end
                return oldScal(self, name)
            end
            UMaterialInstanceDynamic.GetFullName = function() return "DefaultMaterial" end
        end
        if UPrimitiveComponent then
            UPrimitiveComponent.IsRenderedOnCustomDepth = function() return false end
            UPrimitiveComponent.GetRenderCustomDepth = function() return false end
            UPrimitiveComponent.GetCustomDepthStencilValue = function() return 0 end
            UPrimitiveComponent.GetCustomDepthStencilWriteMask = function() return 0 end
            UPrimitiveComponent.GetVisibleFlag = function() return true end
        end
        if UMeshComponent then
            UMeshComponent.ShouldRender = function() return true end
            UMeshComponent.GetShouldRender = function() return true end
            UMeshComponent.IsVisible = function() return true end
        end

        local UObject = import("Object")
        if UObject and UObject.GetObjectsOfClass then
            local oldGet = UObject.GetObjectsOfClass
            UObject.GetObjectsOfClass = function(Class, IncludeDerived)
                if Class and tostring(Class):find("MaterialInstanceDynamic") then return {} end
                return oldGet(Class, IncludeDerived)
            end
        end
    end)
    _G._MATERIAL_GETTERS_HOOKED = true
end
activate_material_evasion()

-- ============================================================================
-- NEW WALLHACK (DrawDyeing + IdeaOutline) - LEGACY FALLBACK
-- ============================================================================
local LinearColor = import("LinearColor")

local CONSOLE_READY = false
local PROCESSED_PAWNS = {}
local TICK_COUNT = 0
local WH_TIMER = nil

local TICK_INTERVAL = 0.3
local MAX_PAWNS_PER_TICK = 20
local RESET_PROCESSED_EVERY = 6
local AVATAR_SLOTS = {0,1,2,3,4,5,6,7}

local colors = {
    vis = LinearColor(0, 255, 0, 255),
    occ = LinearColor(255, 0, 0, 255),
    bVis = LinearColor(0, 200, 0, 255),
    bOcc = LinearColor(200, 0, 0, 255)
}

local function SetupConsole()
    if CONSOLE_READY then return end
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        CONSOLE_READY = true
        print("[PBC] Console ready")
    end)
end

local function ApplyToMesh(mesh, visColor, occColor)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visColor)
        mesh:SetIdeaOutlineOcclusionColor(occColor)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function RemoveFromMeshPBC(mesh)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetDrawDyeingMode(0)
        mesh:SetDrawIdeaOutline(false)
        mesh:SetIdeaOutlineNew(false)
        mesh:SetDrawHighlight(false)
        mesh:SetHighlightCanBeOccluded(true)
        mesh:SetRenderCustomDepth(false)
        mesh:SetCustomDepthStencilValue(0)
        mesh:SetIdeaOutlineOcclusionHighlight(false)
        mesh:SetIdeaOverrideOutlineAndOcclusion(false)
    end)
end

local function IsPawnAlive(pawn)
    if not slua.isValid(pawn) then return false end
    if pawn.Health and pawn.Health > 0 then return true end
    return false
end

local function PBCtick()
    pcall(function()
        local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
        local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
        if not (whGR or whAim) then return end
        if _G._MOD_EXPIRED then return end
        if not _G._WHA_BYPASS_ACTIVE then return end
        local localPawn = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPawn) then return end

        SetupConsole()
        if not colors then return end

        TICK_COUNT = TICK_COUNT + 1
        if TICK_COUNT % RESET_PROCESSED_EVERY == 0 then PROCESSED_PAWNS = {} end

        local myTeamId = localPawn.TeamID or 0
        local allPawns = Game:GetAllPlayerPawns() or {}
        local processedCount = 0

        for _, pawn in pairs(allPawns) do
            if processedCount >= MAX_PAWNS_PER_TICK then break end
            if not slua.isValid(pawn) or pawn == localPawn then goto continue end
            if pawn.PlayerKey and PROCESSED_PAWNS[pawn.PlayerKey] then goto continue end

            if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                local isAI = false
                pcall(function() isAI = Game:IsAI(pawn) end)
                local vis = isAI and colors.bVis or colors.vis
                local occ = isAI and colors.bOcc or colors.occ

                pcall(function()
                    if slua.isValid(pawn.Mesh) then ApplyToMesh(pawn.Mesh, vis, occ) end
                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then ApplyToMesh(mesh, vis, occ) end
                        end
                    end
                    pcall(function()
                        local SkeletalMeshComponent = import("SkeletalMeshComponent")
                        if SkeletalMeshComponent then
                            local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) and comp ~= pawn.Mesh then ApplyToMesh(comp, vis, occ) end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local StaticMeshComponent = import("StaticMeshComponent")
                        if StaticMeshComponent then
                            local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then ApplyToMesh(comp, vis, occ) end
                                end
                            end
                        end
                    end)
                    local weapon = pawn:GetCurrentWeapon()
                    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                        ApplyToMesh(weapon.Mesh, vis, occ)
                    end
                end)

                if pawn.PlayerKey then PROCESSED_PAWNS[pawn.PlayerKey] = true end
                processedCount = processedCount + 1
            end
            ::continue::
        end
    end)
end

local function StartPBC()
    local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
    local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
    if not (whGR or whAim) then return false end
    SetupConsole()
    if not colors then
        print("[PBC] Colors not initialized, aborting")
        return false
    end

    if WH_TIMER then
        pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end end)
        WH_TIMER = nil
    end

    if _G.Game and _G.Game.AddGameTimer then
        WH_TIMER = _G.Game:AddGameTimer(TICK_INTERVAL, true, PBCtick)
        print("[PBC] ✅ Active (Game timer)")
        return true
    end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        WH_TIMER = pc:AddGameTimer(TICK_INTERVAL, true, PBCtick)
        print("[PBC] ✅ Active (PC timer)")
        return true
    end

    print("[PBC] ❌ Could not start timer")
    return false
end

local retryCount = 0
local function RetryStart()
    local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
    local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
    if not (whGR or whAim) then return end
    if retryCount >= 30 then
        print("[PBC] ❌ Failed to start after 30 retries")
        return
    end
    retryCount = retryCount + 1
    if StartPBC() then
        print("[PBC] ✅ Module ready!")
    else
        if _G.Game and _G.Game.AddGameTimer then
            _G.Game:AddGameTimer(1.0, false, RetryStart)
        end
    end
end

function _G._pbc_Cleanup()
    if WH_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then pcall(function() pc:RemoveGameTimer(WH_TIMER) end) end
        end)
        WH_TIMER = nil
    end
    -- Remove from all meshes
    pcall(function()
        local allPawns = Game:GetAllPlayerPawns() or {}
        for _, pawn in pairs(allPawns) do
            if slua.isValid(pawn) then
                pcall(function()
                    if slua.isValid(pawn.Mesh) then RemoveFromMeshPBC(pawn.Mesh) end
                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then RemoveFromMeshPBC(mesh) end
                        end
                    end
                    pcall(function()
                        local SkeletalMeshComponent = import("SkeletalMeshComponent")
                        if SkeletalMeshComponent then
                            local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) then RemoveFromMeshPBC(comp) end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local StaticMeshComponent = import("StaticMeshComponent")
                        if StaticMeshComponent then
                            local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then RemoveFromMeshPBC(comp) end
                                end
                            end
                        end
                    end)
                    local weapon = pawn:GetCurrentWeapon()
                    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                        RemoveFromMeshPBC(weapon.Mesh)
                    end
                end)
            end
        end
    end)
    PROCESSED_PAWNS = {}
    CONSOLE_READY = false
    print("[PBC] 🧹 Cleanup done")
end

function _G.StartNewWallhack()
    if WH_TIMER then return end
    local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
    local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
    if not (whGR or whAim) then return end
    RetryStart()
end

-- ============================================================================
-- STATIC MODULE PATCH
-- ============================================================================
local nop = function() end
local returnTrue = function() return true end
local returnFalse = function() return false end
local returnZero = function() return 0 end
local returnEmptyTable = function() return {} end

local blockedFuncNames = {
    "reportattackflow","reportsecattackflow","reporthurtflow","reportfirearms",
    "reportverifyinfoflow","reportmrpcsflow","reportplayerbehavior","reportteammathurt",
    "reportmisKillbyteammate","reportforbitpick","reportplayermoveroute","reportplayerposition",
    "reportvehiclemoveflow","reportsecregamemovingflow","reportparachutedata",
    "sendtsssdkantidatatolobby","senddserrorlogtolobby","senddshawkeyepatrollogtolobby",
    "sendsectlog","senddata miningtlog","sendactivitytlog","sendclientmemusage","sendclientfps",
    "onclientcrashreport","onnetworklossdetected","reportmatchroomdata","reportplayersping",
    "sendclientstats","sendserveravgtickdelta","reporthitflow","onplayeractorchannelerror",
    "onplayerrpcvalidatefailed","reportequipmentflow","reportaimflow",
    "getweaponreport","getoneweaponreport","reportheavyweaponboxspawnflow",
    "reportheavyweaponboxactivationflow","reportheavyweaponboxopenplayerflow",
    "reportheavyweaponboxitemflow","reportplayersping","reportplayerip",
    "reportplayerframepingrecord","ondsconnectionsaturated","reportdsnetsaturation",
    "reportnetcontinuoussaturate","reportdsnetrate",
    "reportcircleflow","reportdscircleflow","reportjumpflow","reportaistrategyinfo",
    "sendaideliveryinfo","reportdailytaskinfo","reportmatchroomdata","sendplayerspectatinglog",
    "reportidcardproduceflow","reportidcardpickupflow","reportidcarddestroyflow",
    "reportrevivalflow","reportgamesetting","reportgamesettingnew","reportantsvoiceteamcreate",
    "reportantsvoiceteamquit","reportcommoninfo","reportlightweightstat","sendsectlog",
    "senddata miningtlog","sendactivitytlog","getgeneraltlogdata",
    "reportwallhack","reportaimbot","reportspeedhack","reportmagicbullet",
    "reportplayercontrollerstatechanged","reportavatarflow","reportabnormalmaterial",
    "reportdepthtestchange","reportwallhack","reportmemoryexception","reportmaterialscan",
    "reportshaderoverride","sendsec tlog","senddata miningtlog",
    "reportplayerkillflow","clientsecplayerkillflow","checkreportsecattackflow",
    "checkreportsecattackflowwithattackflow","isenablereportplayerkillflow",
    "isenablereportmrpcsincircleflow","isenablereportmrpcsintpartcircleflow",
    "isenablereportmrpcsflow","isenablereporthitflow","isenablereportcircleflow",
    "onplayernetconnectionclosed","onplayeractorchannelerror",
    "onplayerrpcvalidatefailed","onplayerspectateexception","onshutdownaftererror",
    "heartbeat","sendheartbeat","clientheartbeat","serverheartbeat",
    "swifthawk","clientswifthawk","clientswifthawkwithparams","swifthawkreport","swifthawkdata",
    "anticheatreport","cheatdetection","violationreport","securityviolation",
    "integritycheck","signatureverify","md5","hash","filecheck","pakcheck"
}

local origRequire = require
local securityPathPatterns = { "Security", "AntiCheat", "Integrity", "ReportPlayer", "HawkEye", "SwiftHawk", "Ban", "TssSdk", "ShootVerify", "CoronaLab", "HiggsBoson" }
local function isSecurityModule(name)
    for _, p in ipairs(securityPathPatterns) do
        if name:find(p, 1, true) then return true end
    end
    return false
end
local dummyModules = {
    ["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"] = true,
    ["GameLua.Mod.BaseMod.Common.Security.AvatarCheckCallback"] = true,
    ["GameLua.Mod.BaseMod.Common.Security.GameSafeCallbacks"] = true,
}
_G.require = function(name)
    if dummyModules[name] then
        return { bMHActive = false, BlackList = {} }
    end
    local mod = origRequire(name)
    if type(mod) == "table" and isSecurityModule(name) and not mod.__ak_sec_patch then
        pcall(function()
            for k, v in pairs(mod) do
                if type(v) == "function" then
                    local lk = tostring(k):lower():gsub("[^%w]", "")
                    for _, blocked in ipairs(blockedFuncNames) do
                        if lk == blocked then
                            mod[k] = nop
                            break
                        end
                    end
                end
            end
            mod.__ak_sec_patch = true
        end)
    end
    return mod
end

local securitySubsystemNames = {
    "FileCheckSubsystem","IntegrityCheckSubsystem","PakCheckSubsystem",
    "ClientWallhackDetectionSubsystem","ClientESPDetectionSubsystem",
    "ClientAimTrackingSubsystem","ClientAntiCheatSubsystem",
    "ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem",
    "CoronaLabSubsystem","PlayerSecurityInfoSubsystem",
    "ClientSecMrpcsFlowSubsystem","MrpcsFlowSubsystem",
    "ShootVerifySubSystemClient","MemoryCheckSubsystem",
    "SpeedCheckSubsystem","WallCheckSubsystem",
    "BehaviorScoreSubsystem","AFKReportorSubsystem",
    "AvatarExceptionSubsystem","GameReportSubsystem",
    "SwiftHawkSubsystem","HeartbeatSubsystem",
    "ClientReportPlayerSubsystem","DSReportPlayerSubsystem",
    "ModifierExceptionSubsystem","SimulateCharacterSubsystem",
    "ClientRenderCheckSubsystem","ClientMemoryGuardSubsystem",
    "ClientKernelCheckSubsystem"
}
local SubsystemMgr_inst = nil
pcall(function() SubsystemMgr_inst = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr") end)
if SubsystemMgr_inst and not SubsystemMgr_inst.__ak_intercept then
    local realGet = SubsystemMgr_inst.Get
    SubsystemMgr_inst.Get = function(self, name)
        local sub = realGet(self, name)
        if type(sub) == "table" and not sub.__ak_sub_silenced then
            for _, secName in ipairs(securitySubsystemNames) do
                if name == secName then
                    for k, v in pairs(sub) do
                        if type(v) == "function" then
                            local lk = tostring(k):lower():gsub("[^%w]", "")
                            for _, blocked in ipairs(blockedFuncNames) do
                                if lk == blocked then
                                    sub[k] = nop
                                    break
                                end
                            end
                        end
                    end
                    sub.__ak_sub_silenced = true
                    break
                end
            end
        end
        return sub
    end
    SubsystemMgr_inst.__ak_intercept = true
end

do
    local realGC = _G.GameplayCallbacks or {}
    _G.GameplayCallbacks = setmetatable({}, {
        __index = function(t, k)
            local v = realGC[k]
            if type(v) == "function" then
                local lk = tostring(k):lower():gsub("[^%w]", "")
                for _, blocked in ipairs(blockedFuncNames) do
                    if lk == blocked then return nop end
                end
            end
            return v
        end,
        __newindex = function(t, k, v)
            if type(v) == "function" then
                local lk = tostring(k):lower():gsub("[^%w]", "")
                for _, blocked in ipairs(blockedFuncNames) do
                    if lk == blocked then v = nop; break end
                end
            end
            rawset(realGC, k, v)
        end
    })
end

pcall(function()
    local ES = nil
    pcall(function() ES = origRequire("GameLua.Mod.BaseMod.Common.EventSystem") end)
    if not ES then ES = _G.EventSystem end
    if ES and not ES.__ak_event_blocked then
        local origPost = ES.postEvent
        ES.postEvent = function(eventType, eventID, ...)
            local sType = tostring(eventType or ""):lower()
            local sID = tostring(eventID or ""):lower()
            if sID:find("security") or sID:find("cheat") or sType:find("security") then return end
            return origPost(eventType, eventID, ...)
        end
        ES.__ak_event_blocked = true
    end
end)

pcall(function()
    if debug and debug.getinfo then debug.getinfo = function() return {} end end
    if debug and debug.getlocal then debug.getlocal = function() return nil end end
    if jit and jit.attach then jit.attach(function() end, "bc") end
end)

local function isPacketBlocked(name)
    local n = tostring(name or ""):lower()
    if n:match("md5") or n:match("hash") or n:match("integrity") or n:match("filecheck") or n:match("pakcheck") then return true end
    if n:match("report") or n:match("flow") or n:match("tlog") or
       n:match("cheat") or n:match("security") or n:match("verify") or
       n:match("heartbeat") or n:match("swifthawk") or n:match("ban") or
       n:match("inspect") or n:match("crash") or n:match("telemetry") or
       n:match("corona") or n:match("modifier") or n:match("simulate") then
        return true
    end
    return false
end
if NetUtil and not NetUtil._UltimatePacketsBlocked then
    local origSend = NetUtil.SendPacket
    NetUtil.SendPacket = function(pname, ...)
        if isPacketBlocked(pname) then return nil end
        return origSend(pname, ...)
    end
    NetUtil._UltimatePacketsBlocked = true
end
if _G.SendRPC then
    local origRPC = _G.SendRPC
    function _G.SendRPC(rpcName, ...)
        if isPacketBlocked(rpcName) then return end
        return origRPC(rpcName, ...)
    end
end

local function InstallMD5Bypass()
    local FAKE_MD5 = "7b1c7b5608da3083097816106fc331f9"
    local function returnFakeMD5() return FAKE_MD5 end
    local function returnTrue() return true end
    local function nop() end

    local function patchFunctionsInTable(tbl)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
            if type(v) == "function" then
                local lk = tostring(k):lower()
                if lk:match("md5") or lk:match("hash") or lk:match("crc") or
                   lk:match("sha") or lk:match("integrity") or lk:match("signature") or
                   lk:match("verifyfile") or lk:match("checkfile") then
                    tbl[k] = lk:match("md5") and returnFakeMD5 or returnTrue
                end
            end
        end
    end

    local criticalModules = {
        "CreativeModeBlueprintLibrary", "STExtraBlueprintFunctionLibrary",
        "GameplayStatics", "KismetMathLibrary", "KismetSystemLibrary",
        "FFileHelper", "GameplayData", "AvatarUtils", "TssSdk",
        "slua.loader", "slua.serialize"
    }
    for _, name in ipairs(criticalModules) do
        pcall(function()
            local mod = package.loaded[name] or _G[name]
            if mod then patchFunctionsInTable(mod) end
        end)
    end

    local globalHooks = {
        "MD5Hash", "CRC32", "SHA1", "SHA256", "HMAC",
        "CheckFileIntegrity", "VerifySignature", "FileMismatchReport",
        "OnFileCorrupted", "slua_verify", "check_slua_integrity",
        "GetMD5", "ComputeMD5", "VerifyFileIntegrity",
        "CheckMD5", "CheckFileMD5", "GetFileMD5"
    }
    for _, fn in ipairs(globalHooks) do
        if _G[fn] and type(_G[fn]) == "function" then
            _G[fn] = (fn:lower():match("md5") or fn:lower():match("hash")) and returnFakeMD5 or returnTrue
        end
    end

    local orig_io_open = io.open
    io.open = function(path, mode)
        if type(path) == "string" and path:lower():match("md5") then
            if mode and (mode == "w" or mode == "a") then
                return nil, "Blocked by HyperMD5"
            end
        end
        return orig_io_open(path, mode)
    end

    if NetUtil and NetUtil.SendPacket and not NetUtil._HyperMD5Blocked then
        local origSend = NetUtil.SendPacket
        NetUtil.SendPacket = function(packetName, ...)
            if packetName and tostring(packetName):lower():match("md5") then return nil end
            return origSend(packetName, ...)
        end
        NetUtil._HyperMD5Blocked = true
    end

    if _G.TssSdk then
        _G.TssSdk.GetFileMD5 = returnFakeMD5
        _G.TssSdk.VerifyFileSignature = returnTrue
        local oldRecv = _G.TssSdk.OnRecvData
        _G.TssSdk.OnRecvData = function(data)
            if type(data) == "string" and data:lower():match("md5") then return end
            if oldRecv then oldRecv(data) end
        end
    end

    local SubsystemMgr = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubsystemMgr then
        local checkers = {"FileCheckSubsystem","AssetCheckSubsystem","IntegrityCheckSubsystem","PakCheckSubsystem"}
        for _, sn in ipairs(checkers) do
            local sub = SubsystemMgr:Get(sn)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" then sub[k] = nop end end
                sub.StartCheck = nop; sub.ReportAbnormalFile = nop
            end
        end
    end
end
InstallMD5Bypass()

local function InstallHiggsBypass()
    pcall(function()
        local Higgs = origRequire("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            local origInit = Higgs.Initialize or Higgs.ctor
            if origInit then
                Higgs.Initialize = function(self, ...)
                    self.bMHActive = false
                    self.bCallPreReplication = false
                    if origInit then origInit(self, ...) end
                end
            else
                rawset(Higgs, "bMHActive", false)
                rawset(Higgs, "bCallPreReplication", false)
            end
        end
    end)

    local function poison_class(cls)
        if type(cls) ~= "table" then return end
        local mt = {
            __index = function() return nop end,
            __newindex = function() end,
            __call = nop,
        }
        setmetatable(cls, mt)
        rawset(cls, "bMHActive", false)
        rawset(cls, "bCallPreReplication", false)
        rawset(cls, "BlackList", {})
    end

    pcall(function()
        local avc = _G.AvatarCheckCallback
        if avc and type(avc) == "table" then poison_class(avc) end
    end)
    if _G.GameSafeCallbacks then poison_class(_G.GameSafeCallbacks) end

    _G.BlackList = {}
end
InstallHiggsBypass()

-- ============================================================================
-- ADDITIONAL STATIC BYPASSES
-- ============================================================================
local function tryImport(name)
    local ok, lib = pcall(import, name)
    return ok and lib or nil
end

pcall(function()
    local FileHelper = tryImport("FFileHelper")
    if FileHelper and FileHelper.SaveStringToFile then
        local origSave = FileHelper.SaveStringToFile
        FileHelper.SaveStringToFile = function(str, path, enc, unicode)
            if tostring(path):lower():match("md5") or tostring(path):lower():match("hash") or tostring(path):lower():match("integrity") then
                return true
            end
            return origSave(str, path, enc, unicode)
        end
    end
end)

pcall(function()
    if slua and slua.getSignature then
        function slua.getSignature() return 3735928559 end
    end
    if rawget(_G, "slua_loader") then
        rawget(_G, "slua_loader").verifyBytecode = returnTrue
        rawget(_G, "slua_loader").checkIntegrity = returnTrue
        if rawget(_G, "slua_loader").disableSignatureCheck then
            rawget(_G, "slua_loader").disableSignatureCheck = returnTrue
        end
    end
    if package.loaded["slua.serialize"] then
        package.loaded["slua.serialize"].check = returnTrue
        package.loaded["slua.serialize"].verify = returnTrue
    end
    if jit and jit.attach then jit.attach(function() end, "bc") end
end)

pcall(function()
    local KSL = tryImport("KismetSystemLibrary")
    if KSL then
        KSL.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
        KSL.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
        KSL.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
        KSL.ExecuteConsoleCommand(nil, "sig.Check 0")
        KSL.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
    end
end)

pcall(function()
    local puffer = package.loaded["client.slua.logic.download.report.puffer_tlog"]
    if puffer then
        puffer.ReportEvent = nop; puffer.ReportDownloadResult = nop; puffer.ReportODPTDError = nop
        puffer.ReportSkinError = nop
    end
    local AvatarUtils = package.loaded["AvatarUtils"] or _G.AvatarUtils
    if AvatarUtils then
        AvatarUtils.CheckIsWeaponInBlackList = returnFalse
        AvatarUtils.IsValidAvatar = returnTrue
        AvatarUtils.CheckAvatarIntegrity = returnTrue
        AvatarUtils.ReportInvalidAvatar = nop
    end
    local SubsystemMgr = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubsystemMgr then
        local fs = SubsystemMgr:Get("FileCheckSubsystem")
        if fs then fs.StartCheck = nop; fs.ReportAbnormalFile = nop; fs.StopCheck = nop end
    end
    local equipReport = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
    if equipReport then equipReport.Report = nop; equipReport.SendException = nop end
end)

pcall(function()
    local Screenshot = tryImport("ScreenshotMTDer") or tryImport("ScreenshotMaker")
    if Screenshot then
        Screenshot.MTDePicture = function() return "" end
        Screenshot.ReMTDePicture = function() return "" end
        Screenshot.HasCaptured = returnTrue
        Screenshot.TakeScreenshot = nop
        Screenshot.MakePicture = function() return "" end
        Screenshot.ReMakePicture = function() return "" end
    end
    if _G.TLog then
        _G.TLog.Info = nop; _G.TLog.Warning = nop; _G.TLog.Error = nop
        _G.TLog.Debug = nop; _G.TLog.Report = nop; _G.TLog.Send = nop; _G.TLog.Flush = nop
    end
    if _G.CrashSight then
        _G.CrashSight.ReportException = nop; _G.CrashSight.SetCustomData = nop
        _G.CrashSight.Log = nop; _G.CrashSight.SendCrash = nop; _G.CrashSight.ReportUserException = nop
    end
    local GameReportUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
    if GameReportUtils then
        GameReportUtils.BugglyPostExceptionFull = returnFalse
        GameReportUtils.CheckCanBugglyPostException = returnFalse
        GameReportUtils.ReplayReportData = nop; GameReportUtils.ReportGameException = nop
        GameReportUtils.PostException = nop
    end
    local ClientToolsReport = package.loaded["client.slua.logic.report.ClientToolsReport"]
    if ClientToolsReport then ClientToolsReport.SendReport = nop; ClientToolsReport.SendException = nop; ClientToolsReport.UploadLog = nop end
    local TLogReport = package.loaded["client.slua.config.tlog.tlog_report_utils"]
    if TLogReport then TLogReport.ReportTLogEvent = nop; TLogReport.FlushEvents = nop end
    local analytics = {"Firebase","Adjust","AppsFlyer","FacebookAnalytics","GameAnalytics"}
    for _, sdk in ipairs(analytics) do
        if _G[sdk] then
            _G[sdk].logEvent = nop; _G[sdk].trackEvent = nop; _G[sdk].setEnabled = returnFalse
            _G[sdk].sendEvent = nop; _G[sdk].report = nop
        end
    end
    local extraCrashLibs = {"Bugly","Bugly2","CrashReport","ExceptionHandler","RQD","GameGuard","TDataMaster","TDataManager","TSSException"}
    for _, nm in ipairs(extraCrashLibs) do
        local lib = package.loaded[nm] or _G[nm]
        if lib then
            if lib.ReportException then lib.ReportException = nop end
            if lib.ReportError then lib.ReportError = nop end
            if lib.Report then lib.Report = nop end
            if lib.SendReport then lib.SendReport = nop end
            if lib.SetUserData then lib.SetUserData = nop end
        end
    end
end)

pcall(function()
    local SubsystemMgr = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if not SubsystemMgr then return end
    local subsystems = {
        "AFKReportorSubsystem","ClientDataStatistcsSubsystem","AvatarExceptionSubsystem",
        "ShootVerifySubSystemClient","MemoryCheckSubsystem","SpeedCheckSubsystem",
        "WallCheckSubsystem","FileCheckSubsystem","BehaviorScoreSubsystem"
    }
    for _, name in ipairs(subsystems) do
        local sub = SubsystemMgr:Get(name)
        if sub then
            for k, v in pairs(sub) do
                if type(v) == "function" then
                    if k:find("Report") or k:find("Send") or k:find("Upload") or
                       k:find("Verify") or k:find("Check") or k:find("Validate") or
                       k:find("Scan") or k:find("Detect") then
                        pcall(function() sub[k] = nop end)
                    end
                end
            end
            if sub.ReportPingDelayTimer then pcall(sub.RemoveGameTimer, sub, sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end
            sub.DelayCount = 0
        end
    end
end)

pcall(function()
    local SubsystemMgr = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubsystemMgr then
        local subsystems = {"RescueBtnReplayTraceSubsystem","GameReportSubsystem","ReplaySubsystem"}
        for _, name in ipairs(subsystems) do
            local sub = SubsystemMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then
                        pcall(function() sub[k] = nop end)
                    end
                end
                if sub.timer then pcall(sub.RemoveGameTimer, sub, sub.timer) end
                if sub.Reporter then
                    sub.Reporter.ReportIntArrayData = nop; sub.Reporter.ReportUInt8ArrayData = nop; sub.Reporter.ReportFloatArrayData = nop
                end
                sub.ReplayReportData = returnFalse
                sub.CheckCanBugglyPostException = returnFalse
                sub.BugglyPostExceptionFull = returnFalse
                sub.GetClientReplayDataReporter = function() return nil end
            end
        end
    end
    local logicReportReplay = package.loaded["client.slua.logic.replay.logic_report_replay"]
    if logicReportReplay then logicReportReplay.ReportReplay = nop; logicReportReplay.SendReportReq = nop; logicReportReplay.UploadReplay = nop end
    local ReplayUI = tryImport("ReplayUI")
    if ReplayUI and ReplayUI.ShowReportButton then ReplayUI.ShowReportButton = nop end
    local homeReport = package.loaded["client.slua.logic.home.logic_home_report"]
    if homeReport then homeReport.ShowInGameReportUI = nop; homeReport.SendReport = nop end
end)

pcall(function()
    if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
    local GC = _G.GameplayCallbacks
    if GC.IsUltimateBypassed then return end
    local oldStateChanged = GC.OnDSPlayerStateChanged
    GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
        if InPlayerState then
            local s = string.lower(tostring(InPlayerState))
            local blocked = {cheatdetected=true, connectionlost=true, connectiontimeout=true,
                             connectionexception=true, netdrivererror=true, banned=true, kicked=true,
                             suspended=true, violationdetected=true, integrityfailure=true,
                             securityviolation=true}
            if blocked[s] then return end
        end
        if oldStateChanged then return pcall(oldStateChanged, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason) end
    end
    local reportFuncs = {
        "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
        "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
        "ReportMisKillByTeammate","ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition",
        "ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportParachuteData",
        "SendTssSdkAntiDataToLobby","SendDSErrorLogToLobby","SendDSHawkEyePatrolLogToLobby",
        "SendSecTLog","SendDataMiningTLog","SendActivityTLog","SendClientMemUsage","SendClientFPS",
        "OnClientCrashReport","OnNetworkLossDetected","ReportMatchRoomData","ReportPlayersPing",
        "SendClientStats","SendServerAvgTickDelta","ReportHitFlow","OnPlayerActorChannelError",
        "OnPlayerRPCValidateFailed","ReportEquipmentFlow","ReportAimFlow",
        "GetWeaponReport","GetOneWeaponReport","ReportHeavyWeaponBoxSpawnFlow",
        "ReportHeavyWeaponBoxActivationFlow","ReportHeavyWeaponBoxOpenPlayerFlow",
        "ReportHeavyWeaponBoxItemFlow","ReportPlayersPing","ReportPlayerIP",
        "ReportPlayerFramePingRecord","OnDSConnectionSaturated","ReportDSNetSaturation",
        "ReportNetContinuousSaturate","ReportDSNetRate","SendClientStats","SendServerAvgTickDelta",
        "ReportCircleFlow","ReportDSCircleFlow","ReportJumpFlow","ReportAIStrategyInfo",
        "SendAIDeliveryInfo","ReportDailyTaskInfo","ReportMatchRoomData","SendPlayerSpectatingLog",
        "ReportIDCardProduceFlow","ReportIDCardPickUpFlow","ReportIDCardDestroyFlow",
        "ReportRevivalFlow","ReportGameSetting","ReportGameSettingNew","ReportAntsVoiceTeamCreate",
        "ReportAntsVoiceTeamQuit","ReportCommonInfo","ReportLightweightStat","SendSecTLog",
        "SendDataMiningTLog","SendActivityTLog","GetGeneralTLogData",
        "ReportWallHack","ReportAimbot","ReportSpeedHack","ReportMagicBullet",
        "ReportPlayerControllerStateChanged","ReportAvatarFlow","ReportAbnormalMaterial",
        "ReportDepthTestChange","ReportWallHack","ReportMemoryException","ReportMaterialScan",
        "ReportShaderOverride"
    }
    for _, fn in ipairs(reportFuncs) do
        if GC[fn] then GC[fn] = nop end
    end
    GC.CheckReportSecAttackFlowWithAttackFlow = returnFalse
    GC.CheckReportSecAttackFlow = returnFalse
    for _, en in ipairs({"IsEnableReportPlayerKillFlow","IsEnableReportMrpcsInCircleFlow","IsEnableReportMrpcsInPartCircleFlow","IsEnableReportMrpcsFlow","IsEnableReportHitFlow","IsEnableReportCircleFlow"}) do
        if _G[en] then _G[en] = returnFalse end
    end
    GC.OnPlayerNetConnectionClosed = nop
    GC.OnPlayerActorChannelError = nop
    GC.OnPlayerRPCValidateFailed = nop
    GC.OnPlayerSpectateException = nop
    GC.OnShutdownAfterError = nop
    GC.IsUltimateBypassed = true
end)

pcall(function()
    local collectors = {"PlayerSecurityInfoCollector","PlayerSecurityInfo","SecurityInfoCollector",
                        "ClientSecurityCollector","PlayerAntiCheatCollector"}
    for _, name in ipairs(collectors) do
        if _G[name] then
            for k, v in pairs(_G[name]) do
                if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then
                    _G[name][k] = nop
                end
            end
        end
    end
    local psi = package.loaded["GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem"]
    if psi then
        psi.ReportData = nop; psi.CheckCheat = returnFalse; psi.ValidatePlayer = returnTrue
        psi.CollectData = nop; psi.SendToServer = nop
    end
    if _G.PlayerSecurityInfo then
        _G.PlayerSecurityInfo.ReportCheat = nop; _G.PlayerSecurityInfo.ReportSuspicious = nop
        _G.PlayerSecurityInfo.SendSecurityData = nop; _G.PlayerSecurityInfo.CollectSecurityInfo = nop
    end
end)

pcall(function()
    local flows = {"ClientSecMrpcsFlow","MrpcsFlow","MrpcsData","ClientCircleFlowSubsystem",
                   "ClientKillFlowSubsystem","ClientSecPlayerKillFlow"}
    for _, name in ipairs(flows) do
        local mod = package.loaded[name] or _G[name]
        if mod then
            for k, v in pairs(mod) do
                if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then
                    pcall(function() mod[k] = nop end)
                end
            end
        end
    end
    local cc = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientCircleFlowSubsystem"]
    if cc then
        cc.ReportCircleFlow = nop; cc.SendCircleData = nop; cc.ReportPlayerPosition = nop; cc.ReportCircleData = nop
    end
    if _G.ReportPlayerKillFlow then _G.ReportPlayerKillFlow = nop end
    if _G.ClientSecPlayerKillFlow then _G.ClientSecPlayerKillFlow = nop end
end)

pcall(function()
    local heartbeats = {"Heartbeat","SendHeartbeat","ClientHeartbeat","ServerHeartbeat"}
    for _, name in ipairs(heartbeats) do
        if _G[name] then _G[name] = nop end
        if _G.GameplayCallbacks and _G.GameplayCallbacks[name] then _G.GameplayCallbacks[name] = nop end
    end
    local SubsystemMgr = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubsystemMgr then
        local hb = SubsystemMgr:Get("HeartbeatSubsystem")
        if hb then
            if hb.timer then hb:RemoveGameTimer(hb.timer) end
            hb.SendHeartbeat = nop; hb.StartHeartbeat = nop
        end
    end
end)

pcall(function()
    if _G.CoronaLab then
        _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop
    end
    local SubsystemMgr = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubsystemMgr then
        local cl = SubsystemMgr:Get("CoronaLabSubsystem")
        if cl then cl.ReportData = nop; cl.SendToServer = nop; cl.CollectTelemetry = nop; cl.StopCollection = nop end
    end
    _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
    for k in pairs(_G.GlobalPlayerCoronaData) do _G.GlobalPlayerCoronaData[k] = nil end
    local mt = getmetatable(_G.GlobalPlayerCoronaData) or {}
    mt.__newindex = function() end
    setmetatable(_G.GlobalPlayerCoronaData, mt)
end)

pcall(function()
    if _G.bReportedModifierException then _G.bReportedModifierException = false end
    local mod = package.loaded["GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem"]
    if mod then
        mod.ReportException = nop; mod.CheckModifier = returnTrue; mod.ValidateModifier = returnTrue; mod.ReportModifierError = nop
    end
end)

pcall(function()
    local mod = package.loaded["GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem"]
    if mod then mod.ReportLocation = nop; mod.SendLocationData = nop; mod.VerifyLocation = returnTrue end
end)

pcall(function()
    local mod = package.loaded["GameLua.Dev.Subsystem.ShootVerifySubSystemClient"]
    if mod then
        mod.OnShootVerifyFailed = nop; mod.SendVerifyData = nop; mod.ReportBulletHit = nop
        mod.UploadHitInfo = nop; mod.VerifyShot = returnTrue
    end
    if _G.BulletHitInfoUploadData then
        _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop
    end
end)

pcall(function()
    local ClientSub = nil
    for _, p in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem"}) do
        if package.loaded[p] then ClientSub = package.loaded[p]; break end
        local ok, mod = pcall(origRequire, p)
        if ok and mod then ClientSub = mod; break end
    end
    if ClientSub then
        ClientSub.OnInit = nop; ClientSub._OnPlayerKilledOtherPlayer = nop
        ClientSub._RecordFatalDamager = nop; ClientSub._OnDeathReplayDataWhenFatalDamaged = nop
        ClientSub._RecordMurdererFromDeathReplayData = nop; ClientSub._RecordTeammatePlayerInfo = nop
        ClientSub._OnBattleResult = nop; ClientSub._OnShowQuickReportMutualExclusiveUI = nop
        ClientSub.GetFatalDamagerMap = returnEmptyTable
        ClientSub.GetCachedTeammateName2InfoMap = returnEmptyTable
        ClientSub.GetTeammateName2InfoMapDuringBattle = returnEmptyTable
        ClientSub.GetCurrentNotInTeamHistoricalTeammateMap = returnEmptyTable
        ClientSub.GetInTeamIndexFromHistoricalTeammateInfo = function() return -1 end
    end
    local DSSub = nil
    for _, p in ipairs({"GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem", "GameLua.Mod.BaseMod.Client.Security.DSReportPlayerSubsystem"}) do
        if package.loaded[p] then DSSub = package.loaded[p]; break end
        local ok, mod = pcall(origRequire, p)
        if ok and mod then DSSub = mod; break end
    end
    if DSSub then
        DSSub.OnInit = nop; DSSub._OnNearDeathOrRescued = nop; DSSub._OnCharacterDied = nop
        DSSub._OnTeammateDamage = nop; DSSub._OnPlayerSettlementStart = nop
        DSSub._AddKnockDownerToBattleResult = nop; DSSub._AddKillerToBattleResult = nop
        DSSub._AddTeammateMurderToBattleResult = nop; DSSub._AddFatalDamagerMapToBattleResult = nop
        DSSub._AddMLKillerUIDToBattleResult = nop; DSSub._SaveHistoricalTeammateInfo = nop
        DSSub._RecordFatalDamager = nop; DSSub._RecordTeammateMurderer = nop
    end
    local RPUtils = package.loaded["GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils"]
    if RPUtils then
        RPUtils.RecordFatalDamager = nop; RPUtils.IsUsingHistoricalTeammateInfo = returnFalse; RPUtils.IsCharacterDeliverAI = returnFalse
    end
    local SecUtils = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"]
    if SecUtils then SecUtils.ExtractPlayerBasicInfo = returnEmptyTable; SecUtils.LogIf = returnFalse end
    local QuickReport = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate"]
    if QuickReport then QuickReport.OnShowMutualExclusiveUI = nop; QuickReport.OnHideMutualExclusiveUI = nop end
end)

pcall(function()
    local SubsystemMgr = origRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if not SubsystemMgr then return end
    local allSubs = {
        "CoronaLabSubsystem","PlayerSecurityInfoSubsystem","ClientCircleFlowSubsystem",
        "ModifierExceptionSubsystem","SimulateCharacterSubsystem","ShootVerifySubSystemClient",
        "HiggsBosonComponent","ClientReportPlayerSubsystem","DSReportPlayerSubsystem",
        "ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem","ClientDataStatistcsSubsystem",
        "AFKReportorSubsystem","BehaviorScoreSubsystem","FileCheckSubsystem","MemoryCheckSubsystem",
        "SpeedCheckSubsystem","WallCheckSubsystem","AvatarExceptionSubsystem","GameReportSubsystem",
        "RescueBtnReplayTraceSubsystem","ClientSecMrpcsFlowSubsystem","MrpcsFlowSubsystem",
        "PlayerKillFlowSubsystem","CircleFlowSubsystem","SwiftHawkSubsystem","HeartbeatSubsystem",
        "AntiCheatSubsystem","IntegrityCheckSubsystem","SignatureVerifySubsystem","MD5CheckSubsystem",
        "PakVerifySubsystem"
    }
    for _, sn in ipairs(allSubs) do
        local sub = SubsystemMgr:Get(sn)
        if sub then
            for k, v in pairs(sub) do
                if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or
                    k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or
                    k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then
                    pcall(function() sub[k] = nop end)
                end
            end
            if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
            if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
            if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
        end
    end
end)

pcall(function()
    local flags = {"ENABLE_REPORT","ENABLE_ANTI_CHEAT","ENABLE_SECURITY","ENABLE_TELEMETRY",
                   "ENABLE_ANALYTICS","ENABLE_CRASH_REPORT","ENABLE_PERFORMANCE_REPORT"}
    for _, f in ipairs(flags) do
        if _G[f] then _G[f] = false end
    end
end)

pcall(function()
    local stExtra = tryImport("STExtraBlueprintFunctionLibrary")
    if stExtra and stExtra.IsDevelopment then stExtra.IsDevelopment = returnFalse end
    if Client then Client.IsDevelopment = returnFalse; Client.IsShipping = returnFalse end
    if Server then Server.IsShipping = returnFalse end

    local ToolReport = package.loaded["client.slua.logic.report.ToolReportUtil"]
    if ToolReport then
        ToolReport.IsReleaseVersion = returnFalse; ToolReport.IsWhite = returnFalse; ToolReport.GetReportSwitch = returnFalse
    end

    if _G.TApmHelper then _G.TApmHelper.postEvent = nop end

    local PC = _G.PacketCallbacks
    if PC then
        PC.player_report_cheat = nop; PC.upload_loots_rsp = nop; PC.watch_player_exit = nop
        PC.player_login_report = nop; PC.player_logout_report = nop; PC.server_time_report = nop
    end

    local sdm = _G.ServerDataMgr
    if sdm and sdm.DeletablePlayerResultKey then
        sdm.DeletablePlayerResultKey.SuspiciousHitCount = true
        sdm.DeletablePlayerResultKey.EspTotalSimTraceCnt = true
        sdm.DeletablePlayerResultKey.EspTotalImeFocusCnt = true
        sdm.DeletablePlayerResultKey.ClientGravityAnomalyCount = true
    end

    local pcNotify = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature"]
    if pcNotify then
        pcNotify.ClientRPC_SyncBanID = nop; pcNotify.ClientRPC_StrongTips = nop
        pcNotify.ClientRPC_NormalTips = nop; pcNotify.Notify = nop
        pcNotify.ClientRPC_NotifyBan = nop; pcNotify.ClientRPC_NotifyPunish = nop
        pcNotify.ClientRPC_NotifyIllegalProgram = nop
    end

    local secUtils = package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"]
    if secUtils and secUtils.EStrategyTypeInReplay then
        secUtils.EStrategyTypeInReplay.EspTotalSimTraceCnt = 0
        secUtils.EStrategyTypeInReplay.EspTotalImeFocusCnt = 0
        secUtils.EStrategyTypeInReplay.ClientGravityAnomalyCount = 0
        secUtils.EStrategyTypeInReplay.FlyingErrorCnt = 0
    end

    local hia = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem"]
    if hia then hia.CheckHitIntegrity = nop; hia.InitSession = nop; hia.OnBattleEnd = nop end

    local Behavior = package.loaded["GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem"]
    if Behavior then
        Behavior.OnHandleBehaviorScore = nop; Behavior.AIPerceptionScore = nop; Behavior.ReportBehavior = nop; Behavior.CalcFinalScore = returnZero
    end

    local BanLogic = package.loaded["client.slua.logic.ban.ClientBanLogic"]
    if BanLogic then
        BanLogic.OnSyncBanInfo = nop; BanLogic.OnVoiceBanNotify = nop; BanLogic.OnRealTimeVoiceBanNotify = nop
        BanLogic.OnVoiceBanSuccess = nop; BanLogic.OnSyncMicSuspicious = nop; BanLogic.OnSyncMicPreFilter = nop
        BanLogic.OnNotifyWarningTips = nop; BanLogic.ReqBanInfo = nop
    end
    local BanUtil = package.loaded["client.common.ban_util"] or _G.ban_util
    if BanUtil then BanUtil.CheckBanStatus = returnFalse; BanUtil.GetBanTime = returnZero; BanUtil.IsBanForever = returnFalse end
    local TTBan = package.loaded["client.logic.login.logic_tt_ban"] or _G.logic_tt_ban
    if TTBan then TTBan.CheckIfCanCreateRole = nop; TTBan.GetCarrierInfo = function() return "[{\"mcc\":\"000\"}]" end end
    local GodzillaBan = package.loaded["client.network.Protocol.GodzillaBanHandler"]
    if GodzillaBan then GodzillaBan.send_godzilla_ban_req = nop; GodzillaBan.send_godzilla_unban_req = nop end
    local AntiAddiction = package.loaded["client.network.Protocol.AntiaddctionHandler"]
    if AntiAddiction then AntiAddiction.send_anti_addiction_req = nop; AntiAddiction.send_anti_addiction_notify = nop end
    local AccessRestrict = package.loaded["client.network.Protocol.AccessRestrictionHandler"]
    if AccessRestrict then
        AccessRestrict.send_access_restriction_req = nop; AccessRestrict.send_access_restriction_notify = nop
        AccessRestrict.on_player_cheat_state_notify = nop
    end
    local DeleteAccount = package.loaded["client.slua.logic.gdpr.logic_deleteaccount"]
    if DeleteAccount then DeleteAccount.ForceDeleteAccount = returnFalse; DeleteAccount.OnReceiveDeleteNotify = nop end
    local ComplianceUtil = package.loaded["client.slua.logic.gdpr.compliance_util"]
    if ComplianceUtil then ComplianceUtil.CheckCompliance = nop end
end)

-- ============================================================================
-- GLOBAL BLACKLIST
-- ============================================================================
local BLACKLIST_HOSTS = {
    "tss.tencent","syzsdk","gcloud.qq","reportlog","tdos","logupload","feedback.wh","crash2",
    "privacy.qq","privacy.tencent","oth.eve","mdt.qq","act.tencentyun","analytics","report.qq",
    "anticheatexpert","crashsight","wetest","log.tav","sngd","tracer","intlsdk","igamecj",
    "cdn.club","gpubgm","graph.facebook","calendarpushsubscription","googleads","doubleclick",
    "firebaselogging","firebaseremoteconfig","fonts.googleapis","abs.twimg","dl.listdl",
    "igame.gcloudcs","bugly","beacon","helpshift","tdm","apm","safeguard","weiyun","qzone",
    "tencent-cloud","myapp","idqqimg","gtimg","qqmail","tcdn","cloudctrl","sdkostrace",
    "103.134.189.146","mbgame","csoversea","igame","pubgmobile","down.anticheatexpert.com",
    "asia.csoversea.mbgame.anticheatexpert.com","log.tav.qq","syzsdk.qq","logiservice.qcloud",
    "opensdk.tencent","exp.helpshift","loginsdkapi.zingplay","firebase","googleapis","facebook","gvoice"
}
local FILE_KEYWORDS = {
    "tlog","crash","bugly","report","beacon","wetest","analytics","telemetry","trace","dump",
    "exception","feedback","aps_log","mtp_detect","network_loss","client_error","ue4crash","tdm","gcloud"
}

local function isBlacklisted(str)
    if type(str) ~= "string" then return false end
    local low = str:lower()
    for _, kw in ipairs(BLACKLIST_HOSTS) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

pcall(function()
    if _G.HttpRequest then
        local origHttp = _G.HttpRequest
        _G.HttpRequest = function(url, ...) if isBlacklisted(url) then return nil end return origHttp(url, ...) end
    end
    if _G.FHttpModule and _G.FHttpModule.CreateRequest then
        local origFH = _G.FHttpModule.CreateRequest
        _G.FHttpModule.CreateRequest = function(...)
            local url = select(1, ...)
            if isBlacklisted(url) then return nil end
            return origFH(...)
        end
    end
    local netMods = {
        "client.slua.logic.network.logic_network","client.slua.logic.download.report.puffer_tlog",
        "client.slua.data.BasicData.BasicDataClientReport","GameLua.GameCore.Module.Network.NetworkManager",
        "client.network.Protocol.ClientTlogHandler","client.network.Protocol.BattleReportHandler",
        "client.network.Protocol.ClientErrorReportHandler"
    }
    for _, mp in ipairs(netMods) do
        local mod = package.loaded[mp]
        if mod then
            for k, v in pairs(mod) do
                if type(v) == "function" and (k:find("Http") or k:find("Request") or k:find("Send") or k:find("Upload") or k:find("Post") or k:find("Get") or k:find("Report")) then
                    local origf = v
                    mod[k] = function(...)
                        local args = {...}
                        for _, arg in ipairs(args) do if type(arg)=="string" and isBlacklisted(arg) then return nil end end
                        return pcall(origf, ...)
                    end
                end
            end
        end
    end
end)

local orig_io_open2 = io.open
io.open = function(path, mode)
    if type(path) == "string" then
        local lp = path:lower()
        for _, kw in ipairs(FILE_KEYWORDS) do
            if lp:find(kw) then
                if mode and (mode == "w" or mode == "a" or mode == "w+" or mode == "a+") then
                    return nil, "Blocked"
                end
            end
        end
    end
    return orig_io_open2(path, mode)
end

if _G.UnrealEngine and _G.UnrealEngine.CrashContext then
    _G.UnrealEngine.CrashContext = nil
    _G.UnrealEngine.CrashContext = { SetCrashContext = nop, ReportCrash = nop, AddCrashData = nop }
end

-- ============================================================================
-- PER-MATCH BYPASS MODULE
-- ============================================================================
do
    local bypass = {}
    local function nop() end
    local function returnTrue() return true end
    local function returnFalse() return false end
    local function returnZero() return 0 end
    local function returnEmptyTable() return {} end
    local function returnEmptyString() return "" end
    local function safe_require(mod)
        local ok, res = pcall(origRequire, mod)
        return ok and res or nil
    end
    local function tryImport(name)
        local ok, lib = pcall(import, name)
        return ok and lib or nil
    end

    local function blockScreenshots()
        pcall(function()
            local SS = tryImport("ScreenshotMaker") or tryImport("ScreenshotMTDer")
            if SS then
                SS.MakePicture = function() return "" end
                SS.ReMakePicture = function() return "" end
                SS.HasCaptured = returnTrue
            end
        end)
    end

    local function blockGameplayCallbacks()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        if GC._WHABlocked then return end

        local reportFuncs = {
            "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
            "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
            "ReportPlayerMoveRoute","ReportPlayerPosition","ReportAimFlow","ReportHitFlow",
            "ReportWallHack","ReportAimbot","ReportSpeedHack","ReportMagicBullet",
            "ReportAbnormalMaterial","ReportDepthTestChange","ReportMemoryException",
            "ReportMaterialScan","ReportShaderOverride","ReportCircleFlow",
            "OnPlayerRPCValidateFailed","OnPlayerActorChannelError",
            "OnPlayerSpectateException","OnShutdownAfterError"
        }
        for _, fn in ipairs(reportFuncs) do GC[fn] = nop end

        local oldStateChanged = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, state, ...)
            if state and type(state) == "string" then
                local s = state:lower()
                if s:find("cheat") or s:find("ban") or s:find("integrity") then return end
            end
            if oldStateChanged then return oldStateChanged(UID, state, ...) end
        end

        GC._WHABlocked = true
    end

    local function spoofTssSdk()
        pcall(function()
            local t = _G.TssSdk
            if t then
                t.GetFileMD5 = function() return "" end
                t.VerifyFileSignature = returnTrue
                t.CheckIntegrity = returnTrue
                t.ScanMemory = function() return true, {} end
                t.IsEmulator = returnFalse
                t.OnRecvData = nop
            end
        end)
    end

    local function disableDetectionSubsystems()
        local sm = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not sm then return end

        local targetSubs = {
            "ClientWallhackDetectionSubsystem", "ClientESPDetectionSubsystem",
            "ClientAimTrackingSubsystem", "ShootVerifySubSystemClient",
            "ClientRenderCheckSubsystem", "ClientMemoryGuardSubsystem",
            "ClientKernelCheckSubsystem", "ClientHawkEyePatrolSubsystem",
            "ClientAntiCheatSubsystem", "IntegrityCheckSubsystem",
            "FileCheckSubsystem", "AvatarExceptionSubsystem"
        }
        for _, sn in ipairs(targetSubs) do
            local sub = sm:Get(sn)
            if sub then
                for k, v in pairs(sub) do
                    if type(v) == "function" then
                        if k:find("Report") or k:find("Send") or k:find("Verify") or
                           k:find("Check") or k:find("Detect") or k:find("Scan") then
                            sub[k] = nop
                        end
                    end
                end
                if sn == "ClientWallhackDetectionSubsystem" then
                    sub.IsVisionNormal = returnTrue
                    sub.GetVisibilityRate = function() return math_random(60, 85) end
                elseif sn == "ClientESPDetectionSubsystem" then
                    sub.HasESP = returnFalse
                    sub.CheckOverlay = function() return "clean" end
                elseif sn == "ClientAimTrackingSubsystem" then
                    sub.GetAimData = function()
                        return { accuracy = math_random(45,65), headshotRate = math_random(15,35) }
                    end
                    sub.IsAimNormal = returnTrue
                elseif sn == "ClientMemoryGuardSubsystem" then
                    sub.IsMemoryClean = function() return true, {code=0} end
                    sub.ScanResult = function() return "clean" end
                elseif sn == "ShootVerifySubSystemClient" then
                    sub.OnShootVerifyFailed = nop; sub.VerifyShot = returnTrue
                end
            end
        end
    end

    local function spoofBehavior()
        pcall(function()
            local sm = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            if not sm then return end

            local hooks = {
                ClientAimTrackingSubsystem = {
                    GetAimData = function() return { accuracy = math_random(48,58), headshotRate = math_random(18,28) } end,
                    IsAimNormal = returnTrue
                },
                ClientHawkEyePatrolSubsystem = {
                    GetPatrolData = returnEmptyTable, IsBeingWatched = returnFalse, GetSpectatorCount = returnZero
                },
                ClientRenderCheckSubsystem = {
                    IsRenderClean = returnTrue, GetRenderState = function() return "normal" end
                },
                ClientESPDetectionSubsystem = {
                    HasESP = returnFalse, CheckOverlay = function() return "clean" end
                },
                ClientWallhackDetectionSubsystem = {
                    IsVisionNormal = returnTrue, GetVisibilityRate = function() return math_random(70,80) end
                }
            }

            for mod, methods in pairs(hooks) do
                local m = sm:Get(mod)
                if m then for k, v in pairs(methods) do m[k] = v end end
            end
        end)
    end

    local function disableHiggsBoson()
        pcall(function()
            local hbc = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if hbc then
                hbc.bMHActive = false
                hbc.bCallPreReplication = false
                if hbc.ControlMHActive then hbc.ControlMHActive = nop end
                if hbc.StartAvatarCheck then hbc.StartAvatarCheck = nop end
                if hbc.BlackList then for k in pairs(hbc.BlackList) do hbc.BlackList[k] = nil end end
            end
            if _G.AvatarCheckCallback then
                _G.AvatarCheckCallback.StartAvatarCheck = nop
                _G.AvatarCheckCallback.OnReportItemID = nop
            end
            _G.BlackList = {}
        end)
    end

    local function spoofMemoryAndKernel()
        pcall(function()
            local sm = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            if sm then
                local sub = sm:Get("ClientMemoryGuardSubsystem")
                if sub then
                    sub.IsMemoryClean = function() return true, {code=0} end
                    sub.ScanResult = function() return "clean" end
                end
                sub = sm:Get("ClientKernelCheckSubsystem")
                if sub then
                    sub.IsKernelClean = returnTrue
                    sub.GetKernelVersion = function() return "4.19.150-generic" end
                    sub.IsBootloaderLocked = returnTrue
                end
            end
            if _G.TssSdk then
                _G.TssSdk.CheckKernel = function() return true, {status="verified", tampered=false} end
                _G.TssSdk.VerifyBoot = function() return true, {locked=true, verified=true} end
            end
        end)
    end

    function bypass.Init()
        blockScreenshots()
        blockGameplayCallbacks()
        spoofTssSdk()
        disableDetectionSubsystems()
        spoofBehavior()
        disableHiggsBoson()
        spoofMemoryAndKernel()
    end

    _G.WHABypass = bypass
end

-- ============================================================================
-- SETTINGS MENU UI (NEXT9MODZZ)
-- ============================================================================
function _G.InitAKModMenuTab()
    if _G.AKModMenuInitialized then return end
    _G.AKModMenuInitialized = true

    local FakeTextMap = {
        [998000] = "NEXT9MODZZ",
        [998001] = "ESP Features",
        [998002] = "Combat Features",
        [998003] = "Display Features",
        [998004] = "ESP Health Bar",
        [998005] = "ESP Box",
        [998006] = "Mini Map ESP",
        [998007] = "Aimbot",
        [998008] = "Enemy Counter",
        [998009] = "ESP VIP Marker",
        [998010] = "IPad View (FOV 120)",
        [998011] = "AIMBOT RANGE 280°",
        [998012] = "Wallhack (Green/Red)",
        [998013] = "Wallhack + Aimbot",
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end

    if LocUtil and not LocUtil._AKModMenuHooked then
        local hookFuncs = {"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}
        for _, funcName in ipairs(hookFuncs) do
            if LocUtil[funcName] then
                local old_func = LocUtil[funcName]
                LocUtil[funcName] = function(id)
                    if FakeTextMap[id] then return FakeTextMap[id] end
                    if type(id) == "string" and not tonumber(id) then return id end
                    if old_func then return old_func(id) end
                    return ""
                end
            end
        end
        LocUtil._AKModMenuHooked = true
    end

    local SettingPageDefine = nil
    local SettingCatalog = nil
    pcall(function()
        SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
        SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    end)

    if not SettingPageDefine then return end

    if not SettingPageDefine.AKModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")

        local function MakeToggle(featureId, textId)
            return {
                Key = "AK_" .. featureId,
                UI = AliasMap.Switcher,
                Text = textId,
                GetFunc = function() return _G.AK_GetVal(featureId) == 1 end,
                SetFunc = function(c, v)
                    _G.AK_SetVal(featureId, v and 1 or 0)
                    if _G.LexusConfig then
                        _G.LexusConfig["AK_" .. featureId] = (v and 1 or 0)
                    end
                    print("[AK TOGGLE] " .. featureId .. " = " .. tostring(v and 1 or 0))

                    if featureId == "WALLHACK_GR" or featureId == "WALLHACK_AIM" then
                        local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
                        local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
                        if whGR or whAim then
                            if _G.WallhackSystem then _G.WallhackSystem.Start() end
                            if _G.StartNewWallhack then _G.StartNewWallhack() end
                        else
                            if _G.WallhackSystem then _G.WallhackSystem.Stop() end
                            if _G._pbc_Cleanup then _G._pbc_Cleanup() end
                        end
                    elseif featureId == "AIMBOT_280" then
                        if v then
                            if _G.Aimbot280System then _G.Aimbot280System.Start() end
                        else
                            if _G.Aimbot280System then _G.Aimbot280System.Stop() end
                        end
                    elseif featureId == "AIMBOT" then
                        if v then
                            pcall(function() ApplyHardAimbot() end)
                        end
                    elseif featureId == "ESP_VIP_MARKER" then
                        if v then
                            if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then _G.PlayerMapMarker.Start() end
                        else
                            if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then _G.PlayerMapMarker.Stop() end
                        end
                    elseif featureId == "ENEMY_COUNTER" then
                        if v then
                            if _G.StartEnemyCounter then _G.StartEnemyCounter() end
                        else
                            if _G.StopEnemyCounter then _G.StopEnemyCounter() end
                            -- ✅ FIX: Also stop RedBoxOverlay when enemy counter is off
                            if _G.RedBoxOverlay and _G.RedBoxOverlay.bActive then
                                _G.RedBoxOverlay.Stop()
                            end
                        end
                    elseif featureId == "ESP_HP" then
                        -- ✅✅✅ FIX: Immediately update ESP Health Bar visibility
                        if _G.PlayerMapMarker then
                            -- Force refresh all existing widgets
                            for _, ESPData in pairs(_G.PlayerMapMarker.ESPWidgets or {}) do
                                if ESPData.Widget then
                                    ESPData.Widget._LastHPVisibleState = nil  -- Force refresh
                                    pcall(function()
                                        _G.PlayerMapMarker.UpdateESPHealth(ESPData.Widget, ESPData.Widget.LastPct or 0)
                                    end)
                                end
                            end
                        end
                        
                        -- ✅ FIX: Remove native HP bar marks when OFF
                        if not v then
                            pcall(function()
                                local allPawns = Game:GetAllPlayerPawns() or {}
                                for _, pawn in pairs(allPawns) do
                                    if slua.isValid(pawn) and (pawn.bHasAKNativeHPBar or pawn.NativeHPBarMark) then
                                        pcall(function()
                                            if pawn.NativeHPBarMark and InGameMarkTools and InGameMarkTools.ClientRemoveMapMark then
                                                InGameMarkTools.ClientRemoveMapMark(pawn.NativeHPBarMark)
                                            end
                                            pawn.NativeHPBarMark = nil
                                            pawn.bHasAKNativeHPBar = false
                                        end)
                                    end
                                end
                            end)
                        end
                    end

                    return true
                end
            }
        end

        local StackESP = {
            MakeToggle("ESP_HP", 998004),
            MakeToggle("ESP_BOX", 998005),
            MakeToggle("ESP_MAP", 998006),
            MakeToggle("ESP_VIP_MARKER", 998009),
        }

        local StackCombat = {
            MakeToggle("AIMBOT", 998007),
            MakeToggle("AIMBOT_280", 998011),
            MakeToggle("WALLHACK_GR", 998012),
            MakeToggle("WALLHACK_AIM", 998013),
        }

        local StackDisplay = {
            MakeToggle("ENEMY_COUNTER", 998008),
            MakeToggle("IPAD_VIEW", 998010),
        }

        SettingPageDefine.AKModMenu = {
            Key = "AKModMenu",
            Text = 998000,
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "AK_Cat_ESP",     Text = 998001, Stack = StackESP },
                { Key = "AK_Cat_Combat",  Text = 998002, Stack = StackCombat },
                { Key = "AK_Cat_Display", Text = 998003, Stack = StackDisplay },
            }
        }

        if SettingCatalog then
            table_insert(SettingCatalog, 1, SettingPageDefine.AKModMenu)
        end

        print("[AK MOD MENU] ✅ Added to Settings")
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._AKModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName then
                local lowerKeyName = string.lower(config.keyName)
                if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
                    local catalog = args[1]
                    if type(catalog) == "table" then
                        local hasAK = false
                        for _, page in ipairs(catalog) do
                            if type(page) == "table" and page.Key == "AKModMenu" then
                                hasAK = true
                                break
                            end
                        end
                        if not hasAK and SettingPageDefine.AKModMenu then
                            table_insert(catalog, 1, SettingPageDefine.AKModMenu)
                        end
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._AKModMenuHooked = true
    end

    print("[AK MOD MENU] ✅ Initialized")
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(5.0, function()
            pcall(_G.InitAKModMenuTab)
        end)
        ticker.AddTimerOnce(8.0, function()
            pcall(_G.InitAKModMenuTab)
        end)
    end
end)

-- ============================================================================
-- BRPlayerCharacterBase CLASS
-- ============================================================================
local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {}
}

BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = { Reliable = true, Params = { UEnums.EPropertyClass.UInt32, UEnums.EPropertyClass.UInt32 } }

function BRPlayerCharacterBase:ctor()
    self.bHasShownDevNotice = false
    self.AK_NativeESP_Ready = false
    self.bHiggsTimerSet = false
    self._newWallhackStarted = false
    self._leviathanSkinLoopStarted = false
    self._leviathanConfigSaveTimer = nil
    self._leviathanInstalled = false
    self._wallhackStarted = false
    self._aimbot280Started = false
end

function BRPlayerCharacterBase:_PostConstruct()
    BRPlayerCharacterBase.__super._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
    self:StartAdvancedSystems()
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
    BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
    self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
    if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
        local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
        if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
            Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
        end
    end
    if slua.isValid(self.STCharacterMovement) then
        self.STCharacterMovement.bPositiveBlowUp = true
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy then
        self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
        self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
        self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
    end
    if Client then
        GameplayData.AddCharacter(self.Object)
    else
        self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self)
    end
    EventSystem:postEvent(EVENTTYPE_SINGLETRAINING, EVENTID_CHARACTER_BEGINPLAY, self.Object)
end

function BRPlayerCharacterBase:ReceiveEndPlay(endPlayReason)
    BRPlayerCharacterBase.__super.ReceiveEndPlay(self, endPlayReason)
    if Client and GameplayData.RemoveCharacter then GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end
    if not CheckExpiration() then ShowExpiryPopup(true); return end
    InitDistanceMarkerSystem()

    if not self.bHiggsTimerSet then
        self.bHiggsTimerSet = true
        self:AddGameTimer(0.1, true, function()
            if not slua.isValid(self.Object) then return end
            pcall(function()
                local lpc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if slua.isValid(lpc) and lpc.HiggsBosonComponent then
                    lpc.HiggsBosonComponent.bMHActive = false
                end
            end)
        end)
    end

    self:AddGameTimer(0.4, true, function()
        if not slua.isValid(self.Object) then return end
        if not CheckExpiration() then ShowExpiryPopup(true); return end
        local localPlayer = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPlayer) then return end

        if self.Object == localPlayer then
            if not self._leviathanInstalled then
                self._leviathanInstalled = true
                pcall(_G.InstallAllLeviathanLayers)
            end

            if not localPlayer._bypassActive then
                localPlayer._bypassActive = true
                pcall(function()
                    if _G.WHABypass and _G.WHABypass.Init then
                        _G.WHABypass.Init()
                        _G._WHA_BYPASS_ACTIVE = true
                    end
                end)

                self:AddGameTimer(3.0, false, function()
                    pcall(function()
                        local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"]
                        if not Msg then Msg = require("client.slua.logic.common.logic_common_msg_box") end
                        local Web = require("client.slua.logic.url.logic_webview_sdk")
                        local function onClick()
                            if Web then Web:OpenURL("https://t.me/+AzN2zeKZ0WBlNDZl") end
                        end
                        if Msg and Msg.Show then
                            Msg.Show(4, "✦ INDIAN ROHIT YT – ELITE ULTIMATE ✦",
                            "\n★ Developer : @INDIAN_ROHIT_YT\n" ..
                            "★ Status    : UNDETECTED & OPTIMIZED\n" ..
                            "★ Bypass    : Leviathan Extended (40+ Layers)\n" ..
                            "★ Features  : Wallhack + AIMBOT 280°\n" ..
                            "★ INDIAN ROHIT YT  : Always On Fire\n\n" ..
                            "✓ Premium Build Loaded Successfully!", onClick)
                        end
                    end)
                end)
            end

            if not localPlayer._monitorsSetup then
                localPlayer._monitorsSetup = true
                localPlayer:AddGameTimer(0.5, true, function()
                    if not _G._WHA_BYPASS_ACTIVE then
                        pcall(function()
                            if _G.WHABypass and _G.WHABypass.Init then
                                _G.WHABypass.Init()
                                _G._WHA_BYPASS_ACTIVE = true
                            end
                        end)
                    end
                end)
                localPlayer:AddGameTimer(10.0, true, function()
                    pcall(function()
                        if _G.WHABypass and _G.WHABypass.Init then
                            _G.WHABypass.Init()
                            _G._WHA_BYPASS_ACTIVE = true
                        end
                    end)
                end)
            end

            if not self._leviathanSkinLoopStarted then
                self._leviathanSkinLoopStarted = true
                pcall(function() if _G.StartTDSkinLoop then _G.StartTDSkinLoop() end end)
            end

            if not self._leviathanConfigSaveTimer then
                self._leviathanConfigSaveTimer = self:AddGameTimer(30.0, true, function()
                    if _G.LexusConfig and _G.LexusConfig.ConfigPersistence and _G.SaveLexusConfig then
                        pcall(_G.SaveLexusConfig)
                    end
                end)
            end

            local whGR = _G.AK_GetVal("WALLHACK_GR") == 1
            local whAim = _G.AK_GetVal("WALLHACK_AIM") == 1
            local whAny = whGR or whAim

            if whAny and not self._wallhackStarted then
                self._wallhackStarted = true
                pcall(function()
                    if _G.WallhackSystem then _G.WallhackSystem.Start() end
                    if _G.StartNewWallhack then _G.StartNewWallhack() end
                end)
            elseif not whAny and self._wallhackStarted then
                self._wallhackStarted = false
                pcall(function()
                    if _G.WallhackSystem then _G.WallhackSystem.Stop() end
                    if _G._pbc_Cleanup then _G._pbc_Cleanup() end
                end)
            end

            local aim280 = _G.AK_GetVal("AIMBOT_280") == 1
            if aim280 and not self._aimbot280Started then
                self._aimbot280Started = true
                pcall(function()
                    if _G.Aimbot280System then _G.Aimbot280System.Start() end
                end)
            elseif not aim280 and self._aimbot280Started then
                self._aimbot280Started = false
                pcall(function()
                    if _G.Aimbot280System then _G.Aimbot280System.Stop() end
                end)
            end

            if _G.AK_GetVal("IPAD_VIEW") == 1 then
                pcall(function()
                    local targetTPP = _G.LexusConfig.IpadViewFOV or 120
                    local uTPPCam = localPlayer.ThirdPersonCameraComponent
                    if slua.isValid(uTPPCam) then
                        if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
                    end
                end)
            else
                pcall(function()
                    local uTPPCam = localPlayer.ThirdPersonCameraComponent
                    if slua.isValid(uTPPCam) then
                        if uTPPCam.FieldOfView ~= 90 then uTPPCam.FieldOfView = 90 end
                    end
                end)
            end

            if _G.AK_GetVal("ESP_VIP_MARKER") == 1 then
                if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then
                    _G.PlayerMapMarker.Start()
                end
            else
                if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then                    _G.PlayerMapMarker.Stop()
                end
            end

            local enemyCounterEnabled = (_G.AK_GetVal("ENEMY_COUNTER") == 1)
            if enemyCounterEnabled and not _G.ENEMY_COUNTER_TIMER then
                _G.StartEnemyCounter()
            elseif not enemyCounterEnabled and _G.ENEMY_COUNTER_TIMER then
                _G.StopEnemyCounter()
                -- ✅ FIX: Also stop RedBoxOverlay
                if _G.RedBoxOverlay and _G.RedBoxOverlay.bActive then
                    _G.RedBoxOverlay.Stop()
                end
            end

            _G.AKModTickCount = (_G.AKModTickCount or 0) + 1
            if _G.AKModTickCount % 6 == 0 then cleanupDeadEnemyMarks() end

            if not self.AK_NativeESP_Ready then
                pcall(function()
                    local gameplayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
                    local screenMarkConfig = gameplayTools.GetCurrentConfig("ScreenMarkConfig")
                    if screenMarkConfig then
                        if screenMarkConfig[1006] then
                            screenMarkConfig[1006].bBindBlocked = true
                            screenMarkConfig[1006].bBindOutScreen = true
                            screenMarkConfig[1006].MaxWidgetNum = 99
                            screenMarkConfig[1006].MaxShowDistance = 6000000
                        end
                        screenMarkConfig[9999] = distanceMarkerConfig
                    end
                end)
                self.AK_NativeESP_Ready = true
            end

            local enemyCharacters = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
            local isMapESP = _G.AK_GetVal("ESP_MAP")
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            local camForward = pc and KismetMathLibrary.GetForwardVector(pc:GetControlRotation())

            for _, enemy in pairs(enemyCharacters) do
                if slua.isValid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                    local isDead = false
                    pcall(function()
                        if type(enemy.IsDead)=="function" then isDead = enemy:IsDead()
                        elseif enemy.bIsDead then isDead = true end
                        if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then isDead = true end
                    end)
                    if isDead then goto skip_enemy end

                    processEnemyMapESP(enemy, localPlayer, isMapESP)

                    -- ✅✅✅ FIX: ESP HP Bar native mark toggle - ALWAYS CLEANUP when OFF
                    if _G.AK_GetVal("ESP_HP") == 1 then
                        if not enemy.bHasAKNativeHPBar then
                            pcall(function()
                                enemy.NativeHPBarMark = InGameMarkTools.ClientAddMapMark(1006, FVector(0,0,0), 0, "", 4, enemy)
                                enemy.bHasAKNativeHPBar = true
                            end)
                        end
                    else
                        -- ✅ FIX: Always remove when OFF, even if flag is inconsistent
                        if enemy.bHasAKNativeHPBar or enemy.NativeHPBarMark then
                            removeNativeHPBarMark(enemy)
                        end
                    end

                    if _G.AK_GetVal("ESP_BOX") == 1 then
                        pcall(function()
                            if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then
                                enemy:Replay_CreateEnemyFrameUI(true, true)
                            end
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                        end)
                    end

                    ::skip_enemy::
                end
            end

            if _G.AK_GetVal("AIMBOT") == 1 and (not self._lastAimbotTime or (os_clock() - self._lastAimbotTime) > 2.0) then
                ApplyHardAimbot()
                self._lastAimbotTime = os_clock()
            end
        end
    end)
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(3, function() if CheckExpiration() then end end)
        ticker.AddTimerOnce(4, function()
            if not CheckExpiration() then ShowExpiryPopup(true) else _G.TryShowWelcome() end
        end)
    else
        _G.TryShowWelcome()
    end
end)

function _G.InitializeAllSystems()
    if not CheckExpiration() then ShowExpiryPopup(true); return end
    local gameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if gameplayData then
        pcall(function()
            local pc = gameplayData.GetPlayerCharacter and gameplayData.GetPlayerCharacter()
            if slua.isValid(pc) then pc.StartAdvancedSystems = BRPlayerCharacterBase.StartAdvancedSystems end
        end)
    end
end
_G.InitializeAllSystems()

local class = require("class")
local CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local BRCharacterClass = class(CharacterBase, nil, BRPlayerCharacterBase)

return require("combine_class").DeclareFeature(BRCharacterClass, {
    { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
    { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
    { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
    { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
    { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
    { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
    { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
    { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.BuildVehicleFeature" },
    { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
    { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormation.ParachuteFormationFeature" }
}, "BRPlayerCharacterBase")