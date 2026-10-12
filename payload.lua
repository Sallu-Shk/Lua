-- ====================================================================
-- BRPlayerCharacterBase.lua — TESLA 10X GAMING VIP 5.1 FIXED
-- @OfficialOwner10x 🔥
-- Smooth ESP (50FPS) + Enemy Box (REAL/BOT colors) + Counters
-- GPU Wallhack + Headshot + iPad View + Bypass 20-Layer
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
-- MOD LOGIC — TESLA 10X 5.1 FIXED
-- ====================================================================
local BRAND = "TESLA 10X GAMING 5.1"
local BRAND_DEV = "@OFFICIALOWNER10X"
local _slua = rawget(_G, "slua")

local function Valid(o)
    if o == nil then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, o)
        return ok and v
    end
    return true
end

local function Notify(msg)
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then Msg.Show(1, "◆ " .. BRAND .. " ◆", tostring(msg), function() end, function() end, "OK", "") return end
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
    Esp9_Skeleton = false,
    Esp9_Box = true,
    LineColorMode = 1,
    WallhackV2 = false,
    IpadView = false,
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

-- ====================================================================
-- BYPASS 20-LAYER ULTRA
-- ====================================================================
pcall(function()
    local function nop() end
    local function retFalse() return false end
    local function retTrue() return true end
    local function retZero() return 0 end
    local function retEmpty() return {} end
    local function retEmptyStr() return "" end
    local function retMD5() return "00000000000000000000000000000000" end

    local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if subMgr then
        local targets = {
            "CoronaLabSubsystem","ClientReportPlayerSubsystem","DSReportPlayerSubsystem",
            "ShootVerifySubSystemClient","BehaviorScoreSubsystem","AntiCheatSubsystem",
            "GameReportSubsystem","OperationalStatsSubsystem","SwiftHawkSubsystem",
            "PlayerSecurityInfoSubsystem","ModifierExceptionSubsystem","IntegrityCheckSubsystem",
            "FileCheckSubsystem","MemoryCheckSubsystem","SpeedCheckSubsystem","WallCheckSubsystem",
            "AvatarExceptionSubsystem","ClientDataStatistcsSubsystem","AFKReportorSubsystem",
            "ClientCircleFlowSubsystem","MrpcsFlowSubsystem","ReplaySubsystem",
            "TssSdkSubsystem","TLogSubsystem","CrashSightSubsystem","HiggsBosonSubsystem",
            "NetCheckSubsystem","CheatReportSubsystem","PunishmentSubsystem",
            "PlayerMovementVerifySubsystem","WeaponIntegritySubsystem","SkinIntegritySubsystem",
            "CharacterIntegritySubsystem","VehicleIntegritySubsystem","LobbyVerifySubsystem",
            "BootVerifySubsystem","StartupCheckSubsystem","ProcessCheckSubsystem",
            "RootDetectSubsystem","EmulatorDetectSubsystem","DebugDetectSubsystem",
            "InjectionDetectSubsystem","HookDetectSubsystem","ModuleScanSubsystem",
            "AntiTamperSubsystem","SigCheckSubsystem","AssetVerifySubsystem","PakVerifySubsystem",
            "LuaIntegritySubsystem","BytecodeVerifySubsystem","EncryptionCheckSubsystem"
        }
        for _, n in ipairs(targets) do
            local s = subMgr:Get(n)
            if s then
                for k, v in pairs(s) do
                    if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Collect") or k:find("Scan") or k:find("Detect") or k:find("Tamper") or k:find("Punish") or k:find("Ban") or k:find("Kick")) then
                        pcall(function() s[k] = nop end)
                    end
                end
                for _, tf in ipairs({"TimerHandle","timer","heartbeatTimer","reportTimer","scanTimer","checkTimer","verifyTimer","detectTimer"}) do
                    if s[tf] then pcall(function() s:RemoveGameTimer(s[tf]); s[tf] = nil end) end
                end
            end
        end
    end

    local nu = _G.NetUtil
    if nu and nu.SendPacket and not nu._BypassActive then
        local orig = nu.SendPacket
        local blk = {
            ["ReportAttackFlow"]=1,["ReportSecAttackFlow"]=1,["ReportHitFlow"]=1,
            ["ReportAimFlow"]=1,["ReportPlayerBehavior"]=1,["ReportVerifyInfoFlow"]=1,
            ["ReportFireArms"]=1,["ReportMrpcsFlow"]=1,["ReportTeammatHurt"]=1,
            ["ReportPlayerPosition"]=1,["ReportPlayerMoveRoute"]=1,
            ["on_tss_sdk_anti_data"]=1,["ClientSecMrpcsFlow"]=1,["MrpcsData"]=1,
            ["SwiftHawk"]=1,["ClientSwiftHawk"]=1,["AntiCheatReport"]=1,["CheatDetection"]=1,
            ["ViolationReport"]=1,["SecurityViolation"]=1,["IntegrityCheck"]=1,["SignatureVerify"]=1,
            ["BanPlayer"]=1,["KickPlayer"]=1,["NotifyBan"]=1,["ApplyPunishment"]=1,
            ["ReportEquipmentFlow"]=1,["ReportPlayersPing"]=1,["ReportPlayerIP"]=1,
            ["ReportPlayerFramePingRecord"]=1,["ReportDSNetSaturation"]=1,
            ["ReportNetContinuousSaturate"]=1,["ReportDSNetRate"]=1,["ReportCircleFlow"]=1,
            ["ReportVehicleMoveFlow"]=1,["ReportSecTgameMovingFlow"]=1,
            ["ReportParachuteData"]=1,["SendTssSdkAntiDataToLobby"]=1,
            ["ReportMisKillByTeammate"]=1,["ReportForbitPick"]=1,
            ["ReportSimulateCharacterLocation"]=1,["ReportAvatarID"]=1,
            ["ReportWeaponSkin"]=1,["ReportVehicleSkin"]=1,["ReportClothSkin"]=1,
            ["ReportHitRecord"]=1,["ReportShootData"]=1,["ReportDamageRecord"]=1,
            ["ReportKillRecord"]=1,["ReportWalkRecord"]=1,["ReportSpeedCheck"]=1,
            ["ReportWallCheck"]=1,["ReportMemoryCheck"]=1,["ReportFileCheck"]=1,
            ["ReportHookCheck"]=1,["ReportModuleScan"]=1,["ReportRootDetect"]=1,
            ["ReportEmulatorDetect"]=1,["ReportDebugDetect"]=1,["ReportInjection"]=1,
            ["ReportTamper"]=1,["ReportLuaIntegrity"]=1,["ReportAssetVerify"]=1,
            ["ReportPakVerify"]=1,["ReportBootVerify"]=1,["ReportStartupCheck"]=1,
            ["ReportProcessCheck"]=1,["ReportEncryptionCheck"]=1,["ReportBytecode"]=1
        }
        nu.SendPacket = function(name, ...) if blk[name] then return nil end return orig(name, ...) end
        nu._BypassActive = true
    end

    if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
    local rpts = {
        "ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow",
        "ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate",
        "ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow",
        "ReportSecTgameMovingFlow","ReportParachuteData","SendTssSdkAntiDataToLobby",
        "ReportEquipmentFlow","ReportAimFlow","ReportPlayersPing","ReportPlayerIP",
        "ReportPlayerFramePingRecord","ReportDSNetSaturation","ReportNetContinuousSaturate",
        "ReportDSNetRate","ReportCircleFlow","ClientSecMrpcsFlow","SwiftHawk",
        "ClientSwiftHawk","ClientSwiftHawkWithParams","OnShutdownAfterError",
        "OnPlayerActorChannelError","OnPlayerRPCValidateFailed","OnDSPlayerStateChanged",
        "ReportAvatarID","ReportWeaponSkin","ReportVehicleSkin","ReportClothSkin",
        "ReportHitRecord","ReportShootData","ReportDamageRecord","ReportKillRecord",
        "ReportWalkRecord","ReportSpeedCheck","ReportWallCheck","ReportMemoryCheck",
        "ReportFileCheck","ReportHookCheck","ReportModuleScan","ReportRootDetect",
        "ReportEmulatorDetect","ReportDebugDetect","ReportInjection","ReportTamper",
        "ReportLuaIntegrity","ReportAssetVerify","ReportPakVerify","ReportBootVerify",
        "ReportStartupCheck","ReportProcessCheck","ReportEncryptionCheck","ReportBytecode"
    }
    for _, f in ipairs(rpts) do _G.GameplayCallbacks[f] = nop end
    _G.GameplayCallbacks.CheckReportSecAttackFlowWithAttackFlow = retFalse
    _G.GameplayCallbacks.CheckReportSecAttackFlow = retFalse

    pcall(function()
        local t = package.loaded["TssSdk"] or _G.TssSdk
        if t then
            t.SendReportInfo = nop; t.ScanMemory = retTrue; t.IsEmulator = retFalse
            t.CheckEnvironment = retTrue; t.VerifyProcess = retTrue; t.Init = retTrue
            t.GetFileMD5 = retMD5; t.VerifyFileSignature = retTrue
            t.CheckRoot = retFalse; t.CheckDebugger = retFalse; t.CheckHook = retFalse
            t.CheckInjection = retFalse; t.CheckTamper = retFalse; t.CheckVirtual = retFalse
            t.ReportAntiData = nop; t.SendAntiData = nop; t.ScanProcess = retTrue
            t.ScanModules = retEmpty; t.ScanFiles = retEmpty; t.ScanMemoryRegions = retEmpty
        end
    end)

    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            local cmd = console.ExecuteConsoleCommand
            if cmd then
                cmd(nil, "pak.DisablePakSignatureCheck 1")
                cmd(nil, "pakchunk.EnableSignatureCheck 0")
                cmd(nil, "s.VerifyPak 0")
                cmd(nil, "sig.Check 0")
                cmd(nil, "n.VerifyPacket 0")
                cmd(nil, "net.DisableVerify 1")
                cmd(nil, "AntiCheat.Disable 1")
                cmd(nil, "TssSdk.Disable 1")
                cmd(nil, "Higgs.Disable 1")
                cmd(nil, "Corona.Disable 1")
                cmd(nil, "Security.Disable 1")
            end
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = retMD5
            CMode.MD5HashFile = retMD5
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = retMD5 end
        if _G.MD5 then _G.MD5 = retMD5 end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = retMD5 end
        if _G.SHA256 then _G.SHA256 = retMD5 end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue
            FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
            FileHashChecker.ComputeHash = function() return "BYPASS" end
        end
    end)

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

    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then
            SMTD.MTDePicture = retEmptyStr
            SMTD.ReMTDePicture = retEmptyStr
            SMTD.HasCaptured = retTrue
            SMTD.TakeScreenshot = nop
            SMTD.CaptureScreen = nop
            SMTD.SaveScreenshot = retTrue
            SMTD.GetScreenshotData = retEmptyStr
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop end
        local Beacon = package.loaded["Beacon"] or _G.Beacon
        if Beacon then Beacon.Report = nop; Beacon.Send = nop end
    end)

    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({
                "ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck","StartAvatarCheck",
                "ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert",
                "ServerReportAvatar","ClientReportNetAvatar","SendHisarData","RPC_Client_ShootVertifyRes",
                "RPC_Server_ReportSimulateCharacterLocation","StartCheck","StopCheck","Reset",
                "VerifyAvatar","VerifyWeapon","VerifyPosition","VerifyDamage","VerifySpeed",
                "DetectInjection","DetectHook","DetectTamper","DetectDebug","DetectRoot","DetectEmulator",
                "ReportAllData","SendVerifyPacket","SendHeartbeat","SendChecksum"
            }) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.GetCurWeaponSkinID = retZero
            Higgs.IsMHActive = retFalse
            Higgs.bMHActive = false
            Higgs.CheckActive = retFalse
            Higgs.ShouldReport = retFalse
        end
    end)

    if _G.GameplayCallbacks then
        _G.GameplayCallbacks.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = string.lower(tostring(State or ""))
            local blocked = {
                "cheatdetected","banned","kicked","suspended","violationdetected",
                "integrityfailure","securityviolation","permanentban","temporaryban",
                "10yearban","1dayban","7dayban","30dayban","banplayer","kickplayer",
                "punish","penalty","block","deny","reject","fraud","abnormal",
                "verifyfail","checkfail","scanfail","detectfail","tamper"
            }
            for _, bs in ipairs(blocked) do
                if s:find(bs, 1, true) then return end
            end
        end
    end

    pcall(function()
        local aim = package.loaded["GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity"]
        if aim then
            aim.CheckAimbotSuspicion = retFalse
            aim.ReportAimData = nop
            aim.VerifyAimAngle = retTrue
        end
    end)

    pcall(function()
        local speed = package.loaded["GameLua.GameCore.Module.SpeedCheckModule"]
        if speed then
            for k, v in pairs(speed) do
                if type(v) == "function" and (k:find("Check") or k:find("Verify") or k:find("Report")) then
                    speed[k] = nop
                end
            end
        end
    end)

    pcall(function()
        local enc = package.loaded["common.encryption"] or _G.Encryption
        if enc then
            enc.Verify = retTrue
            enc.CheckSignature = retTrue
            enc.ValidateHash = retTrue
        end
    end)

    pcall(function()
        local lobby = package.loaded["client.logic.lobby.LobbyReporter"]
        if lobby then
            for k, v in pairs(lobby) do
                if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload")) then
                    lobby[k] = nop
                end
            end
        end
    end)

    pcall(function()
        if _G.RPCValidator then
            _G.RPCValidator.Validate = retTrue
            _G.RPCValidator.Check = retTrue
        end
    end)

    print("[" .. BRAND .. " BYPASS] 20-Layer ULTRA active")
