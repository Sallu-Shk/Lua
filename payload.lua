-- ====================================================================
-- BRPlayerCharacterBase.lua — TESLA 10X GAMING VIP 4.6
-- @OfficialOwner10x 🔥
-- ESP (Box + Line + Skeleton + Name + Distance + HP) + Headshot
-- iPad View + Color Changer + Stronger Bypass
-- ====================================================================

local BRPlayerCharacterBase = { ServerRPC = {}, ClientRPC = {}, MulticastRPC = {}, LuaEventContainer = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

-- ==================== BASE CLASS ====================
function BRPlayerCharacterBase:ctor() end
function BRPlayerCharacterBase:_PostConstruct() BRPlayerCharacterBase.__super._PostConstruct(self); self:InitAddSpecialMoveInfo(); self.bCanNearDeathGiveup = true end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local c = import("CheckFallingDistanceComponent")
    if slua.isValid(c) and not slua.isValid(self:GetComponentByClass(c)) then Game:AddComponent(c, self, "CheckFallingDistanceComponent") end
  end
  if slua.isValid(self.STCharacterMovement) then self.STCharacterMovement.bPositiveBlowUp = true end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
  end
  if Client then GameplayData.AddCharacter(self.Object)
  else self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self) end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local m = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(m.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local gt = CGameMode.GameModeType; local gid = tonumber(CGameState.GameModeID)
    local a = gt == EGameModeType.ETypicalGameMode or gt == EGameModeType.EFourInOneGameMode or gt == EGameModeType.EHeavyWeaponGameMode
    return a and (not MatchModeIds[gid])
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(L, N)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, L, N)
  if not Client then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then
      if N == EParachuteState.PS_Opening then
        if uPC.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then uPC.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI() end
      elseif N == EParachuteState.PS_None then
        if uPC.CheckParachuteOpenFeature.RecoverParachuteOpenParam then uPC.CheckParachuteOpenFeature:RecoverParachuteOpenParam() end
        if uPC.CheckParachuteOpenFeature.ClearTimerAndState then uPC.CheckParachuteOpenFeature:ClearTimerAndState() end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
  if not Client then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then
      if uPC.CheckParachuteOpenFeature.ClearTimerAndState then uPC.CheckParachuteOpenFeature:ClearTimerAndState() end
      if uPC.CheckParachuteOpenFeature.ResetCheckShowUI then uPC.CheckParachuteOpenFeature:ResetCheckShowUI() end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(r) BRPlayerCharacterBase.__super.ReceiveEndPlay(self, r); if Client then GameplayData.RemoveCharacter(self.Object) end end
function BRPlayerCharacterBase:IsWarGameMode()
  local gs = GameplayData:GetGameState()
  if slua.isValid(gs) and Game:IsClassOf(gs, STExtraGameStateBase) then return gs.GameModeType == EGameModeType.EWarGameMode end
  return false
end
function BRPlayerCharacterBase:BPOnRecycled() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:BPOnRespawned() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:ReceiveOnRecycle() if Client then self:ResetMeshRelativeLocationAndRotation() GameplayData.RemoveCharacter(self.Object) end end
function BRPlayerCharacterBase:ReceiveOnSpawn() if Client then self:ResetMeshRelativeLocationAndRotation() GameplayData.AddCharacter(self.Object) end end
function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local r = FRotator(0, -90, 0); local l = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then self.Mesh:K2_SetRelativeRotation(r, false, nil, false) end
    self:CacheInitialMeshOffset(l, r)
  end
end
function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end
function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end
function BRPlayerCharacterBase:PreAttachedToVehicle()
  if not UKismetSystemLibrary.IsDedicatedServer(self) then return end
  local pc = self:GetPlayerControllerSafety()
  if not slua.isValid(pc) then return end
  local av = self.CharacterAvatarComp2_BP
  if not slua.isValid(av) then return end
  local util = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local vid = util:ChangeVehicleSkinByClothes(pc, av)
  local t = import("ESTExtraVehicleShapeType")
  if vid then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(vid) == t.VST_Horse then
      local ps = self:GetPlayerStateSafety()
      if slua.isValid(ps) then ps:AddGeneralCount(468, 1, false) end
    end
  end
end
function BRPlayerCharacterBase:ParachuteJump()
  local pc = self:GetControllerSafety()
  if slua.isValid(pc) then
    if not self:GetEnsure() then
      if pc:GetCurrentStateType() ~= EStateType.State_ParachuteJump and pc:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        pc:ReInitParachuteItem()
        pc:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
    else EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object) end
  end
end
function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uChar, uNew, uOld)
  if uChar ~= self.Object then return end
  local crane = self:GetMedievalCraneFromBase(uNew)
  if crane and crane.AddCharacter then crane:AddCharacter(self.Object)
  else crane = self:GetMedievalCraneFromBase(uOld); if crane and crane.RemoveCharacter then crane:RemoveCharacter(self.Object) end end
end
function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then return end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then return end
  if not Lifter.AddCharacter then return end
  return Lifter
end
function BRPlayerCharacterBase:CheckForbidFlaregun()
  local ps = self:GetPlayerStateSafety()
  if not slua.isValid(ps) then return false end
  if ps.CanUseFlaregun == false and self:IsLocallyControlled() then
    local pc = self:GetPlayerControllerSafety()
    if slua.isValid(pc) then pc:DisplayGameTipWithMsgID(48532) end
  end
  return not ps.CanUseFlaregun
end
function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end
function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local comp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(comp) and self.bCanNearDeathGiveup == true then
    local ps = self:GetPlayerStateSafety()
    if slua.isValid(ps) then ps:AddGeneralCount(1613, 1, false) end
    comp:TriggerGotoDieExplictly(self.Object)
  end
end
function BRPlayerCharacterBase:RPC_Server_GmPlayAction(id)
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then self:MulticastRPC_GmPlayAction(id) end
end
function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(id)
  if not Client then return end
  local comp = self:GetPlayEmoteComponent()
  if not slua.isValid(comp) then return end
  local cfg = CDataTable.GetTableData("EmoteBPTable", id)
  if not cfg then return end
  local hp = cfg.Path; local A = slua.loadObject(hp)
  local arr = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local h = A(); comp:OnLoadEmoteAssetBegin(h, id, arr, "")
  local tb = FuncUtil.LuaArrayToTable(arr); local au = require("common.asset_util")
  local function later() comp:OnLoadEmoteAssetEnd(h, id, 0) end
  au.GetAssetsArrayAsyncParallel(tb, later)
end
function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(v)
  if slua.isValid(self.ParachuteComponent) then self.ParachuteComponent.bServerSyncShouldCheckPassWall = v end
end
function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState() self.Super:OnPlayerEnterCarryBoxState(); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end end
function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(b) self.Super:OnPlayerLeaveCarryBoxState(b); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(b) end end
function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uIn)
  if slua.isValid(uIn) and Game:IsClassOf(uIn, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uIn)
  end
end
function BRPlayerCharacterBase:SetAreaID(id) self:SetAttrValue("AreaID", id, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end
function BRPlayerCharacterBase:DoModChangeToBT() if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end end
function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end
end
function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end
end
function BRPlayerCharacterBase:SwitchCameraToNormal()
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then self.ParachuteFormation:OnLandingClearFormationCamera() end
end
function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local w = self:GetWeaponBySlot(Slot)
    if slua.isValid(w) then
      local wid = w:GetWeaponID()
      local cfg = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if cfg and cfg.CheckIsWeaponInBlackList and cfg.CheckIsWeaponInBlackList(wid) then
        local pc = self:GetPlayerControllerSafety()
        if Client and slua.isValid(pc) and pc.Role == ENetRole.ROLE_AutonomousProxy then pc:DisplayGameTipWithMsgID(47306) end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local o = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(o) then
      local s = o:GetCurMoveState()
      if s == ESpiderSwingMoveState.Launching or s == ESpiderSwingMoveState.Swinging then return false end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ====================================================================
-- ==================== MOD LOGIC =====================================
-- ====================================================================

local BRAND = "TESLA 10X GAMING"
local BRAND_DEV = "@OfficialOwner10x 🔥"
local VERSION = "4.6"
local _slua = rawget(_G, "slua")

local function Valid(o)
    if not o then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, o)
        if not ok or not v then return false end
    end
    return true