end)

-- ==================== MENU ====================
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true
    local _FakeText = { [999000] = "◆ TESLA 10X GAMING VIP ◆", [999001] = "ESP", [999002] = "I PAD VIEW", [999003] = "COMBAT" }
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
            { Key="M_EC", UI=AM.Switcher, Text="   Enemy Counter (REAL/BOT)", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Count end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Count=v return true end },
            { Key="M_N", UI=AM.Switcher, Text="   Player Name", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Name end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Name=v return true end },
            { Key="M_D", UI=AM.Switcher, Text="   Distance", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Distance end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Distance=v return true end },
            { Key="M_H", UI=AM.Switcher, Text="   Health Bar", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_HP end, SetFunc=function(c,v) _G.LexusConfig.Esp9_HP=v return true end },
            { Key="M_B", UI=AM.Switcher, Text="   Enemy Box", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Box end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Box=v return true end },
            { Key="M_L", UI=AM.Switcher, Text="   Snap Line", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Line end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Line=v return true end },
            { Key="M_S", UI=AM.Switcher, Text="   Skeleton", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Skeleton end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Skeleton=v return true end },
            { Key="M_LC", UI=AM.Slider, Text="   Line Color (1-6)", ExpandHandle="M_ESP", MinValue=1, MaxValue=6,
              GetFunc=function() return _G.LexusConfig.LineColorMode or 1 end, SetFunc=function(c,v) _G.LexusConfig.LineColorMode = v return true end },
            { Key="M_WH", UI=AM.Switcher, Text="   Wallhack (GPU Outline)", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.WallhackV2 end, SetFunc=function(c,v) _G.LexusConfig.WallhackV2=v return true end },
        }
        local StackGraphics = {
            { Key="M_IP", UI=AM.TitleSwitcher, Text="I PAD VIEW", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.IpadView end, SetFunc=function(c,v) _G.LexusConfig.IpadView=v return true end },
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
-- NATIVE ESP — FIXED with AbsoluteToLocal + BOX + COUNTERS
-- ====================================================================
local SlateBlueprintLibrary, WidgetLayoutLibrary, FVector2D, FVector, FLinearColor, FSlateColor
pcall(function()
    SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary")
    WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary")
    FVector2D = import("Vector2D")
    FVector = import("Vector")
    FLinearColor = import("LinearColor")
    FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
end)
local KismetSystemLibrary = import("KismetSystemLibrary")

local function IsValid(o)
    if o == nil then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, o)
        return ok and v
    end
    return true
end

local PlayerMapMarker = {}
PlayerMapMarker.bActive = false
PlayerMapMarker.ESPCanvas = nil
PlayerMapMarker.ESPWidgets = {}
PlayerMapMarker.ESPWidgetPtrs = {}
PlayerMapMarker.SnapLineWidgets = {}
PlayerMapMarker.SkeletonWidgets = {}
PlayerMapMarker._OBHeadWidgetClass = nil
PlayerMapMarker._cachedViewportW = 1920; PlayerMapMarker._cachedViewportH = 1080
PlayerMapMarker.bUseSnapLines = true
PlayerMapMarker.bUseSkeleton = false
PlayerMapMarker.bUseBox = true
PlayerMapMarker.bIncludeMe = false
PlayerMapMarker.bIncludeAI = true
PlayerMapMarker.SnapLineThickness = 1.2
PlayerMapMarker.SnapLineOriginY = 50
PlayerMapMarker.SnapLineHeadOffsetY = -14
PlayerMapMarker.SkeletonThickness = 1.0
PlayerMapMarker.SkeletonChains = {
    {"neck_01","lowerarm_r","hand_r"},{"neck_01","lowerarm_l","hand_l"},
    {"head","neck_01","pelvis"},{"pelvis","calf_r","foot_r"},{"pelvis","calf_l","foot_l"}
}
PlayerMapMarker.BoneNameFallbacks = {
    ["head"]={"head","Head"},["neck_01"]={"neck_01","Neck_01","neck"},
    ["spine_03"]={"spine_03","Spine_03","spine_02"},["pelvis"]={"pelvis","Pelvis","hip"},
    ["upperarm_l"]={"upperarm_l","UpperArm_L"},["upperarm_r"]={"upperarm_r","UpperArm_R"},
    ["lowerarm_l"]={"lowerarm_l","LowerArm_L"},["lowerarm_r"]={"lowerarm_r","LowerArm_R"},
    ["hand_l"]={"hand_l","Hand_L"},["hand_r"]={"hand_r","Hand_R"},
    ["calf_l"]={"calf_l","Calf_L"},["calf_r"]={"calf_r","Calf_R"},
    ["foot_l"]={"foot_l","Foot_L"},["foot_r"]={"foot_r","Foot_R"},
}
PlayerMapMarker._StaticBoneLocCache = {}
PlayerMapMarker._CachedGameplayData = nil
PlayerMapMarker._CachedPC = nil
PlayerMapMarker._CachedCGameState = nil
PlayerMapMarker._CachedMyLoc = nil

function PlayerMapMarker.GetGameplayData()
    if PlayerMapMarker._CachedGameplayData then return PlayerMapMarker._CachedGameplayData end
    local ok, G = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and G then PlayerMapMarker._CachedGameplayData = G return G end
    return nil
end
function PlayerMapMarker.GetMyPlayerController()
    local PC = PlayerMapMarker._CachedPC
    if PC and IsValid(PC) then return PC end
    local GD = PlayerMapMarker.GetGameplayData()
    if not GD then return nil end
    pcall(function() PC = GD.GetPlayerController and GD.GetPlayerController() end)
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
        local GD = PlayerMapMarker.GetGameplayData()
        if GD and GD.GetLocalCharacter then
            local MyChar = GD.GetLocalCharacter()
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
function PlayerMapMarker.GetDistanceString(MyLoc, TargetLoc)
    if not MyLoc or not TargetLoc then return "" end
    local D = nil
    pcall(function()
        local dx = (MyLoc.X or 0) - (TargetLoc.X or 0)
        local dy = (MyLoc.Y or 0) - (TargetLoc.Y or 0)
        D = math.sqrt(dx * dx + dy * dy)
    end)
    if not D then return "" end
    local M = D / 100
    if M < 1000 then return string.format("%dm", math.floor(M)) else return string.format("%.1fkm", M / 1000) end
end
function PlayerMapMarker.GetMyLocation()
    local GD = PlayerMapMarker.GetGameplayData()
    if not GD then return nil end
    local MyChar = nil
    pcall(function() MyChar = GD.GetLocalCharacter and GD.GetLocalCharacter() end)
    if not IsValid(MyChar) then return nil end
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
    local b = false
    pcall(function() if Game and Game.IsAI then b = Game:IsAI(Character) end end)
    return b
end
function PlayerMapMarker.IsAlive(Character)
    local b = true
    pcall(function() if Character.IsAlive then b = Character:IsAlive() end end)
    return b
end
function PlayerMapMarker.GetTeamID(Character)
    if not IsValid(Character) then return nil end
    local T = nil
    pcall(function() if Character.GetTeamID then T = Character:GetTeamID() end end)
    if not T then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid(PS) and PS.GetTeamID then T = PS:GetTeamID() end
        end)
    end
    if not T then pcall(function() if Character.TeamID then T = Character.TeamID end end) end
    return T
end

function PlayerMapMarker.InitESPCanvas()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then return true end
    local InGameUITools = nil
    pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    if not InGameUITools then return false end
    local MainUI = nil
    pcall(function() MainUI = InGameUITools.GetMainControlBaseUI() end)
    if not MainUI or not Game:IsValid(MainUI) then return false end
    local Parent = nil
    pcall(function()
        if MainUI.CanvasPanel_0 and Game:IsValid(MainUI.CanvasPanel_0) then Parent = MainUI.CanvasPanel_0
        elseif MainUI.CanvasPanel_42 and Game:IsValid(MainUI.CanvasPanel_42) then Parent = MainUI.CanvasPanel_42 end
    end)
    if not Parent then return false end
    PlayerMapMarker.ESPCanvas = Parent
    return true
end

-- ==== FIX: no more manual scale — AbsoluteToLocal per projection ====
function PlayerMapMarker.UpdateCanvasTransform(PC) end

-- ==== FIX: exact device-independent projection ====
PlayerMapMarker._tempProj = FVector2D and FVector2D(0,0) or {X=0,Y=0}
function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    if not IsValid(PC) or not WorldLoc then return false, (FVector2D and FVector2D(0,0) or {X=0,Y=0}) end
    local sp = PlayerMapMarker._tempProj
    sp.X = 0; sp.Y = 0
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, sp, true)
        if res == true or res == 1 then bOK = true end
    end)
    if not bOK or (sp.X == 0 and sp.Y == 0) then return false, (FVector2D and FVector2D(0,0) or {X=0,Y=0}) end

    if SlateBlueprintLibrary and PlayerMapMarker.ESPCanvas and PlayerMapMarker.ESPCanvas.GetCachedGeometry then
        local cg = nil
        pcall(function() cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry() end)
        if cg then
            local loc = nil
            pcall(function() loc = SlateBlueprintLibrary.AbsoluteToLocal(cg, sp) end)
            if loc and loc.X then return true, loc end
        end
    end
    return true, (FVector2D and FVector2D(sp.X, sp.Y) or {X=sp.X, Y=sp.Y})
end

-- ==== FIX: snapline origin via AbsoluteToLocal ====
function PlayerMapMarker.GetSnapLineStartPos(PC)
    local w = 0
    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D(0, 0); PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then w = vs.X end
        end
    end)
    if w <= 200 then
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
                local vs = WidgetLayoutLibrary.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then w = vs.X end
            end
        end)
    end
    if w <= 200 then w = 1920 end
    local sp = FVector2D and FVector2D(w / 2.0, PlayerMapMarker.SnapLineOriginY) or {X = w / 2.0, Y = PlayerMapMarker.SnapLineOriginY}
    if SlateBlueprintLibrary and PlayerMapMarker.ESPCanvas and PlayerMapMarker.ESPCanvas.GetCachedGeometry then
        local cg = nil
        pcall(function() cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry() end)
        if cg then
            local loc = nil
            pcall(function() loc = SlateBlueprintLibrary.AbsoluteToLocal(cg, sp) end)
            if loc and loc.X then return loc.X, loc.Y end
        end
    end
    return sp.X, sp.Y
end

function PlayerMapMarker.GetESPLocation(Character)
    if not IsValid(Character) then return nil end
    local Loc = PlayerMapMarker.GetCharacterLocation(Character)
    if Loc then
        local h = 85
        pcall(function()
            if Character.bIsCrouched then h = 60 end
            if Character.IsProne and Character:IsProne() then h = 30 end
        end)
        pcall(function() Loc.Z = Loc.Z + h end)
    end
    return Loc