end

local function Notify(msg)
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then Msg.Show(1, "⚡ " .. BRAND .. " VIP ⚡", tostring(msg), function() end, function() end, "OK", "") return end
    end)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage("[" .. BRAND .. "]" .. tostring(msg), -1, 3.0, {R=1,G=0.85,B=0,A=1}, {X=1.2, Y=1.2})
        end
    end)
    print("[" .. BRAND .. "] " .. tostring(msg))
end
_G.LexusNotify = Notify

-- ==================== CONFIG ====================
_G.LexusConfig = _G.LexusConfig or {
    EspLoai9 = false,
    Esp9_Count = true,
    Esp9_Name = true,
    Esp9_Distance = true,
    Esp9_HP = true,
    Esp9_Line = true,
    Esp9_Box = true,
    Esp9_Skeleton = false,
    -- NEW: Color modes
    LineColorMode = 1,      -- 1=Green 2=Red 3=Cyan 4=White 5=Yellow 6=Magenta
    BoxColorPlayer = 1,     -- Green
    BoxColorBot = 3,        -- Cyan
    -- NEW: iPad View
    IpadView = false,
    -- Headshot
    Headshot = false,
    FakeHWID = false,
}

_G.LexusState = _G.LexusState or {
    LoopToken = 0, NativeESPReady = false, MenuStep = 0,
    CustomTextData = { IpadFOV = 120 }, EnemyMarks = {}, PrevGraphicsState = {},
}

-- ==================== COLOR PALETTE ====================
local COLOR_PALETTE = {
    [1] = {R=0,   G=1,   B=0,   A=1, name="Green"},
    [2] = {R=1,   G=0.15,B=0.15,A=1, name="Red"},
    [3] = {R=0,   G=1,   B=1,   A=1, name="Cyan"},
    [4] = {R=1,   G=1,   B=1,   A=1, name="White"},
    [5] = {R=1,   G=0.95,B=0,   A=1, name="Yellow"},
    [6] = {R=1,   G=0,   B=1,   A=1, name="Magenta"},
}

local function GetColorFromMode(mode)
    local c = COLOR_PALETTE[mode] or COLOR_PALETTE[1]
    local LC = import("LinearColor")
    if LC then return LC(c.R, c.G, c.B, c.A) end
    return c
end

-- ==================== HEADSHOT ====================
pcall(function()
    if _G._HSHooked then return end
    _G._HSHooked = true
    local function DoHook()
        local paths = {"GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity","GameLua.Logic.Weapon.ShootWeaponEntity"}
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end
        for _, p in ipairs(paths) do
            local mod = package.loaded[p]
            if mod then
                if not mod._HSOrigGet then
                    mod._HSOrigGet = mod.GetHitBodyType
                    mod._HSOrigGetByPos = mod.GetHitBodyTypeByHitPos
                end
                mod.GetHitBodyType = function(self, a, b)
                    if _G.LexusConfig.Headshot then return EAvatarDamagePosition.BigHead end
                    if mod._HSOrigGet then return mod._HSOrigGet(self, a, b) end
                end
                mod.GetHitBodyTypeByHitPos = function(self, a)
                    if _G.LexusConfig.Headshot then return EAvatarDamagePosition.BigHead end
                    if mod._HSOrigGetByPos then return mod._HSOrigGetByPos(self, a) end
                end
            end
        end
    end
    DoHook()
    local ok, tk = pcall(require, "common.time_ticker")
    if ok and tk and tk.AddTimerOnce then
        for i = 1, 10 do tk.AddTimerOnce(i * 2.0, function() pcall(DoHook) end) end
    end
end)

-- ==================== STRONGER BYPASS (MD5 + Skin + Log + Higgs) ====================
pcall(function()
    local function nop() end
    local function retFalse() return false end
    local function retTrue() return true end
    local function retZero() return 0 end
    local function retEmpty() return {} end
    local function retEmptyStr() return "" end

    -- 1. Subsystem report block
    local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if subMgr then
        local targets = {"CoronaLabSubsystem","ClientReportPlayerSubsystem","DSReportPlayerSubsystem",
            "ShootVerifySubSystemClient","BehaviorScoreSubsystem","AntiCheatSubsystem",
            "GameReportSubsystem","OperationalStatsSubsystem","SwiftHawkSubsystem",
            "PlayerSecurityInfoSubsystem","ModifierExceptionSubsystem","IntegrityCheckSubsystem",
            "FileCheckSubsystem","MemoryCheckSubsystem","SpeedCheckSubsystem","WallCheckSubsystem",
            "AvatarExceptionSubsystem","ClientDataStatistcsSubsystem","AFKReportorSubsystem",
            "ClientCircleFlowSubsystem","MrpcsFlowSubsystem","ReplaySubsystem"}
        for _, n in ipairs(targets) do
            local s = subMgr:Get(n)
            if s then
                for k, v in pairs(s) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Collect") or k:find("Scan")) then
                        pcall(function() s[k] = nop end)
                    end
                end
                for _, tf in ipairs({"TimerHandle","timer","heartbeatTimer","reportTimer","scanTimer","checkTimer"}) do
                    if s[tf] then pcall(function() s:RemoveGameTimer(s[tf]); s[tf] = nil end) end
                end
            end
        end
    end

    -- 2. NetUtil block
    local nu = _G.NetUtil
    if nu and nu.SendPacket and not nu._BypassActive then
        local orig = nu.SendPacket
        local blk = {["ReportAttackFlow"]=1,["ReportSecAttackFlow"]=1,["ReportHitFlow"]=1,
            ["ReportAimFlow"]=1,["ReportPlayerBehavior"]=1,["ReportVerifyInfoFlow"]=1,
            ["ReportFireArms"]=1,["ReportMrpcsFlow"]=1,["ReportTeammatHurt"]=1,
            ["ReportPlayerPosition"]=1,["ReportPlayerMoveRoute"]=1,
            ["on_tss_sdk_anti_data"]=1,["ClientSecMrpcsFlow"]=1,["MrpcsData"]=1,
            ["SwiftHawk"]=1,["ClientSwiftHawk"]=1,["AntiCheatReport"]=1,["CheatDetection"]=1,
            ["ViolationReport"]=1,["SecurityViolation"]=1,["IntegrityCheck"]=1,["SignatureVerify"]=1,
            ["BanPlayer"]=1,["KickPlayer"]=1,["NotifyBan"]=1,["ApplyPunishment"]=1}
        nu.SendPacket = function(name, ...) if blk[name] then return nil end return orig(name, ...) end
        nu._BypassActive = true
    end

    -- 3. GameplayCallbacks null
    if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
    local rpts = {"ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow",
        "ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate",
        "ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow",
        "ReportSecTgameMovingFlow","ReportParachuteData","SendTssSdkAntiDataToLobby",
        "ReportEquipmentFlow","ReportAimFlow","ReportPlayersPing","ReportPlayerIP",
        "ReportPlayerFramePingRecord","ReportDSNetSaturation","ReportNetContinuousSaturate",
        "ReportDSNetRate","ReportCircleFlow","ClientSecMrpcsFlow","SwiftHawk",
        "ClientSwiftHawk","ClientSwiftHawkWithParams","OnShutdownAfterError",
        "OnPlayerActorChannelError","OnPlayerRPCValidateFailed","OnDSPlayerStateChanged"}
    for _, f in ipairs(rpts) do _G.GameplayCallbacks[f] = nop end
    _G.GameplayCallbacks.CheckReportSecAttackFlowWithAttackFlow = retFalse
    _G.GameplayCallbacks.CheckReportSecAttackFlow = retFalse

    -- 4. TSS SDK
    pcall(function()
        local t = package.loaded["TssSdk"] or _G.TssSdk
        if t then
            t.SendReportInfo = nop; t.ScanMemory = retTrue; t.IsEmulator = retFalse
            t.CheckEnvironment = retTrue; t.VerifyProcess = retTrue
            t.GetFileMD5 = function() return "BYPASS" end; t.VerifyFileSignature = retTrue
        end
    end)

    -- 5. MD5 / PAK signature bypass
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue
            FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
    end)

    -- 6. Skin bypass (puffer_tlog, AvatarUtils)
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = retFalse
            AvatarUtils.IsValidAvatar = retTrue
            AvatarUtils.CheckAvatarIntegrity = retTrue
            AvatarUtils.ReportInvalidAvatar = nop
        end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)

    -- 7. Log blocker (Screenshot, TLog, CrashSight)
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then
            SMTD.MTDePicture = function() return "" end
            SMTD.ReMTDePicture = function() return "" end
            SMTD.HasCaptured = retTrue
            SMTD.TakeScreenshot = nop
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop end
    end)

    -- 8. HiggsBoson component
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck","StartAvatarCheck","ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert","ServerReportAvatar","ClientReportNetAvatar","SendHisarData","RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.GetCurWeaponSkinID = retZero
            Higgs.IsMHActive = retFalse
            Higgs.bMHActive = false
        end
    end)

    -- 9. Ban packet absorber
    local ban_packets = {["BanPlayer"]=1,["KickPlayer"]=1,["SuspendPlayer"]=1,["NotifyBan"]=1,
        ["ApplyPunishment"]=1,["ReportCheatResult"]=1,["ProcessBanRequest"]=1,["FairPlayBan"]=1,
        ["SecurityBan"]=1,["TemporaryBan"]=1,["PermanentBan"]=1,["AccountBan"]=1}
    -- (already blocked in NetUtil section above)

    -- 10. DS state ban filter
    if _G.GameplayCallbacks then
        _G.GameplayCallbacks.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = string.lower(tostring(State or ""))
            local blocked_states = {"cheatdetected","banned","kicked","suspended","violationdetected",
                "integrityfailure","securityviolation","permanentban","temporaryban","10yearban","1dayban"}
            for _, bs in ipairs(blocked_states) do
                if s:find(bs, 1, true) then return end
            end
        end
    end

    print("[" .. BRAND .. " BYPASS] 10 layers active")
end)

-- ==================== MENU ====================
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true
    local _FakeText = { [999000] = "⚡ TESLA 10X VIP ⚡", [999001] = "ESP", [999002] = "GRAPHICS", [999003] = "COMBAT" }
    for _, lp in ipairs({"client.common.LocUtil","client.slua.logic.common.LocUtil","common.LocUtil","common.loc_util"}) do
        pcall(function()
            local m = package.loaded[lp] or require(lp)
            if m and not m._10XHooked then
                for _, fn in ipairs({"GetLocalizeResStr","GetText","GetTextByID","GetLocalText","GetLocalizeStr"}) do
                    if m[fn] and type(m[fn]) == "function" then
                        local orig = m[fn]
                        m[fn] = function(id, ...) if _FakeText[id] then return _FakeText[id] end return orig(id, ...) end
                    end
                end
                m._10XHooked = true
            end
        end)
    end
    local SPD = require("client.logic.NewSetting.SettingPageDefine")
    local SC = require("client.logic.NewSetting.SettingCatalog")
    if not SPD.ModMenu then
        local AM = require("client.slua.umg.NewSetting.Item.AliasMap")
        local StackESP = {
            { Key="M_ESP", UI=AM.TitleSwitcher, Text="ESP MASTER", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.EspLoai9 end, SetFunc=function(c,v) _G.LexusConfig.EspLoai9=v return true end },
            { Key="M_EC", UI=AM.Switcher, Text="   Enemy Counter", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Count end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Count=v return true end },
            { Key="M_N", UI=AM.Switcher, Text="   Player Name", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Name end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Name=v return true end },
            { Key="M_D", UI=AM.Switcher, Text="   Distance", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Distance end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Distance=v return true end },
            { Key="M_H", UI=AM.Switcher, Text="   Health Bar", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_HP end, SetFunc=function(c,v) _G.LexusConfig.Esp9_HP=v return true end },
            { Key="M_L", UI=AM.Switcher, Text="   Snap Line", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Line end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Line=v return true end },
            { Key="M_B", UI=AM.Switcher, Text="   Box ESP", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Box end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Box=v return true end },
            { Key="M_S", UI=AM.Switcher, Text="   Skeleton", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Skeleton end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Skeleton=v return true end },
            -- Color options
            { Key="M_LC", UI=AM.Slider, Text="   Line Color (1-6)", ExpandHandle="M_ESP", MinValue=1, MaxValue=6,
              GetFunc=function() return _G.LexusConfig.LineColorMode or 1 end, SetFunc=function(c,v) _G.LexusConfig.LineColorMode = v return true end },
            { Key="M_PC", UI=AM.Slider, Text="   Player Box Color (1-6)", ExpandHandle="M_ESP", MinValue=1, MaxValue=6,
              GetFunc=function() return _G.LexusConfig.BoxColorPlayer or 1 end, SetFunc=function(c,v) _G.LexusConfig.BoxColorPlayer = v return true end },
            { Key="M_BC", UI=AM.Slider, Text="   Bot Box Color (1-6)", ExpandHandle="M_ESP", MinValue=1, MaxValue=6,
              GetFunc=function() return _G.LexusConfig.BoxColorBot or 3 end, SetFunc=function(c,v) _G.LexusConfig.BoxColorBot = v return true end },
        }
        local StackGraphics = {
            { Key="M_IP", UI=AM.TitleSwitcher, Text="IPAD VIEW", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.IpadView end, SetFunc=function(c,v) _G.LexusConfig.IpadView=v return true end },
            { Key="M_IPFOV", UI=AM.Slider, Text="   FOV", ExpandHandle="M_IP", MinValue=1, MaxValue=100,
              GetFunc=function() return (_G.LexusState.CustomTextData.IpadFOV or 120) - 90 end,
              SetFunc=function(c,v) _G.LexusState.CustomTextData.IpadFOV = 90 + v return true end },
        }
        local StackCombat = {
            { Key="M_HS", UI=AM.Switcher, Text="HEADSHOT (BigHead)", GetFunc=function() return _G.LexusConfig.Headshot end, SetFunc=function(c,v) _G.LexusConfig.Headshot=v return true end },
            { Key="M_HW", UI=AM.Switcher, Text="Fake HWID", GetFunc=function() return _G.LexusConfig.FakeHWID end, SetFunc=function(c,v) _G.LexusConfig.FakeHWID=v return true end },
        }
        SPD.ModMenu = { Key = "ModMenu", Text = 999000, UIKey = "Setting_Page_Privacy", Category = {
            { Key="Cat_ESP", Text=999001, Stack=StackESP },
            { Key="Cat_Graphics", Text=999002, Stack=StackGraphics },
            { Key="Cat_Combat", Text=999003, Stack=StackCombat },
        }}
        table.insert(SC, 1, SPD.ModMenu)
    end
    local UIMgr = _G.UIManager
    if UIMgr and not UIMgr._IsModMenuHooked then
        local old = UIMgr.ShowUI
        UIMgr.ShowUI = function(cfg, ...)
            local args = {...}; local n = select('#', ...)
            if cfg and cfg.keyName then
                local lk = string.lower(cfg.keyName)
                if string.find(lk, "setting_main") and not string.find(lk, "custom") then
                    local cat = args[1]
                    if type(cat) == "table" and cat[1] and type(cat[1]) == "table" and cat[1].Key then
                        local has = false
                        for _, p in ipairs(cat) do if type(p) == "table" and p.Key == "ModMenu" then has = true break end end
                        if not has then table.insert(cat, 1, SPD.ModMenu) end
                    end
                end
            end
            local unpack = table.unpack or unpack
            return old(cfg, unpack(args, 1, n))
        end
        UIMgr._IsModMenuHooked = true
    end
end

-- ====================================================================
-- ==================== ESP MODULE =====================================
-- ====================================================================

local SlateBlueprintLibrary, WidgetLayoutLibrary, FVector2D, FVector, FLinearColor, FSlateColor
pcall(function()
    SlateBlueprintLibrary = import("SlateBlueprintLibrary")
    WidgetLayoutLibrary = import("WidgetLayoutLibrary")
    FVector2D = import("Vector2D")
    FVector = import("Vector")
    FLinearColor = import("LinearColor")
    FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
end)