end

function PlayerMapMarker.CreateESPWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    if not PlayerMapMarker._OBHeadWidgetClass then
        pcall(function()
            local Path = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP"
            local uClass = slua.loadClass(Path)
            if uClass then PlayerMapMarker._OBHeadWidgetClass = uClass end
        end)
        if not PlayerMapMarker._OBHeadWidgetClass then return nil end
    end
    local Widget = nil
    pcall(function()
        local STExtraBFL = import("STExtraBlueprintFunctionLibrary")
        if not STExtraBFL or not STExtraBFL.CreateWidgetByClass then return end
        local PC = PlayerMapMarker.GetMyPlayerController()
        local OuterObj = IsValid(PC) and PC.Object or PlayerMapMarker.ESPCanvas
        Widget = STExtraBFL.CreateWidgetByClass(PlayerMapMarker._OBHeadWidgetClass, OuterObj)
    end)
    if not Widget then return nil end
    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Widget:SetRenderOpacity(1.0) end)
    local NameText = nil
    local HealthFill = nil
    pcall(function()
        NameText = Widget.TextBlock_TeamName
        if Widget.TextBlock_PlayerName and slua.isValid(Widget.TextBlock_PlayerName) then
            pcall(function() Widget.TextBlock_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        end
        if Widget.WidgetSwitcher_Type and slua.isValid(Widget.WidgetSwitcher_Type) then
            pcall(function() Widget.WidgetSwitcher_Type:SetActiveWidgetIndex(0) end)
        end
        if Widget.WidgetSwitcher_Type2 and slua.isValid(Widget.WidgetSwitcher_Type2) then
            pcall(function() Widget.WidgetSwitcher_Type2:SetActiveWidgetIndex(0) end)
        end
        local SizeBox_HP = Widget.SizeBox_HP
        if SizeBox_HP and slua.isValid(SizeBox_HP) then
            pcall(function() SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            pcall(function() SizeBox_HP:SetHeightOverride(6) end)
            pcall(function() SizeBox_HP:SetWidthOverride(100) end)
            local ExistingChild = nil
            pcall(function() if SizeBox_HP.GetContent then ExistingChild = SizeBox_HP:GetContent() end end)
            if ExistingChild and slua.isValid(ExistingChild) then
                pcall(function() ExistingChild:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                HealthFill = ExistingChild
            end
        end
    end)
    return { Container = Widget, NameText = NameText, HealthFill = HealthFill, IsGameWidget = true }
end

function PlayerMapMarker.UpdateESPText(Widget, Text)
    if not Widget then return end
    if Widget._LastESPText == Text then return end
    Widget._LastESPText = Text
    local function apply(w, txt)
        if not w or not slua.isValid(w) then return end
        if txt == "" then pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) return end
        pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        pcall(function() w:SetText(txt) end)
        pcall(function()
            local c = FLinearColor and FLinearColor(1, 1, 1, 1) or {R=255,G=255,B=255,A=255}
            if FSlateColor then w:SetColorAndOpacity(FSlateColor(c)) else w:SetColorAndOpacity(c) end
        end)
        pcall(function() w:SetJustification(1) end)
    end
    if Widget.NameText and slua.isValid(Widget.NameText) then apply(Widget.NameText, Text) end
    if Widget.IsGameWidget and Widget.Container then
        pcall(function()
            local W = Widget.Container
            if W and slua.isValid(W) then
                apply(W.TextBlock_TeamName, Text)
                apply(W.TextBlock_PlayerName, Text)
            end
        end)
    end
end

function PlayerMapMarker.UpdateESPHealth(Widget, pct)
    if not Widget then return end
    if not _G.LexusConfig.Esp9_HP then return end
    if Widget.HealthFill then
        pcall(function()
            local PB = Widget.HealthFill
            if PB and slua.isValid(PB) then
                if PB.SetPercent then PB:SetPercent(pct) end
                if PB.SetWidgetVisibility then PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
                local col
                if pct > 0.5 then col = FLinearColor and FLinearColor(0,1,0,1) or {R=0,G=255,B=0,A=255}
                elseif pct > 0.25 then col = FLinearColor and FLinearColor(1,0.5,0,1) or {R=255,G=128,B=0,A=255}
                else col = FLinearColor and FLinearColor(1,0,0,1) or {R=255,G=0,B=0,A=255} end
                if PB.SetFillColorAndOpacity then PB:SetFillColorAndOpacity(col) end
            end
        end)
    end
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
                    local align = FVector2D and FVector2D(0.5, 1.0) or {X=0.5,Y=1.0}
                    pcall(function() Slot:SetAlignment(align) end)
                    pcall(function() Slot:SetZOrder(20) end)
                end
            end
            local bShow = _G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP
            if bShow then Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            else Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            if not Widget._OffsetResetDone then
                pcall(function() Container:SetRenderScale(FVector2D and FVector2D(0.90,0.90) or {X=0.90,Y=0.90}) end)
                pcall(function() Container:SetRenderTransformPivot(FVector2D and FVector2D(0.5,1.0) or {X=0.5,Y=1.0}) end)
                Widget._OffsetResetDone = true
            end
            if Slot and slua.isValid(Slot) then
                local fx = CanvasPos.X
                local fy = CanvasPos.Y
                if not Widget._CachedPosVec then Widget._CachedPosVec = FVector2D and FVector2D(fx, fy) or {X=fx, Y=fy}
                else Widget._CachedPosVec.X = fx; Widget._CachedPosVec.Y = fy end
                pcall(function() Slot:SetPosition(Widget._CachedPosVec) end)
            end
        end
    end)
    return true
end

-- ====================================================================
-- ENEMY BOX system
-- ====================================================================
function PlayerMapMarker.CreateBoxWidgets()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local function makeLine()
        local b = nil
        pcall(function() b = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
        if not b or not slua.isValid(b) then return nil end
        pcall(function() b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        local s = nil
        pcall(function()
            s = PlayerMapMarker.ESPCanvas:AddChildToCanvas(b)
            if s then s:SetAutoSize(false); s:SetZOrder(18) end
        end)
        return { Widget = b, Slot = s }
    end
    return { Top = makeLine(), Bot = makeLine(), Left = makeLine(), Right = makeLine(),
             posVec = FVector2D and FVector2D(0,0) or {X=0,Y=0},
             sizeVec = FVector2D and FVector2D(0,0) or {X=0,Y=0} }
end

function PlayerMapMarker.GetEnemyBounds(Char, PC)
    if not IsValid(Char) or not IsValid(PC) then return nil end
    local mesh = Char.Mesh
    local headLoc, footLoc = nil, nil
    if mesh and Game:IsValid(mesh) and mesh.GetSocketLocation then
        pcall(function() headLoc = mesh:GetSocketLocation("head") end)
        pcall(function() footLoc = mesh:GetSocketLocation("foot_l") or mesh:GetSocketLocation("foot_r") end)
    end
    if not headLoc or not footLoc then
        local al = PlayerMapMarker.GetCharacterLocation(Char)
        if al then
            headLoc = { X = al.X, Y = al.Y, Z = al.Z + 90 }
            footLoc = { X = al.X, Y = al.Y, Z = al.Z - 5 }
        end
    end
    if not headLoc or not footLoc then return nil end

    local b1, headC = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, headLoc)
    local b2, footC = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, footLoc)
    if not b1 or not b2 then return nil end

    local top = headC.Y
    local bot = footC.Y
    local h = bot - top
    if h < 10 then return nil end
    if h > 800 then h = 800 end
    local w = h * 0.55
    if w < 14 then w = 14 end
    if w > 220 then w = 220 end
    local cx = headC.X
    return {
        left = cx - w / 2.0,
        right = cx + w / 2.0,
        top = top,
        bottom = bot,
        w = w, h = h
    }
end

function PlayerMapMarker.UpdateBoxForEnemy(box, bounds, color)
    if not box or not bounds then return end
    local th = 1.5
    local function place(line, x, y, w, h)
        if not line or not line.Widget or not line.Slot then return end
        pcall(function()
            line.Widget:SetBrushColor(color)
            line.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local pv = box.posVec; pv.X = x; pv.Y = y
            local sv = box.sizeVec; sv.X = w; sv.Y = h
            line.Slot:SetPosition(pv)
            line.Slot:SetSize(sv)
        end)
    end
    place(box.Top,   bounds.left,       bounds.top,           bounds.w, th)
    place(box.Bot,   bounds.left,       bounds.bottom - th,   bounds.w, th)
    place(box.Left,  bounds.left,       bounds.top,           th,       bounds.h)
    place(box.Right, bounds.right - th, bounds.top,           th,       bounds.h)
end

function PlayerMapMarker.HideBox(box)
    if not box then return end
    for _, line in pairs({ box.Top, box.Bot, box.Left, box.Right }) do
        if line and line.Widget and slua.isValid(line.Widget) then
            pcall(function() line.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
    end
end

function PlayerMapMarker.DestroyBox(box)
    if not box then return end
    for _, line in pairs({ box.Top, box.Bot, box.Left, box.Right }) do
        if line and line.Widget and slua.isValid(line.Widget) then
            pcall(function() line.Widget:RemoveFromParent() line.Widget:ConditionalBeginDestroy() end)
        end
    end
end

function PlayerMapMarker.RemoveESPWidget(Widget, KeyStr)
    if not Widget then return end
    if Widget.Box then PlayerMapMarker.DestroyBox(Widget.Box); Widget.Box = nil end
    local Container = Widget.Container or Widget
    pcall(function()
        local ptr = tostring(Container)
        PlayerMapMarker.ESPWidgetPtrs[ptr] = nil
        Container:RemoveFromParent()
        Container:ConditionalBeginDestroy()
    end)
    if KeyStr then
        PlayerMapMarker.RemoveSnapLine(KeyStr)
        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
    end
end

-- ====================================================================
-- SNAPLINE
-- ====================================================================
function PlayerMapMarker.CreateSnapLine()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local b = nil
    pcall(function() b = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not b or not slua.isValid(b) then return nil end
    local c = GetColorFromMode(_G.LexusConfig.LineColorMode or 1)
    pcall(function() b:SetBrushColor(c) end)
    pcall(function() b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() b:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5}) end)
    local s = nil
    pcall(function() s = PlayerMapMarker.ESPCanvas:AddChildToCanvas(b); if s then s:SetAutoSize(false); s:SetZOrder(1) end end)
    return { Widget = b, Slot = s, _cachedColorMode = nil, _posVec = FVector2D and FVector2D(0,0) or {X=0,Y=0}, _sizeVec = FVector2D and FVector2D(0,0) or {X=0,Y=0} }
end

function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
    if not PlayerMapMarker.bUseSnapLines then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local L = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if not bOnScreen or not CanvasPos then
        if L and L.Widget and slua.isValid(L.Widget) then
            pcall(function() L.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end
    if not L then
        L = PlayerMapMarker.CreateSnapLine()
        if not L or not L.Widget then return end
        PlayerMapMarker.SnapLineWidgets[KeyStr] = L
    end
    pcall(function() L.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    local cm = _G.LexusConfig.LineColorMode or 1
    if L._cachedColorMode ~= cm then
        pcall(function() L.Widget:SetBrushColor(GetColorFromMode(cm)) end)
        L._cachedColorMode = cm
    end
    local toX = CanvasPos.X
    local toY = CanvasPos.Y + PlayerMapMarker.SnapLineHeadOffsetY
    local dx = toX - fromX
    local dy = toY - fromY
    local len = math.sqrt(dx*dx + dy*dy)
    local ang = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * (180.0 / math.pi)
    local th = PlayerMapMarker.SnapLineThickness or 1.2
    L._posVec.X = fromX; L._posVec.Y = fromY - th / 2.0
    L._sizeVec.X = len; L._sizeVec.Y = th
    pcall(function()
        L.Slot:SetPosition(L._posVec); L.Slot:SetSize(L._sizeVec)
        L.Widget:SetRenderAngle(ang)
    end)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
    local L = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if L and L.Widget and slua.isValid(L.Widget) then
        pcall(function() L.Widget:RemoveFromParent() L.Widget:ConditionalBeginDestroy() end)
        PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
    end
end

-- ====================================================================
-- SKELETON
-- ====================================================================
function PlayerMapMarker.GetBoneLocationWithFallback(Char, name)
    if not IsValid(Char) or not name then return nil end
    local list = PlayerMapMarker.BoneNameFallbacks[name] or {name}
    for _, bn in ipairs(list) do
        local loc = nil
        pcall(function()
            local mesh = Char.Mesh
            if mesh and Game:IsValid(mesh) then
                if mesh.GetSocketLocation then loc = mesh:GetSocketLocation(bn)
                elseif mesh.GetBoneLocation then loc = mesh:GetBoneLocation(bn) end
            end
        end)
        if loc then return loc end
    end
    return nil
end

function PlayerMapMarker.CreateSkeletonLineWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local b = nil
    pcall(function() b = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not b or not slua.isValid(b) then return nil end
    pcall(function() b:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5}) end)
    local s = nil
    pcall(function() s = PlayerMapMarker.ESPCanvas:AddChildToCanvas(b); if s then s:SetAutoSize(false); s:SetZOrder(5) end end)
    return { Widget = b, Slot = s, posVec = FVector2D and FVector2D(0,0) or {X=0,Y=0}, sizeVec = FVector2D and FVector2D(0,0) or {X=0,Y=0} }
end

function PlayerMapMarker.UpdateSkeletonLines(KeyStr, Char, PC, bVisible, color, bOnScreen, charLoc)
    if not PlayerMapMarker.bUseSkeleton then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local B = PlayerMapMarker.SkeletonWidgets[KeyStr]
    if not bVisible or not IsValid(Char) or not IsValid(PC) then
        if B then for _, L in ipairs(B) do
            if L and L.Widget and slua.isValid(L.Widget) then L.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) L.Widget._isSelfHitTestVisible = false end
        end end
        return
    end
    if not charLoc then charLoc = PlayerMapMarker.GetESPLocation(Char) end
    if not charLoc then return end
    if not B then B = {}; PlayerMapMarker.SkeletonWidgets[KeyStr] = B end
    local cache = PlayerMapMarker._StaticBoneLocCache
    for k in pairs(cache) do cache[k] = nil end
    local lineIndex = 0
    local th = PlayerMapMarker.SkeletonThickness
    local col = color or (FLinearColor and FLinearColor(0,1,0,0.8) or {R=0,G=255,B=0,A=200})
    for _, chain in ipairs(PlayerMapMarker.SkeletonChains) do
        local lastX, lastY = nil, nil
        for _, bn in ipairs(chain) do
            local w = cache[bn]
            if w == nil then
                w = PlayerMapMarker.GetBoneLocationWithFallback(Char, bn) or false
                cache[bn] = w
            end
            if w == false then w = nil end
            local cx, cy = nil, nil
            if w then
                local ok, cX, cY = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, w)
                if ok then cx = cX cy = cY end
            end
            if lastX and cx then
                lineIndex = lineIndex + 1
                local L = B[lineIndex]
                if not L or not L.Widget or not slua.isValid(L.Widget) then
                    L = PlayerMapMarker.CreateSkeletonLineWidget()
                    if L then B[lineIndex] = L end
                end
                if L and L.Widget and L.Slot then
                    if L.Widget._cachedColor ~= col then
                        L.Widget:SetBrushColor(col)
                        L.Widget._cachedColor = col
                    end
                    if not L.Widget._isSelfHitTestVisible then
                        L.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                        L.Widget._isSelfHitTestVisible = true
                    end
                    local dx = cx - lastX
                    local dy = cy - lastY
                    local len = math.sqrt(dx*dx + dy*dy)
                    local ang = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * 57.29577951308232
                    L.posVec.X = lastX; L.posVec.Y = lastY - th / 2.0
                    L.sizeVec.X = len; L.sizeVec.Y = th
                    pcall(function()
                        L.Slot:SetPosition(L.posVec); L.Slot:SetSize(L.sizeVec)
                        L.Widget:SetRenderAngle(ang)
                    end)
                end
            end
            lastX = cx; lastY = cy
        end
    end
    for i = lineIndex + 1, #B do
        local L = B[i]
        if L and L.Widget and slua.isValid(L.Widget) then
            L.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            L.Widget._isSelfHitTestVisible = false
        end
    end