local function IsValidX(obj)
    if not obj then return false end
    if slua and slua.isValid then return slua.isValid(obj) end
    return true
end

local TempProjVec2D = FVector2D and FVector2D(0, 0) or nil
local ColorWhite = FLinearColor and FLinearColor(1, 1, 1, 1) or nil
local ColorYellow = FLinearColor and FLinearColor(1, 0.95, 0, 1) or nil
local ColorBlue = FLinearColor and FLinearColor(0.18, 0.62, 1, 1) or nil

local BoxESP = {
    bActive = true,
    ESPCanvas = nil,
    BoxWidgets = {},
    LineWidgets = {},
    SkeletonWidgets = {},
    CounterData = {
        bCreated = false,
        LastPlayerCount = -1,
        LastBotCount = -1,
        RealBg = nil, RealSlot = nil,
        RealTxt = nil, RealTxtSlot = nil,
        BotBg = nil, BotSlot = nil,
        BotTxt = nil, BotTxtSlot = nil,
    },
    HealthColor = { R = 0, G = 1, B = 0, A = 1 },
    HealthBgColor = { R = 0, G = 0, B = 0, A = 0.85 },
    HealthBarWidth = 3.0,
    CornerThickness = 1.2,
    CornerLengthRatio = 0.28,
    SnapLineThickness = 1.2,
    SnapLineOriginY = 45,  -- NEW: Upar shift (45px from top)
    _CanvasScaleX = 1.0, _CanvasScaleY = 1.0, _CanvasOffsetX = 0.0, _CanvasOffsetY = 0.0,
    _LastCanvas = nil, _LastTransformTime = 0, _LastHeavyUpdateTime = 0,
}

function BoxESP.GetMainCanvas()
    if BoxESP.ESPCanvas and IsValidX(BoxESP.ESPCanvas) then return BoxESP.ESPCanvas end
    local t = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
    if not t then pcall(function() t = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end) end
    if not t then return nil end
    local MainUI = t.GetMainControlBaseUI and t.GetMainControlBaseUI()
    if not IsValidX(MainUI) then return nil end
    local PC = nil
    if MainUI.CanvasPanel_0 and IsValidX(MainUI.CanvasPanel_0) then PC = MainUI.CanvasPanel_0
    elseif MainUI.CanvasPanel_42 and IsValidX(MainUI.CanvasPanel_42) then PC = MainUI.CanvasPanel_42 end
    if PC then BoxESP.ESPCanvas = PC; BoxESP._LastCanvas = PC end
    return PC
end

function BoxESP.UpdateCanvasTransform(PC)
    if not BoxESP.ESPCanvas or not IsValidX(BoxESP.ESPCanvas) then return end
    local success = false
    if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
        local cg = BoxESP.ESPCanvas:GetCachedGeometry()
        if cg then
            local pt0 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(0, 0))
            local pt1 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(100, 100))
            if pt0 and pt1 then
                BoxESP._CanvasScaleX = (pt1.X - pt0.X) / 100
                BoxESP._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                BoxESP._CanvasOffsetX = pt0.X; BoxESP._CanvasOffsetY = pt0.Y
                success = true
            end
        end
    end
    if not success and WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
        local s = WidgetLayoutLibrary.GetViewportScale(PC) or 1.0
        BoxESP._CanvasScaleX = 1.0 / s; BoxESP._CanvasScaleY = 1.0 / s
        BoxESP._CanvasOffsetX = 0; BoxESP._CanvasOffsetY = 0
    end
end

function BoxESP.ProjectWorldToCanvasLocal(PC, WorldLoc)
    if not IsValidX(PC) or not WorldLoc or not TempProjVec2D then return false, 0, 0 end
    local res = PC:ProjectWorldLocationToScreen(WorldLoc, TempProjVec2D, true)
    if (res == true or res == 1) and (TempProjVec2D.X ~= 0 or TempProjVec2D.Y ~= 0) then
        return true, TempProjVec2D.X * BoxESP._CanvasScaleX + BoxESP._CanvasOffsetX, TempProjVec2D.Y * BoxESP._CanvasScaleY + BoxESP._CanvasOffsetY
    end
    return false, 0, 0
end

function BoxESP.GetSnapLineStartPos(PC)
    local w, h, scale = 0, 0, 1.0
    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D(0, 0); PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then w = vs.X h = vs.Y end
        end
    end)
    if w <= 200 then
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
                local vs = WidgetLayoutLibrary.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then w = vs.X h = vs.Y end
            end
        end)
    end
    pcall(function()
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
            local s = WidgetLayoutLibrary.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then scale = s end
        end
    end)
    if w <= 200 then w = 1920 * scale h = 1080 * scale end
    local cx_px = w / 2.0
    local cy_px = BoxESP.SnapLineOriginY * scale
    return cx_px * BoxESP._CanvasScaleX + BoxESP._CanvasOffsetX, cy_px * BoxESP._CanvasScaleY + BoxESP._CanvasOffsetY
end

function BoxESP.CreateESPWidget(ParentCanvas)
    if not FLinearColor or not FVector2D then return nil end
    local CornerContainer = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas)
    if not IsValidX(CornerContainer) then return nil end
    local CornerMainSlot = ParentCanvas:AddChildToCanvas(CornerContainer)
    if not CornerMainSlot then return nil end
    CornerMainSlot:SetAutoSize(false); CornerMainSlot:SetZOrder(995); CornerMainSlot:SetAlignment(FVector2D(0.5, 0.5))

    local whiteC = FLinearColor(1, 1, 1, 1)
    local function mkLine()
        local b = CGame:NewObjectFromPath("/Script/UMG.Border", CornerContainer)
        if b and IsValidX(b) then
            b:SetBrushColor(whiteC)
            b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local s = CornerContainer:AddChildToCanvas(b); if s then s:SetAutoSize(false) end
            return { widget = b, slot = s }
        end
        return nil
    end
    local C = { TLH=mkLine(), TLV=mkLine(), TRH=mkLine(), TRV=mkLine(), BLH=mkLine(), BLV=mkLine(), BRH=mkLine(), BRV=mkLine() }

    local BgImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    if not IsValidX(BgImage) then return nil end
    BgImage:SetColorAndOpacity(FLinearColor(0, 0, 0, 0.85))
    BgImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    local BgSlot = ParentCanvas:AddChildToCanvas(BgImage)
    if not BgSlot then return nil end
    BgSlot:SetAutoSize(false); BgSlot:SetZOrder(998); BgSlot:SetAlignment(FVector2D(0.5, 1.0))

    local HealthImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
    if not IsValidX(HealthImage) then return nil end
    HealthImage:SetColorAndOpacity(FLinearColor(0, 1, 0, 1))
    HealthImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    local HealthSlot = ParentCanvas:AddChildToCanvas(HealthImage)
    if not HealthSlot then return nil end
    HealthSlot:SetAutoSize(false); HealthSlot:SetZOrder(999); HealthSlot:SetAlignment(FVector2D(0.5, 1.0))

    local function mkText(color, size, align)
        local t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas)
        local s = nil
        if t and IsValidX(t) then
            t:SetText("")
            if t.Font then
                local f = t.Font; f.Size = math.floor(size or 10)
                if f.OutlineSettings then f.OutlineSettings.OutlineSize = 1; f.OutlineSettings.OutlineColor = FLinearColor(0, 0, 0, 1) end
                if t.SetFont then t:SetFont(f) else t.Font = f end
            end
            if t.SetFontSize then t:SetFontSize(math.floor(size or 10)) end
            t:SetJustification(1)
            if t.SetHorizontalAlignment then t:SetHorizontalAlignment(1) end
            if t.SetAutoWrapText then t:SetAutoWrapText(false) end
            if FSlateColor then t:SetColorAndOpacity(FSlateColor(color)) else t:SetColorAndOpacity(color) end
            t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            s = ParentCanvas:AddChildToCanvas(t)
            if s then s:SetAutoSize(true); s:SetZOrder(1000); s:SetAlignment(align or FVector2D(0.5, 0.0)) end
        end
        return t, s
    end

    local NameW, NameS = mkText(ColorBlue, 10, FVector2D(0.5, 0.0))
    local DistW, DistS = mkText(ColorWhite, 10, FVector2D(0.5, 0.0))
    local WeaponW, WeaponS = mkText(ColorYellow, 10, FVector2D(0.5, 1.0))

    return {
        CornerContainer = CornerContainer, CornerSlot = CornerMainSlot, Corners = C,
        BgWidget = BgImage, BgSlot = BgSlot, HealthWidget = HealthImage, HealthSlot = HealthSlot,
        NameWidget = NameW, NameSlot = NameS, DistWidget = DistW, DistSlot = DistS,
        WeaponWidget = WeaponW, WeaponSlot = WeaponS,
        _cachedName = "", _cachedDist = "", _cachedWeapon = "",
        _cachedColorMode = -1, _cachedWeaponColorMode = -1, _cachedTextColorMode = -1,
        lastW = 0, lastH = 0, bVisible = true,
    }
end

function BoxESP.UpdateCornerDimensions(boxData, width, height)
    if math.abs(width - (boxData.lastW or 0)) < 1.5 and math.abs(height - (boxData.lastH or 0)) < 1.5 then return end
    boxData.lastW = width; boxData.lastH = height
    local t = BoxESP.CornerThickness
    local cLen = math.max(7, math.min(width, height) * BoxESP.CornerLengthRatio)
    local C = boxData.Corners
    boxData.CornerSlot:SetSize(FVector2D(width, height))
    if C.TLH and C.TLH.slot then C.TLH.slot:SetPosition(FVector2D(0, 0)); C.TLH.slot:SetSize(FVector2D(cLen, t)) end
    if C.TLV and C.TLV.slot then C.TLV.slot:SetPosition(FVector2D(0, 0)); C.TLV.slot:SetSize(FVector2D(t, cLen)) end
    if C.TRH and C.TRH.slot then C.TRH.slot:SetPosition(FVector2D(width - cLen, 0)); C.TRH.slot:SetSize(FVector2D(cLen, t)) end
    if C.TRV and C.TRV.slot then C.TRV.slot:SetPosition(FVector2D(width - t, 0)); C.TRV.slot:SetSize(FVector2D(t, cLen)) end
    if C.BLH and C.BLH.slot then C.BLH.slot:SetPosition(FVector2D(0, height - t)); C.BLH.slot:SetSize(FVector2D(cLen, t)) end
    if C.BLV and C.BLV.slot then C.BLV.slot:SetPosition(FVector2D(0, height - cLen)); C.BLV.slot:SetSize(FVector2D(t, cLen)) end
    if C.BRH and C.BRH.slot then C.BRH.slot:SetPosition(FVector2D(width - cLen, height - t)); C.BRH.slot:SetSize(FVector2D(cLen, t)) end
    if C.BRV and C.BRV.slot then C.BRV.slot:SetPosition(FVector2D(width - t, height - cLen)); C.BRV.slot:SetSize(FVector2D(t, cLen)) end
end

function BoxESP.SetBoxColor(boxData, color)
    local c = color
    local C = boxData.Corners
    for _, part in ipairs({C.TLH, C.TLV, C.TRH, C.TRV, C.BLH, C.BLV, C.BRH, C.BRV}) do
        if part and part.widget and IsValidX(part.widget) then
            pcall(function() part.widget:SetBrushColor(c) end)
        end
    end
end

-- Snap line
function BoxESP.CreateSnapLine(ParentCanvas)
    if not IsValidX(ParentCanvas) then return nil end
    local b = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
    if not IsValidX(b) then return nil end
    b:SetBrushColor(ColorWhite)
    b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    b:SetRenderTransformPivot(FVector2D(0.0, 0.5))
    local s = ParentCanvas:AddChildToCanvas(b)
    if s then s:SetAutoSize(false); s:SetZOrder(990) end
    return { Widget = b, Slot = s, bVisible = true, _cachedColor = nil }
end

function BoxESP.UpdateSnapLine(KeyStr, toX, toY, fromX, fromY, ParentCanvas)
    if not _G.LexusConfig.Esp9_Line then
        local l = BoxESP.LineWidgets[KeyStr]
        if l and l.Widget and IsValidX(l.Widget) and l.bVisible then
            l.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed); l.bVisible = false
        end
        return
    end
    local lineData = BoxESP.LineWidgets[KeyStr]
    if not lineData or not IsValidX(lineData.Widget) then
        lineData = BoxESP.CreateSnapLine(ParentCanvas)
        if not lineData or not lineData.Widget or not lineData.Slot then return end
        BoxESP.LineWidgets[KeyStr] = lineData
    end
    if not lineData.bVisible then
        lineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible); lineData.bVisible = true
    end
    -- Update color
    local colorMode = _G.LexusConfig.LineColorMode or 1
    if lineData._cachedColor ~= colorMode then
        local c = GetColorFromMode(colorMode)
        pcall(function() lineData.Widget:SetBrushColor(c) end)
        lineData._cachedColor = colorMode
    end
    local dx = toX - fromX; local dy = toY - fromY
    local len = math.sqrt(dx * dx + dy * dy)
    local angle = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * (180.0 / math.pi)
    local t = BoxESP.SnapLineThickness or 1.2
    if not lineData._CachedPosVec then
        lineData._CachedPosVec = FVector2D(fromX, fromY - t * 0.5)
        lineData._CachedSizeVec = FVector2D(len, t)
    else
        lineData._CachedPosVec.X = fromX; lineData._CachedPosVec.Y = fromY - t * 0.5
        lineData._CachedSizeVec.X = len; lineData._CachedSizeVec.Y = t
    end
    pcall(function()
        lineData.Slot:SetPosition(lineData._CachedPosVec); lineData.Slot:SetSize(lineData._CachedSizeVec)
        lineData.Widget:SetRenderAngle(angle)
    end)
end

-- Skeleton
local SKEL_CHAINS = {
    {"head","neck_01"},{"neck_01","spine_03"},{"spine_03","pelvis"},
    {"pelvis","thigh_l"},{"pelvis","thigh_r"},
    {"thigh_l","calf_l"},{"thigh_r","calf_r"},
    {"calf_l","foot_l"},{"calf_r","foot_r"},
    {"neck_01","upperarm_l"},{"neck_01","upperarm_r"},
    {"upperarm_l","lowerarm_l"},{"upperarm_r","lowerarm_r"},
    {"lowerarm_l","hand_l"},{"lowerarm_r","hand_r"},
}
local BONE_FB = {
    head={"head","Head"}, neck_01={"neck_01","Neck_01","neck"}, spine_03={"spine_03","Spine_03","spine_02"},
    pelvis={"pelvis","Pelvis","hip"}, upperarm_l={"upperarm_l","UpperArm_L"}, upperarm_r={"upperarm_r","UpperArm_R"},
    lowerarm_l={"lowerarm_l","LowerArm_L"}, lowerarm_r={"lowerarm_r","LowerArm_R"},
    hand_l={"hand_l","Hand_L"}, hand_r={"hand_r","Hand_R"},
    thigh_l={"thigh_l","Thigh_L"}, thigh_r={"thigh_r","Thigh_R"},
    calf_l={"calf_l","Calf_L"}, calf_r={"calf_r","Calf_R"},
    foot_l={"foot_l","Foot_L"}, foot_r={"foot_r","Foot_R"},
}
local function GetBoneLoc(char, name)
    local mesh = nil
    pcall(function() mesh = char.Mesh end)
    if not IsValidX(mesh) then return nil end
    for _, b in ipairs(BONE_FB[name] or {name}) do
        local loc = nil
        pcall(function() if mesh.GetSocketLocation then loc = mesh:GetSocketLocation(b) end end)
        if loc then return loc end
    end
    return nil
end