end

function PlayerMapMarker.RemoveSkeletonLines(KeyStr)
    local B = PlayerMapMarker.SkeletonWidgets[KeyStr]
    if B then
        for _, L in ipairs(B) do
            if L and L.Widget and slua.isValid(L.Widget) then
                pcall(function() L.Widget:RemoveFromParent() L.Widget:ConditionalBeginDestroy() end)
            end
        end
        PlayerMapMarker.SkeletonWidgets[KeyStr] = nil
    end
end

-- ====================================================================
-- REAL / BOT COUNTERS (top-left of canvas)
-- ====================================================================
local CounterUI = { bActive = false, RealBox = nil, BotBox = nil, RealTxt = nil, BotTxt = nil,
                    LastReal = -1, LastBot = -1 }

function CounterUI.Create()
    if CounterUI.RealBox and slua.isValid(CounterUI.RealBox) then return true end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return false end
    local canvas = PlayerMapMarker.ESPCanvas
    local LC = FLinearColor
    local V2 = FVector2D
    local SC = FSlateColor

    local function makeBox(r, g, b)
        local bx = nil
        pcall(function() bx = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
        if not bx or not slua.isValid(bx) then return nil, nil end
        pcall(function() bx:SetBrushColor(LC and LC(r, g, b, 0.9) or {R=r*255, G=g*255, B=b*255, A=230}) end)
        pcall(function() bx:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        local s = nil
        pcall(function()
            s = canvas:AddChildToCanvas(bx)
            if s then s:SetAutoSize(false); s:SetZOrder(999) end
        end)
        return bx, s
    end

    local function makeTxt()
        local t = nil
        pcall(function() t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", canvas) end)
        if not t or not slua.isValid(t) then return nil, nil end
        pcall(function()
            t:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            local f = t.Font; f.Size = 22; t.Font = f
            t:SetJustification(1)
            local w = LC and LC(1, 1, 1, 1) or {R=255,G=255,B=255,A=255}
            if SC then t:SetColorAndOpacity(SC(w)) else t:SetColorAndOpacity(w) end
        end)
        local s = nil
        pcall(function()
            s = canvas:AddChildToCanvas(t)
            if s then s:SetAutoSize(false); s:SetZOrder(1000) end
        end)
        return t, s
    end

    CounterUI.RealBox = select(1, makeBox(0.9, 0.1, 0.1))
    CounterUI.BotBox  = select(1, makeBox(0.1, 0.8, 0.1))
    CounterUI.RealTxt = select(1, makeTxt())
    CounterUI.BotTxt  = select(1, makeTxt())

    local function posSize(w, x, y, sw, sh)
        if not w or not slua.isValid(w) then return end
        pcall(function()
            local s = w.Slot
            if s then
                s:SetPosition(V2 and V2(x, y) or {X=x, Y=y})
                s:SetSize(V2 and V2(sw, sh) or {X=sw, Y=sh})
            end
        end)
    end
    posSize(CounterUI.RealBox, 20, 20, 190, 34)
    posSize(CounterUI.BotBox,  220, 20, 190, 34)
    posSize(CounterUI.RealTxt, 20, 24, 190, 30)
    posSize(CounterUI.BotTxt,  220, 24, 190, 30)
    CounterUI.bActive = true
    return true
end

function CounterUI.SetCounts(real, bot)
    if not CounterUI.bActive then if not CounterUI.Create() then return end end
    if CounterUI.LastReal == real and CounterUI.LastBot == bot then return end
    CounterUI.LastReal = real; CounterUI.LastBot = bot
    if CounterUI.RealTxt and slua.isValid(CounterUI.RealTxt) then
        pcall(function() CounterUI.RealTxt:SetText(string.format("REAL: %d", real)) end)
    end
    if CounterUI.BotTxt and slua.isValid(CounterUI.BotTxt) then
        pcall(function() CounterUI.BotTxt:SetText(string.format("BOT: %d", bot)) end)
    end
end

function CounterUI.Hide()
    for _, w in ipairs({ CounterUI.RealBox, CounterUI.BotBox, CounterUI.RealTxt, CounterUI.BotTxt }) do
        if w and slua.isValid(w) then
            pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
    end
end

function CounterUI.Show()
    for _, w in ipairs({ CounterUI.RealBox, CounterUI.BotBox, CounterUI.RealTxt, CounterUI.BotTxt }) do
        if w and slua.isValid(w) then
            pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        end
    end
end

function CounterUI.Destroy()
    for _, w in ipairs({ CounterUI.RealBox, CounterUI.BotBox, CounterUI.RealTxt, CounterUI.BotTxt }) do
        if w and slua.isValid(w) then
            pcall(function() w:RemoveFromParent() w:ConditionalBeginDestroy() end)
        end
    end
    CounterUI.RealBox = nil; CounterUI.BotBox = nil
    CounterUI.RealTxt = nil; CounterUI.BotTxt = nil
    CounterUI.bActive = false
    CounterUI.LastReal = -1; CounterUI.LastBot = -1
end

_G.CounterUI = CounterUI

-- ====================================================================
-- LIGHT TICK: position + box, 0.02s (50 FPS)
-- ====================================================================
function PlayerMapMarker.UpdateESPLight()
    if not PlayerMapMarker.bActive then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end

    PlayerMapMarker.bUseSnapLines = _G.LexusConfig.Esp9_Line
    PlayerMapMarker.bUseSkeleton = _G.LexusConfig.Esp9_Skeleton
    PlayerMapMarker.bUseBox = _G.LexusConfig.Esp9_Box

    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end

    for KeyStr, D in pairs(PlayerMapMarker.ESPWidgets) do
        local W = D.Widget
        local Char = D.Character
        local Container = W and (W.Container or W)
        if W and Container and slua.isValid(Container) and IsValid(Char) then
            local bAlive = PlayerMapMarker.IsAlive(Char)
            if not bAlive then
                pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                if W.Box then PlayerMapMarker.HideBox(W.Box) end
                PlayerMapMarker.RemoveSnapLine(KeyStr)
                PlayerMapMarker.RemoveSkeletonLines(KeyStr)
            else
                local bShow = _G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP
                if bShow then
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                else
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                end
                local Loc = PlayerMapMarker.GetESPLocation(Char)
                if Loc then
                    local bOn, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                    PlayerMapMarker.UpdateESPPositionWithPC(W, Loc, PC, CanvasPos)

                    -- ===== BOX =====
                    if PlayerMapMarker.bUseBox then
                        local bounds = PlayerMapMarker.GetEnemyBounds(Char, PC)
                        if bounds then
                            if not W.Box then W.Box = PlayerMapMarker.CreateBoxWidgets() end
                            local boxColor
                            if W.IsBot then
                                boxColor = FLinearColor and FLinearColor(0, 1, 1, 1) or {R=0, G=255, B=255, A=255}
                            else
                                boxColor = FLinearColor and FLinearColor(1, 0.15, 0.15, 1) or {R=255, G=40, B=40, A=255}
                            end
                            if W.Box then
                                PlayerMapMarker.UpdateBoxForEnemy(W.Box, bounds, boxColor)
                            end
                        else
                            if W.Box then PlayerMapMarker.HideBox(W.Box) end
                        end
                    else
                        if W.Box then PlayerMapMarker.HideBox(W.Box) end
                    end
                    -- ================

                    if PlayerMapMarker.bUseSnapLines then
                        PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOn, fromX, fromY)
                    else
                        PlayerMapMarker.RemoveSnapLine(KeyStr)
                    end
                    if PlayerMapMarker.bUseSkeleton then
                        PlayerMapMarker.UpdateSkeletonLines(KeyStr, Char, PC, true, nil, bOn, Loc)
                    else
                        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                    end
                end
            end
        end
    end
end

-- ====================================================================
-- DISTANCE TICK: text + HP, 0.15s
-- ====================================================================
function PlayerMapMarker.UpdateESPDistances()
    if not PlayerMapMarker.bActive then return end
    local MyLoc = PlayerMapMarker.GetMyLocation()
    if not MyLoc then return end
    for KeyStr, D in pairs(PlayerMapMarker.ESPWidgets) do
        local W = D.Widget
        local Char = D.Character
        local Container = W and (W.Container or W)
        if W and Container and slua.isValid(Container) and IsValid(Char) then
            local Loc = PlayerMapMarker.GetESPLocation(Char)
            if Loc then
                local DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
                local Name = D.Name or "Unknown"
                local Txt = ""
                if _G.LexusConfig.Esp9_Name then Txt = Name end
                if _G.LexusConfig.Esp9_Distance and DistStr ~= "" then
                    if Txt ~= "" then Txt = string.format("%s [%s]", Txt, DistStr) else Txt = string.format("[%s]", DistStr) end
                end
                W._LastESPText = nil
                PlayerMapMarker.UpdateESPText(W, Txt)
                local HP = Char.Health or 0
                local MH = Char.MaxHealth or 120
                local pct = 0
                if HP > 0 and MH > 0 then pct = math.min(1, math.max(0, HP / MH)) end
                PlayerMapMarker.UpdateESPHealth(W, pct)
            end
        end
    end
end

-- ====================================================================
-- HEAVY SCAN: widget create/destroy + counters, 0.1s
-- ====================================================================
function PlayerMapMarker.ScanAndUpdate()
    PlayerMapMarker.bUseSnapLines = _G.LexusConfig.Esp9_Line
    PlayerMapMarker.bUseSkeleton = _G.LexusConfig.Esp9_Skeleton
    PlayerMapMarker.bUseBox = _G.LexusConfig.Esp9_Box

    if not PlayerMapMarker.InitESPCanvas() then return end

    local AllChars = PlayerMapMarker.GetAllCharacters()
    if not AllChars then return end
    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local MyLoc = PlayerMapMarker.GetMyLocation()
    PlayerMapMarker._CachedMyLoc = MyLoc
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end
    local SeenKeys = {}
    local MyChar = nil
    pcall(function()
        local GD = PlayerMapMarker.GetGameplayData()
        if GD and GD.GetLocalCharacter then MyChar = GD.GetLocalCharacter() end
    end)
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

    for PlayerKey, Char in pairs(AllChars) do
        if IsValid(Char) then
            local bIsMe = PlayerMapMarker.IsMe(Char, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Char)
            local KeyStr = tostring(PlayerKey)
            local Name = PlayerMapMarker.GetPlayerName(Char)
            local Loc = PlayerMapMarker.GetESPLocation(Char)
            local DistStr = ""
            if MyLoc and Loc then DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc) end
            local bSkip = false
            if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
            if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
            local TeamID = PlayerMapMarker.GetTeamID(Char)
            if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then bSkip = true end
            local bAlive = PlayerMapMarker.IsAlive(Char)

            if not bSkip and Loc then
                SeenKeys[KeyStr] = true
                local D = PlayerMapMarker.ESPWidgets[KeyStr]
                local Txt = ""
                if _G.LexusConfig.Esp9_Name then Txt = Name end
                if _G.LexusConfig.Esp9_Distance and DistStr ~= "" then
                    if Txt ~= "" then Txt = string.format("%s [%s]", Txt, DistStr) else Txt = string.format("[%s]", DistStr) end
                end
                local bOn, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                if not D then
                    local W = PlayerMapMarker.CreateESPWidget()
                    if W then
                        W.Box = PlayerMapMarker.CreateBoxWidgets()
                        W.IsBot = bIsAI
                        PlayerMapMarker.ESPWidgets[KeyStr] = { Widget = W, Character = Char, Name = Name, TeamID = TeamID }
                        PlayerMapMarker.UpdateESPText(W, Txt)
                        if bAlive then
                            PlayerMapMarker.UpdateESPPositionWithPC(W, Loc, PC, CanvasPos)
                            local HP = Char.Health or 0
                            local MH = Char.MaxHealth or 120
                            local pct = 0
                            if HP > 0 and MH > 0 then pct = math.min(1, math.max(0, HP / MH)) end
                            PlayerMapMarker.UpdateESPHealth(W, pct)
                        else
                            pcall(function() (W.Container or W):SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                        end
                    end
                else
                    D.Character = Char
                    D.Name = Name
                    if D.Widget then D.Widget.IsBot = bIsAI end
                    if bAlive then
                        D.TeamID = TeamID
                        D.Widget._LastESPText = nil
                        PlayerMapMarker.UpdateESPText(D.Widget, Txt)
                        PlayerMapMarker.UpdateESPPositionWithPC(D.Widget, Loc, PC, CanvasPos)
                    else
                        pcall(function() (D.Widget.Container or D.Widget):SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                        if D.Widget.Box then PlayerMapMarker.HideBox(D.Widget.Box) end
                    end
                end
            end
        end
    end
    for K, D in pairs(PlayerMapMarker.ESPWidgets) do
        if not SeenKeys[K] then
            PlayerMapMarker.RemoveESPWidget(D.Widget, K)
            PlayerMapMarker.ESPWidgets[K] = nil
        end
    end

    -- ==== REAL / BOT counter ====
    pcall(function()
        if not _G.LexusConfig.Esp9_Count then
            if CounterUI.bActive then CounterUI.Hide() end
            return
        end
        local realC, botC = 0, 0
        for _, D in pairs(PlayerMapMarker.ESPWidgets) do
            if D.Character and IsValid(D.Character) and PlayerMapMarker.IsAlive(D.Character) then
                if D.Widget and D.Widget.IsBot then botC = botC + 1
                else realC = realC + 1 end
            end
        end
        if not CounterUI.bActive then CounterUI.Create() end
        CounterUI.Show()
        CounterUI.SetCounts(realC, botC)
    end)
end

function PlayerMapMarker.Start()
    if PlayerMapMarker.bActive then return end
    if not PlayerMapMarker.InitESPCanvas() then return end
    PlayerMapMarker.bActive = true
    PlayerMapMarker.ScanAndUpdate()
end
function PlayerMapMarker.Stop()
    PlayerMapMarker.bActive = false
    for K, D in pairs(PlayerMapMarker.ESPWidgets) do PlayerMapMarker.RemoveESPWidget(D.Widget, K) end
    PlayerMapMarker.ESPWidgets = {}
    PlayerMapMarker.ESPWidgetPtrs = {}
    for K, _ in pairs(PlayerMapMarker.SnapLineWidgets) do PlayerMapMarker.RemoveSnapLine(K) end
    for K, _ in pairs(PlayerMapMarker.SkeletonWidgets) do PlayerMapMarker.RemoveSkeletonLines(K) end
    PlayerMapMarker.ESPCanvas = nil
    PlayerMapMarker._OBHeadWidgetClass = nil
    pcall(function() CounterUI.Destroy() end)
end
_G.PlayerMapMarker = PlayerMapMarker

-- ====================================================================
-- WALLHACK V2 (GPU)
-- ====================================================================
local WH2_READY = false
local WH2_RUNNING = false
local WH2_STOPPED = false
local WH2_SEEN = {}
local WH2_TICKS = 0
local WH2_TMR = nil
local WH2_ITV = 0.3
local WH2_SLOTS = {0,1,2,3,4,5,6,7}
local WH2_VIS  = FLinearColor and FLinearColor(0,1,0,1) or {R=0,G=255,B=0,A=255}
local WH2_OCC  = FLinearColor and FLinearColor(1,0,0,1) or {R=255,G=0,B=0,A=255}
local WH2_BVIS = FLinearColor and FLinearColor(0,0.7,0,0.8) or {R=0,G=180,B=0,A=200}
local WH2_BOCC = FLinearColor and FLinearColor(0.7,0,0,0.8) or {R=180,G=0,B=0,A=200}

local function WH2_SetupConsole()
    if WH2_READY then return end
    pcall(function()
        local KSL = KismetSystemLibrary
        local world = slua.getWorld()
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        WH2_READY = true
    end)
end

local function WH2_ApplyMesh(mesh, vc, oc)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(vc)
        mesh:SetOccludedDyeingColor(oc)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(vc)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(vc)
        mesh:SetIdeaOutlineOcclusionColor(oc)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function WH2_Tick()
    if WH2_STOPPED or not _G.LexusConfig.WallhackV2 then return end
    pcall(function()
        local GD = PlayerMapMarker.GetGameplayData() or GameplayData
        local lp = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
        if not IsValid(lp) then return end
        WH2_SetupConsole()
        WH2_TICKS = WH2_TICKS + 1
        if WH2_TICKS % 6 == 0 then WH2_SEEN = {} end
        local myTeam = lp.TeamID or 0
        local pawns = {}
        if GD.GetAllPlayerCharacters then pawns = GD.GetAllPlayerCharacters() or {}
        elseif GD.GameCharacters then for _, c in pairs(GD.GameCharacters) do table.insert(pawns, c) end end
        local n = 0
        for _, pawn in pairs(pawns) do
            if n >= 20 then break end
            if IsValid(pawn) and pawn ~= lp then
                local pid = tostring(pawn.PlayerKey or pawn)
                if not WH2_SEEN[pid] then
                    if (pawn.TeamID or 0) ~= myTeam and (pawn.Health or 100) > 0 then
                        local bot = false
                        pcall(function() if pawn.bIsAI or pawn.AIData then bot = true end end)
                        local vc = bot and WH2_BVIS or WH2_VIS
                        local oc = bot and WH2_BOCC or WH2_OCC
                        pcall(function()
                            if pawn.Mesh and slua.isValid(pawn.Mesh) then WH2_ApplyMesh(pawn.Mesh, vc, oc) end
                            local av = pawn.CharacterAvatarComp2_BP
                            if not av and type(pawn.getAvatarComponent2) == "function" then av = pawn:getAvatarComponent2() end
                            if av and av.GetMeshCompBySlot then
                                for _, s in ipairs(WH2_SLOTS) do
                                    local m = av:GetMeshCompBySlot(s)
                                    if m and slua.isValid(m) then WH2_ApplyMesh(m, vc, oc) end
                                end
                            end
                            local w = type(pawn.GetCurrentWeapon) == "function" and pawn:GetCurrentWeapon()
                            if w and slua.isValid(w) and w.Mesh and slua.isValid(w.Mesh) then WH2_ApplyMesh(w.Mesh, vc, oc) end
                        end)
                        WH2_SEEN[pid] = true
                        n = n + 1
                    end
                end
            end
        end
    end)
end

local function WH2_Start()
    if WH2_RUNNING then return end
    WH2_RUNNING = true
    WH2_STOPPED = false
    WH2_SetupConsole()
    if WH2_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH2_TMR) end end); WH2_TMR = nil end
    if _G.Game and type(_G.Game.AddGameTimer) == "function" then
        WH2_TMR = _G.Game:AddGameTimer(WH2_ITV, true, WH2_Tick)
        return
    end
    local ok, tk = pcall(require, "common.time_ticker")
    if ok and tk and tk.AddTimerOnce then
        local function loop()
            if WH2_STOPPED then return end
            WH2_Tick()
            if _G.LexusConfig and _G.LexusConfig.WallhackV2 and not WH2_STOPPED then
                tk.AddTimerOnce(WH2_ITV, loop)
            end
        end
        tk.AddTimerOnce(WH2_ITV, loop)
    end
end

local function WH2_Stop()
    WH2_RUNNING = false
    WH2_STOPPED = true
    if WH2_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH2_TMR) end end); WH2_TMR = nil end
    WH2_SEEN = {}; WH2_TICKS = 0; WH2_READY = false