function BoxESP.UpdateSkeleton(key, char, onScreen, pc, ParentCanvas, color)
    if not _G.LexusConfig.Esp9_Skeleton then
        BoxESP.RemoveSkeleton(key); return
    end
    if not IsValidX(ParentCanvas) then return end
    local sk = BoxESP.SkeletonWidgets[key]
    if not onScreen or not char then
        if sk then for _, it in ipairs(sk) do
            if it and it.Widget and IsValidX(it.Widget) then
                pcall(function() it.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end end
        return
    end
    if not sk then sk = {}; BoxESP.SkeletonWidgets[key] = sk end
    local th = 1.2
    for i, chain in ipairs(SKEL_CHAINS) do
        local a3 = GetBoneLoc(char, chain[1]); local b3 = GetBoneLoc(char, chain[2])
        local it = sk[i]
        if not it then
            local b = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
            if b and IsValidX(b) then
                b:SetBrushColor(color or ColorWhite)
                b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                b:SetRenderTransformPivot(FVector2D(0.0, 0.5))
                local s = ParentCanvas:AddChildToCanvas(b)
                if s then s:SetAutoSize(false); s:SetZOrder(450) end
                it = { Widget = b, Slot = s, _p = FVector2D(0, 0), _s = FVector2D(0, 0), _color = color }
                sk[i] = it
            end
        end
        if it and it.Widget and it.Slot then
            local aOn, aX, aY = false, 0, 0; local bOn, bX, bY = false, 0, 0
            if a3 then aOn, aX, aY = BoxESP.ProjectWorldToCanvasLocal(pc, a3) end
            if b3 then bOn, bX, bY = BoxESP.ProjectWorldToCanvasLocal(pc, b3) end
            if aOn and bOn then
                local dx = bX - aX; local dy = bY - aY
                local len = math.sqrt(dx * dx + dy * dy)
                local ang = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * 57.29577951308232
                it._p.X = aX; it._p.Y = aY - th / 2.0; it._s.X = len; it._s.Y = th
                pcall(function()
                    it.Slot:SetPosition(it._p); it.Slot:SetSize(it._s)
                    it.Widget:SetRenderAngle(ang)
                    it.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end)
            else
                pcall(function() it.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end
    end
end

function BoxESP.RemoveSkeleton(key)
    local sk = BoxESP.SkeletonWidgets[key]
    if sk then
        for _, it in ipairs(sk) do
            if it and it.Widget and IsValidX(it.Widget) then
                pcall(function() it.Widget:RemoveFromParent() it.Widget:ConditionalBeginDestroy() end)
            end
        end
        BoxESP.SkeletonWidgets[key] = nil
    end
end

function BoxESP.HideWidget(boxData)
    if not boxData or not boxData.bVisible then return end
    boxData.bVisible = false
    local c = UEnums.ESlateVisibility.Collapsed
    if boxData.CornerContainer then boxData.CornerContainer:SetWidgetVisibility(c) end
    if boxData.BgWidget then boxData.BgWidget:SetWidgetVisibility(c) end
    if boxData.HealthWidget then boxData.HealthWidget:SetWidgetVisibility(c) end
    if boxData.WeaponWidget then boxData.WeaponWidget:SetWidgetVisibility(c) end
    if boxData.NameWidget then boxData.NameWidget:SetWidgetVisibility(c) end
    if boxData.DistWidget then boxData.DistWidget:SetWidgetVisibility(c) end
end

function BoxESP.ShowWidget(boxData)
    if not boxData or boxData.bVisible then return end
    boxData.bVisible = true
    local v = UEnums.ESlateVisibility.SelfHitTestInvisible
    if boxData.CornerContainer then boxData.CornerContainer:SetWidgetVisibility(v) end
    if boxData.BgWidget then boxData.BgWidget:SetWidgetVisibility(v) end
    if boxData.HealthWidget then boxData.HealthWidget:SetWidgetVisibility(v) end
    if boxData.WeaponWidget then boxData.WeaponWidget:SetWidgetVisibility(v) end
    if boxData.NameWidget then boxData.NameWidget:SetWidgetVisibility(v) end
    if boxData.DistWidget then boxData.DistWidget:SetWidgetVisibility(v) end
end

function BoxESP.UpdateEnemyCounter(realCount, botCount, ParentCanvas, cx)
    local CD = BoxESP.CounterData
    if not CD.bCreated then
        pcall(function()
            local FLC = import("LinearColor")
            local redC = FLC and FLC(0.85, 0.15, 0.15, 0.95) or {R=0.85, G=0.15, B=0.15, A=0.95}
            local greenC = FLC and FLC(0.15, 0.85, 0.15, 0.95) or {R=0.15, G=0.85, B=0.15, A=0.95}
            local whiteC = FLC and FLC(1, 1, 1, 1) or {R=1, G=1, B=1, A=1}

            -- REAL box (Red)
            local realBg = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
            if realBg and IsValidX(realBg) then
                realBg:SetBrushColor(redC)
                realBg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                local s1 = ParentCanvas:AddChildToCanvas(realBg)
                if s1 then s1:SetAutoSize(false); s1:SetSize(FVector2D(105, 32)); s1:SetZOrder(1005); s1:SetAlignment(FVector2D(0, 0)) end
                CD.RealBg = realBg; CD.RealSlot = s1
            end
            local realTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas)
            if realTxt and IsValidX(realTxt) then
                realTxt:SetText("REAL 0")
                if realTxt.Font then
                    local f = realTxt.Font; f.Size = 19
                    if f.OutlineSettings then f.OutlineSettings.OutlineSize = 0; f.OutlineSettings.OutlineColor = FLinearColor(0, 0, 0, 0) end
                    if realTxt.SetFont then realTxt:SetFont(f) else realTxt.Font = f end
                end
                if realTxt.SetFontSize then realTxt:SetFontSize(19) end
                if FSlateColor then realTxt:SetColorAndOpacity(FSlateColor(whiteC)) else realTxt:SetColorAndOpacity(whiteC) end
                realTxt:SetJustification(1)
                if realTxt.SetHorizontalAlignment then realTxt:SetHorizontalAlignment(1) end
                if realTxt.SetVerticalAlignment then realTxt:SetVerticalAlignment(1) end
                realTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                local s2 = ParentCanvas:AddChildToCanvas(realTxt)
                if s2 then s2:SetAutoSize(true); s2:SetZOrder(1010); s2:SetAlignment(FVector2D(0.5, 0.5)) end
                CD.RealTxt = realTxt; CD.RealTxtSlot = s2
            end

            -- BOT box (Green)
            local botBg = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
            if botBg and IsValidX(botBg) then
                botBg:SetBrushColor(greenC)
                botBg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                local s3 = ParentCanvas:AddChildToCanvas(botBg)
                if s3 then s3:SetAutoSize(false); s3:SetSize(FVector2D(105, 32)); s3:SetZOrder(1005); s3:SetAlignment(FVector2D(0, 0)) end
                CD.BotBg = botBg; CD.BotSlot = s3
            end
            local botTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas)
            if botTxt and IsValidX(botTxt) then
                botTxt:SetText("BOT 0")
                if botTxt.Font then
                    local f = botTxt.Font; f.Size = 19
                    if f.OutlineSettings then f.OutlineSettings.OutlineSize = 0; f.OutlineSettings.OutlineColor = FLinearColor(0, 0, 0, 0) end
                    if botTxt.SetFont then botTxt:SetFont(f) else botTxt.Font = f end
                end
                if botTxt.SetFontSize then botTxt:SetFontSize(19) end
                if FSlateColor then botTxt:SetColorAndOpacity(FSlateColor(whiteC)) else botTxt:SetColorAndOpacity(whiteC) end
                botTxt:SetJustification(1)
                if botTxt.SetHorizontalAlignment then botTxt:SetHorizontalAlignment(1) end
                if botTxt.SetVerticalAlignment then botTxt:SetVerticalAlignment(1) end
                botTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                local s4 = ParentCanvas:AddChildToCanvas(botTxt)
                if s4 then s4:SetAutoSize(true); s4:SetZOrder(1010); s4:SetAlignment(FVector2D(0.5, 0.5)) end
                CD.BotTxt = botTxt; CD.BotTxtSlot = s4
            end

            CD.bCreated = true
        end)
    end

    if not _G.LexusConfig.Esp9_Count then
        if CD.RealBg then CD.RealBg:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        if CD.RealTxt then CD.RealTxt:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        if CD.BotBg then CD.BotBg:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        if CD.BotTxt then CD.BotTxt:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        return
    end

    -- Layout: top-center pe, 65px from top
    local topY = 65
    local boxW = 105
    local boxH = 32
    local gap = 3

    if CD.RealSlot then CD.RealSlot:SetPosition(FVector2D(cx - boxW - gap, topY)); CD.RealSlot:SetSize(FVector2D(boxW, boxH)) end
    if CD.RealTxtSlot then CD.RealTxtSlot:SetPosition(FVector2D(cx - (boxW * 0.5) - gap, topY + (boxH * 0.5))) end
    if CD.BotSlot then CD.BotSlot:SetPosition(FVector2D(cx + gap, topY)); CD.BotSlot:SetSize(FVector2D(boxW, boxH)) end
    if CD.BotTxtSlot then CD.BotTxtSlot:SetPosition(FVector2D(cx + (boxW * 0.5) + gap, topY + (boxH * 0.5))) end

    if CD.LastPlayerCount ~= realCount and CD.RealTxt then
        CD.RealTxt:SetText("REAL " .. realCount); CD.LastPlayerCount = realCount
    end
    if CD.LastBotCount ~= botCount and CD.BotTxt then
        CD.BotTxt:SetText("BOT " .. botCount); CD.LastBotCount = botCount
    end

    local v = UEnums.ESlateVisibility.SelfHitTestInvisible
    if CD.RealBg then CD.RealBg:SetWidgetVisibility(v) end
    if CD.RealTxt then CD.RealTxt:SetWidgetVisibility(v) end
    if CD.BotBg then CD.BotBg:SetWidgetVisibility(v) end
    if CD.BotTxt then CD.BotTxt:SetWidgetVisibility(v) end