end

-- ==================== iPAD VIEW ====================
local function ApplyIpadView()
    pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or _G.GameplayData
        if not GD then return end
        local me = GD.GetPlayerCharacter and GD.GetPlayerCharacter()
        if not Valid(me) then return end
        local cam = me.ThirdPersonCameraComponent
        if not Valid(cam) then return end
        local target = 90
        if _G.LexusConfig.IpadView then target = _G.LexusState.CustomTextData.IpadFOV or 120 end
        if cam.FieldOfView ~= target then cam.FieldOfView = target end
    end)
end

-- ==================== HWID SPOOF ====================
local function HWID_SpoofTick()
    pcall(function()
        local SystemLib = KismetSystemLibrary
        if SystemLib and not _G.FakeHWID_Hooked then
            _G.Original_GetDeviceId = SystemLib.GetDeviceId
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then
                        local chars = "0123456789abcdef"
                        local hwid = ""
                        for i = 1, 32 do hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) end
                        _G.FakeHWID_String = hwid
                    end
                    return _G.FakeHWID_String
                end
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
        end
    end)
end

-- ==================== MAIN LOOPS ====================
local _heavyFrame = 0

local function HeavyTick()
    _heavyFrame = _heavyFrame + 1

    if _G.LexusConfig.EspLoai9 then
        if not PlayerMapMarker.bActive then PlayerMapMarker.Start() end
        if _heavyFrame % 5 == 0 then pcall(PlayerMapMarker.ScanAndUpdate) end
    else
        if PlayerMapMarker.bActive then PlayerMapMarker.Stop() end
    end

    if _G.LexusConfig.WallhackV2 and not WH2_RUNNING then pcall(WH2_Start)
    elseif not _G.LexusConfig.WallhackV2 and WH2_RUNNING then pcall(WH2_Stop) end

    pcall(ApplyIpadView)
    pcall(HWID_SpoofTick)

    pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
        local pc = GD and GD.GetPlayerController and GD.GetPlayerController()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(0.1, HeavyTick) end
end

local function LightTick()
    if _G.LexusConfig.EspLoai9 and PlayerMapMarker.bActive then
        pcall(PlayerMapMarker.UpdateESPLight)
    end
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(0.02, LightTick) end
end

local function DistanceTick()
    if _G.LexusConfig.EspLoai9 and PlayerMapMarker.bActive then
        pcall(PlayerMapMarker.UpdateESPDistances)
    end
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(0.15, DistanceTick) end
end

-- ==================== WELCOME ====================
function _G.ShowLexusVIPMenu()
    if _G.LexusMenuShown then return end
    _G.LexusMenuShown = true
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end
        local content = [[
╔═══════════════════════════════╗
║   ◆ TESLA 10X GAMING ◆        ║
║         VIP LUA 5.1          ║
║      ━━━━━━━━━━━━━━━━         ║
║   ✓ SMOOTH ESP (50FPS)        ║
║   ✓ ENEMY BOX + COUNTERS      ║
║   ✓ GPU WALLHACK              ║
║   ✓ HEADSHOT / BIGHEAD        ║
║   ✓ IPAD VIEW + COLORS        ║
║   ✓ BYPASS 20-LAYER ULTRA     ║
║   ━━━━━━━━━━━━━━━━            ║
║   Dev: @OFFICIALOWNER10X      ║
╚═══════════════════════════════╝

ACTIVATION SUCCESSFUL!

Open Settings → Privacy → ◆ TESLA 10X GAMING VIP ◆]]
        Msg.Show(1, "◆ TESLA 10X GAMING ◆ VIP 5.1", content,
            function() Notify("VIP MENU ADDED! SETTINGS → PRIVACY TAB.") end,
            function() end, "OK", "")
    end)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage("◆ TESLA 10X GAMING ◆ VIP 5.1 | @OFFICIALOWNER10X", -1, 8.0, {R=1, G=0.85, B=0, A=1}, {X=1.2, Y=1.5})
        end
    end)
end

-- ==================== START ====================
InitModMenuTab()
_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
pcall(function()
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then
        t.AddTimerOnce(1.0, HeavyTick)
        t.AddTimerOnce(1.2, LightTick)
        t.AddTimerOnce(1.4, DistanceTick)
        t.AddTimerOnce(3.0, function() pcall(ShowLexusVIPMenu) end)
    else
        if Game and Game.AddGameTimer then
            Game:AddGameTimer(0.1, true, HeavyTick)
            Game:AddGameTimer(0.02, true, LightTick)
            Game:AddGameTimer(0.15, true, DistanceTick)
            Game:AddGameTimer(3.0, false, ShowLexusVIPMenu)
        end
    end
end)
Notify("◆ TESLA 10X GAMING VIP 5.1 FIXED LOADED ◆")

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
  { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.Gameplay.Feature.ParachuteFormationFeature" },
  { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
}, "BRPlayerCharacterBase")