end

function BoxESP.UpdateESP()
    if not BoxESP.bActive or not _G.LexusConfig.EspLoai9 then
        for k, d in pairs(BoxESP.BoxWidgets) do BoxESP.HideWidget(d) end
        for k, l in pairs(BoxESP.LineWidgets) do
            if l and l.Widget and IsValidX(l.Widget) and l.bVisible then
                l.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed); l.bVisible = false
            end
        end
        for k, _ in pairs(BoxESP.SkeletonWidgets) do BoxESP.RemoveSkeleton(k) end
        if BoxESP.CounterData.Text then BoxESP.CounterData.Text:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        return
    end

    local ParentCanvas = BoxESP.GetMainCanvas()
    if not ParentCanvas then return end
    local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or _G.GameplayData
    if not GD then return end
    local LocalPlayer = GD.GetPlayerCharacter and GD.GetPlayerCharacter()
    if not IsValidX(LocalPlayer) then return end
    local PC = GD.GetPlayerController and GD.GetPlayerController()
    if not IsValidX(PC) then return end

    local curTime = os.clock and os.clock() or 0
    if BoxESP._LastCanvas ~= ParentCanvas or (curTime - BoxESP._LastTransformTime > 1.0) then
        BoxESP.UpdateCanvasTransform(PC); BoxESP._LastCanvas = ParentCanvas; BoxESP._LastTransformTime = curTime
    end
    local bHeavy = (curTime - BoxESP._LastHeavyUpdateTime > 0.15)
    if bHeavy then BoxESP._LastHeavyUpdateTime = curTime end

    local fromX, fromY = BoxESP.GetSnapLineStartPos(PC)

    local TeamID = LocalPlayer.TeamID or (LocalPlayer.GetTeamID and LocalPlayer:GetTeamID()) or 0
    local AllPawns = (Game and Game.GetAllPlayerPawns and Game:GetAllPlayerPawns()) or {}
    local SeenKeys = {}
    local realCount, botCount = 0, 0

    for Key, Pawn in pairs(AllPawns) do
        if IsValidX(Pawn) and Pawn ~= LocalPlayer then
            local pTeam = Pawn.TeamID or (Pawn.GetTeamID and Pawn:GetTeamID()) or -1
            local isAlive = (Pawn.Health and Pawn.Health > 0) or (Pawn.IsAlive and Pawn:IsAlive())
            if isAlive and pTeam ~= TeamID then
                local KeyStr = tostring(Key)
                SeenKeys[KeyStr] = true

                local ping = (Pawn.PlayerState and Pawn.PlayerState.Ping) or Pawn.Ping or -1
                ping = tonumber(ping) or -1
                local isBot = (ping >= 0 and ping <= 3) or Pawn.bIsAI or Pawn.bIsAIBot or Pawn.bIsABot or (Game and Game.IsAI and Game:IsAI(Pawn))
                if isBot then botCount = botCount + 1 else realCount = realCount + 1 end

                -- CHOOSE COLOR based on player/bot
                local colorMode = isBot and (_G.LexusConfig.BoxColorBot or 3) or (_G.LexusConfig.BoxColorPlayer or 1)
                local boxColor = GetColorFromMode(colorMode)

                local Loc = Pawn.K2_GetActorLocation and Pawn:K2_GetActorLocation()
                if not Loc and Pawn.RootComponent then Loc = Pawn.RootComponent:K2_GetComponentLocation() end
                if Loc then
                    local topW, botW = nil, nil
                    local mesh = Pawn.Mesh or (Pawn.GetMesh and Pawn:GetMesh()) or Pawn.CharacterMesh0
                    if mesh and mesh.GetSocketLocation then
                        local hL = mesh:GetSocketLocation("Head") or mesh:GetSocketLocation("head")
                        if hL and (hL.X ~= 0 or hL.Y ~= 0 or hL.Z ~= 0) then topW = FVector(hL.X, hL.Y, hL.Z + 15) end
                        local rL = mesh:GetSocketLocation("root") or mesh:GetSocketLocation("Root")
                        if rL and (rL.X ~= 0 or rL.Y ~= 0 or rL.Z ~= 0) then botW = rL end
                    end
                    local isProne = Pawn.bIsProning or Pawn.bIsProne or (Pawn.IsProne and Pawn:IsProne()) or Pawn.PoseState == 2 or Pawn.PoseState == "Prone"
                    local isCrouch = Pawn.bIsCrouched or (Pawn.IsCrouched and Pawn:IsCrouched()) or Pawn.PoseState == 1 or Pawn.PoseState == "Crouch"
                    if not topW or not botW then
                        local tOff = isProne and 18 or (isCrouch and 50 or 88)
                        local bOff = isProne and -22 or (isCrouch and -68 or -90)
                        topW = topW or FVector(Loc.X, Loc.Y, Loc.Z + tOff)
                        botW = botW or FVector(Loc.X, Loc.Y, Loc.Z + bOff)
                    end
                    local bTopOk, topX, topY = BoxESP.ProjectWorldToCanvasLocal(PC, topW)
                    local bBotOk, botX, botY = BoxESP.ProjectWorldToCanvasLocal(PC, botW)

                    local boxData = BoxESP.BoxWidgets[KeyStr]
                    if not boxData then
                        boxData = BoxESP.CreateESPWidget(ParentCanvas)
                        if boxData then BoxESP.BoxWidgets[KeyStr] = boxData end
                    end

                    if boxData and IsValidX(boxData.CornerContainer) then
                        if bTopOk and bBotOk then
                            local bH = math.max(28, math.abs(botY - topY))
                            local bW = math.max(15, bH * (isProne and 1.1 or (isCrouch and 0.7 or 0.55)))
                            local cX = (topX + botX) * 0.5
                            local cY = (topY + botY) * 0.5
                            local boxTopY = cY - (bH * 0.5)
                            local boxBotY = cY + (bH * 0.5)

                            if _G.LexusConfig.Esp9_Box then
                                BoxESP.UpdateCornerDimensions(boxData, bW, bH)
                                BoxESP.SetBoxColor(boxData, boxColor)
                                boxData.CornerSlot:SetPosition(FVector2D(cX, cY))
                                pcall(function() boxData.CornerContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                            else
                                pcall(function() boxData.CornerContainer:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            end
                            BoxESP.ShowWidget(boxData)

                            -- HP Bar
                            if _G.LexusConfig.Esp9_HP then
                                local hbw = BoxESP.HealthBarWidth or 3.0
                                local hcx = cX - (bW * 0.5) - 2.5 - (hbw * 0.5)
                                local hp = Pawn.Health or (Pawn.GetHealth and Pawn:GetHealth()) or 100
                                local hpMax = Pawn.HealthMax or (Pawn.GetHealthMax and Pawn:GetHealthMax()) or 100
                                if hpMax <= 0 then hpMax = 100 end
                                local pct = math.max(0, math.min(1, hp / hpMax))
                                local hh = bH * pct
                                boxData.BgSlot:SetSize(FVector2D(hbw, bH)); boxData.BgSlot:SetPosition(FVector2D(hcx, boxBotY))
                                boxData.HealthSlot:SetSize(FVector2D(hbw, hh)); boxData.HealthSlot:SetPosition(FVector2D(hcx, boxBotY))
                                -- Health bar color = same as box color
                                pcall(function()
                                    if boxData.HealthWidget then boxData.HealthWidget:SetColorAndOpacity(boxColor) end
                                    if boxData.BgWidget then boxData.BgWidget:SetColorAndOpacity(FLinearColor(0, 0, 0, 0.85)) end
                                end)
                                pcall(function()
                                    boxData.BgWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                    boxData.HealthWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                end)
                            else
                                pcall(function()
                                    boxData.BgWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                                    boxData.HealthWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                                end)
                            end

                            -- Weapon
                            if _G.LexusConfig.Esp9_Name and bHeavy then
                                local wep = (Pawn.GetCurrentWeapon and Pawn:GetCurrentWeapon()) or (Pawn.WeaponManagerComponent and Pawn.WeaponManagerComponent.CurrentWeaponReplicated)
                                local wn = isBot and "Fist" or "Fist"
                                if wep and IsValidX(wep) then
                                    local n = (type(wep.GetWeaponName) == "function" and wep:GetWeaponName()) or wep.WeaponName
                                    if n and n ~= "" then wn = tostring(n):gsub("^BP_", ""):gsub("_C$", "") end
                                end
                                if boxData._cachedWeapon ~= wn then boxData.WeaponWidget:SetText(wn); boxData._cachedWeapon = wn end
                            end
                            if _G.LexusConfig.Esp9_Name then
                                boxData.WeaponSlot:SetPosition(FVector2D(cX, boxTopY - 3.5))
                                pcall(function() boxData.WeaponWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                            else
                                pcall(function() boxData.WeaponWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            end

                            -- Name (with player/bot color match)
                            if _G.LexusConfig.Esp9_Name and bHeavy then
                                local pn = isBot and "BOT" or "PLAYER"
                                if not isBot then
                                    pcall(function() if Pawn.PlayerName then pn = tostring(Pawn.PlayerName) end end)
                                end
                                if boxData._cachedName ~= pn then
                                    boxData.NameWidget:SetText(pn)
                                    boxData._cachedName = pn
                                end
                                -- Name color = box color
                                if boxData._cachedTextColorMode ~= colorMode then
                                    if FSlateColor then boxData.NameWidget:SetColorAndOpacity(FSlateColor(boxColor)) else boxData.NameWidget:SetColorAndOpacity(boxColor) end
                                    boxData._cachedTextColorMode = colorMode
                                end
                            end
                            if _G.LexusConfig.Esp9_Name then
                                boxData.NameSlot:SetPosition(FVector2D(cX, boxBotY + 4.0))
                                pcall(function() boxData.NameWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                            else
                                pcall(function() boxData.NameWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            end

                            -- Distance
                            if _G.LexusConfig.Esp9_Distance then
                                local dv = math.floor(LocalPlayer:GetDistanceTo(Pawn) / 100.0)
                                local ds = tostring(dv) .. "m"
                                if boxData._cachedDist ~= ds then boxData.DistWidget:SetText(ds); boxData._cachedDist = ds end
                                boxData.DistSlot:SetPosition(FVector2D(cX, boxBotY + 20.5))
                                pcall(function() boxData.DistWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                            else
                                pcall(function() boxData.DistWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            end

                            -- Line
                            if _G.LexusConfig.Esp9_Line then
                                BoxESP.UpdateSnapLine(KeyStr, cX, boxTopY, fromX, fromY, ParentCanvas)
                            else
                                local l = BoxESP.LineWidgets[KeyStr]
                                if l and l.Widget and IsValidX(l.Widget) and l.bVisible then
                                    l.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed); l.bVisible = false
                                end
                            end

                            -- Skeleton
                            BoxESP.UpdateSkeleton(KeyStr, Pawn, true, PC, ParentCanvas, boxColor)
                        else
                            BoxESP.HideWidget(boxData)
                            BoxESP.RemoveSkeleton(KeyStr)
                        end
                    end
                end
            end
        end
    end

    for KeyStr, boxData in pairs(BoxESP.BoxWidgets) do
        if not SeenKeys[KeyStr] then BoxESP.HideWidget(boxData); BoxESP.RemoveSkeleton(KeyStr) end
    end
    for KeyStr, l in pairs(BoxESP.LineWidgets) do
        if not SeenKeys[KeyStr] and l and l.Widget and IsValidX(l.Widget) and l.bVisible then
            l.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed); l.bVisible = false
        end
    end

    BoxESP.UpdateEnemyCounter(realCount, botCount, ParentCanvas, fromX)
end

_G.BoxESP = BoxESP

-- ==================== iPAD VIEW ====================
local function ApplyIpadView()
    pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or _G.GameplayData
        if not GD then return end
        local me = GD.GetPlayerCharacter and GD.GetPlayerCharacter()
        if not Valid(me) then return end
        local cam = me.ThirdPersonCameraComponent
        if not Valid(cam) then return end
        local targetFOV = 90
        if _G.LexusConfig.IpadView then
            targetFOV = _G.LexusState.CustomTextData.IpadFOV or 120
        end
        if cam.FieldOfView ~= targetFOV then cam.FieldOfView = targetFOV end
    end)
end

-- ==================== LOOP ====================
local function FastTick()
    pcall(BoxESP.UpdateESP)
    pcall(ApplyIpadView)
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(0.02, FastTick) end
end

-- ==================== PREMIUM WELCOME + LOGO ====================
function _G.ShowLexusVIPMenu()
    if _G.LexusMenuShown then return end
    _G.LexusMenuShown = true
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end
        -- Premium ASCII logo content
        local content = [[
╔═══════════════════════════════╗
║   ⚡ TESLA 10X GAMING ⚡       ║
║         VIP MOD v4.6          ║
║      ━━━━━━━━━━━━━━━━         ║
║   ✓ ESP + Box + Skeleton      ║
║   ✓ Headshot / BigHead        ║
║   ✓ iPad View + Colors        ║
║   ✓ Strong Bypass (MD5/Skin)  ║
║   ━━━━━━━━━━━━━━━━            ║
║   Dev: @OfficialOwner10x      ║
╚═══════════════════════════════╝

ACTIVATION SUCCESSFUL! 

Open Settings → Privacy → ⚡ TESLA 10X VIP ⚡]]
        Msg.Show(1, "⚡ TESLA 10X GAMING ⚡ VIP 4.6",
            content,
            function()
                Notify("VIP Menu added! Settings → Privacy tab.")
            end,
            function() end, "OK", "")
    end)
    -- Also send as on-screen notify
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage("⚡ TESLA 10X GAMING ⚡ VIP 4.6 | @OfficialOwner10x", -1, 8.0,
                {R=1, G=0.85, B=0, A=1}, {X=1.2, Y=1.5})
        end
    end)
end

-- ==================== START ====================
InitModMenuTab()
_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1

pcall(function()
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then
        t.AddTimerOnce(1.0, FastTick)
        t.AddTimerOnce(3.0, function() pcall(ShowLexusVIPMenu) end)
    else
        if Game and Game.AddGameTimer then
            Game:AddGameTimer(0.02, true, FastTick)
            Game:AddGameTimer(3.0, false, ShowLexusVIPMenu)
        end
    end
end)

Notify("⚡ TESLA 10X VIP 4.6 loaded ⚡")

-- ====================================================================
-- CLASS DECLARATION
-- ====================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildSkateFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.PlayerCharacterBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.Gameplay.Feature.ParachuteFormationFeature" },
  { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
}, "BRPlayerCharacterBase")