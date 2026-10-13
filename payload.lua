-- ====================================================================
-- BRPlayerCharacterBase.lua — TESLA 10X 6.1
-- Wallhack (pose-aware) + Glowing Body + Box ESP
-- Bypass 20L + iPad View + Aim Assist
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
function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal) BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal); if self.Object ~= uPawn then return end; if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end end end
function BRPlayerCharacterBase:OnPawnStateChange(PawnState) if PawnState == EPawnState.SwitchPP then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end end end
function BRPlayerCharacterBase:HandleFinishedState() if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then local m = import("EDynamicSimpleQueryConfigDisableMask"); self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(m.Bit0, true) end end
function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent() if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then local gt = CGameMode.GameModeType; local gid = tonumber(CGameState.GameModeID); return (gt == EGameModeType.ETypicalGameMode or gt == EGameModeType.EFourInOneGameMode or gt == EGameModeType.EHeavyWeaponGameMode) and (not MatchModeIds[gid]) end; return false end
function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(L, N) BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, L, N); if not Client then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then if N == EParachuteState.PS_Opening then if uPC.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then uPC.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI() end elseif N == EParachuteState.PS_None then if uPC.CheckParachuteOpenFeature.RecoverParachuteOpenParam then uPC.CheckParachuteOpenFeature:RecoverParachuteOpenParam() end; if uPC.CheckParachuteOpenFeature.ClearTimerAndState then uPC.CheckParachuteOpenFeature:ClearTimerAndState() end end end end end
function BRPlayerCharacterBase:OnLanded() if self.HandleOnLanded then self:HandleOnLanded(-1) end; if not Client then local uPC = self:GetPlayerControllerSafety(); if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then if uPC.CheckParachuteOpenFeature.ClearTimerAndState then uPC.CheckParachuteOpenFeature:ClearTimerAndState() end; if uPC.CheckParachuteOpenFeature.ResetCheckShowUI then uPC.CheckParachuteOpenFeature:ResetCheckShowUI() end end end end
function BRPlayerCharacterBase:ReceiveEndPlay(r) BRPlayerCharacterBase.__super.ReceiveEndPlay(self, r); if Client then GameplayData.RemoveCharacter(self.Object) end end
function BRPlayerCharacterBase:IsWarGameMode() local gs = GameplayData:GetGameState(); if slua.isValid(gs) and Game:IsClassOf(gs, STExtraGameStateBase) then return gs.GameModeType == EGameModeType.EWarGameMode end; return false end
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
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then self.CharacterMovement:SetBase(nil, "", true) end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI) end
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
  if vid then local UAvatarUtils = import("AvatarUtils"); if UAvatarUtils.GetVehicleShapeBySkinID(vid) == t.VST_Horse then local ps = self:GetPlayerStateSafety(); if slua.isValid(ps) then ps:AddGeneralCount(468, 1, false) end end end
end
function BRPlayerCharacterBase:ParachuteJump()
  local pc = self:GetControllerSafety()
  if slua.isValid(pc) then
    if not self:GetEnsure() then
      if pc:GetCurrentStateType() ~= EStateType.State_ParachuteJump and pc:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false); pc:ReInitParachuteItem(); pc:ServerChangeStatePC(EStateType.State_ParachuteJump) end
    else EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object) end
  end
end
function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uChar, uNew, uOld) if uChar ~= self.Object then return end; local crane = self:GetMedievalCraneFromBase(uNew); if crane and crane.AddCharacter then crane:AddCharacter(self.Object) else crane = self:GetMedievalCraneFromBase(uOld); if crane and crane.RemoveCharacter then crane:RemoveCharacter(self.Object) end end end
function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base) if not slua.isValid(Base) or not Base.GetOwner then return end; local Lifter = Base:GetOwner(); if not slua.isValid(Lifter) then return end; if not Lifter.AddCharacter then return end; return Lifter end
function BRPlayerCharacterBase:CheckForbidFlaregun() local ps = self:GetPlayerStateSafety(); if not slua.isValid(ps) then return false end; if ps.CanUseFlaregun == false and self:IsLocallyControlled() then local pc = self:GetPlayerControllerSafety(); if slua.isValid(pc) then pc:DisplayGameTipWithMsgID(48532) end end; return not ps.CanUseFlaregun end
function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end
function BRPlayerCharacterBase:HandleNearDeathGiveupRescue() local comp = self.NearDeatchComponent; if self:IsNearDeath() and slua.isValid(comp) and self.bCanNearDeathGiveup == true then local ps = self:GetPlayerStateSafety(); if slua.isValid(ps) then ps:AddGeneralCount(1613, 1, false) end; comp:TriggerGotoDieExplictly(self.Object) end end
function BRPlayerCharacterBase:RPC_Server_GmPlayAction(id) if USTExtraBlueprintFunctionLibrary.IsDevelopment() then self:MulticastRPC_GmPlayAction(id) end end
function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(id) if not Client then return end; local comp = self:GetPlayEmoteComponent(); if not slua.isValid(comp) then return end; local cfg = CDataTable.GetTableData("EmoteBPTable", id); if not cfg then return end; local hp = cfg.Path; local A = slua.loadObject(hp); local arr = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath")); local h = A(); comp:OnLoadEmoteAssetBegin(h, id, arr, ""); local tb = FuncUtil.LuaArrayToTable(arr); local au = require("common.asset_util"); local function later() comp:OnLoadEmoteAssetEnd(h, id, 0) end; au.GetAssetsArrayAsyncParallel(tb, later) end
function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(v) if slua.isValid(self.ParachuteComponent) then self.ParachuteComponent.bServerSyncShouldCheckPassWall = v end end
function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState() self.Super:OnPlayerEnterCarryBoxState(); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end end
function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(b) self.Super:OnPlayerLeaveCarryBoxState(b); if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(b) end end
function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uIn) if slua.isValid(uIn) and Game:IsClassOf(uIn, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:CarryDeadBox(uIn) end end
function BRPlayerCharacterBase:SetAreaID(id) self:SetAttrValue("AreaID", id, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end
function BRPlayerCharacterBase:DoModChangeToBT() if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end end
function BRPlayerCharacterBase:SwitchCameraToParachuteOpening() self.Super:SwitchCameraToParachuteOpening(); if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end end
function BRPlayerCharacterBase:SwitchCameraToParachuteFalling() self.Super:SwitchCameraToParachuteFalling(); if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then self.ParachuteFormation:OverlayFormationCameraParams() end end
function BRPlayerCharacterBase:SwitchCameraToNormal() self.Super:SwitchCameraToNormal(); if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then self.ParachuteFormation:OnLandingClearFormationCamera() end end
function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then local w = self:GetWeaponBySlot(Slot); if slua.isValid(w) then local wid = w:GetWeaponID(); local cfg = GamePlayTools.GetCurrentConfig("AttachToOtherConfig"); if cfg and cfg.CheckIsWeaponInBlackList and cfg.CheckIsWeaponInBlackList(wid) then local pc = self:GetPlayerControllerSafety(); if Client and slua.isValid(pc) and pc.Role == ENetRole.ROLE_AutonomousProxy then pc:DisplayGameTipWithMsgID(47306) end; return false end end end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then local o = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing); if slua.isValid(o) then local s = o:GetCurMoveState(); if s == ESpiderSwingMoveState.Launching or s == ESpiderSwingMoveState.Swinging then return false end end end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ====================================================================
-- MOD
-- ====================================================================
local BRAND = "TESLA 10X 6.1"
local _slua = rawget(_G, "slua")
local function Valid(o) if o == nil then return false end; if _slua and _slua.isValid then local ok, v = pcall(_slua.isValid, o); return ok and v end; return true end
local function Notify(msg)
    pcall(function() local Msg = require("client.slua.logic.common.logic_common_msg_box"); if Msg and Msg.Show then Msg.Show(1, "◆ " .. BRAND .. " ◆", tostring(msg), function() end, function() end, "OK", "") return end end)
    pcall(function() local sh = import("ScriptHelperClient"); if sh and sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage("[" .. BRAND .. "]" .. tostring(msg), -1, 3.0, {R=1,G=0.85,B=0,A=1}, {X=1.2, Y=1.2}) end end)
    print("[" .. BRAND .. "] " .. tostring(msg))
end
_G.LexusNotify = Notify

_G.LexusConfig = _G.LexusConfig or {
    EspLoai9 = false,
    Esp9_Box = true,
    Esp9_Name = false,
    Esp9_Distance = false,
    Esp9_HP = false,
    Esp9_Line = false,
    Esp9_Skeleton = false,
    Esp9_Count = false,
    WallhackV2 = true,
    GlowBody = false,
    GlowColor = 5,
    GlowThickness = 15,
    IpadView = false,
    AimAssist = true,
    Headshot = false,
    FakeHWID = false,
}
_G.LexusState = _G.LexusState or { LoopToken = 0, CustomTextData = { IpadFOV = 120 } }

-- HEADSHOT
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
                if not mod._HSOrigGet then mod._HSOrigGet = mod.GetHitBodyType; mod._HSOrigGetByPos = mod.GetHitBodyTypeByHitPos end
                mod.GetHitBodyType = function(self, a, b) if _G.LexusConfig.Headshot then return EAvatarDamagePosition.BigHead end; if mod._HSOrigGet then return mod._HSOrigGet(self, a, b) end end
                mod.GetHitBodyTypeByHitPos = function(self, a) if _G.LexusConfig.Headshot then return EAvatarDamagePosition.BigHead end; if mod._HSOrigGetByPos then return mod._HSOrigGetByPos(self, a) end end
            end
        end
    end
    DoHook()
    local ok, tk = pcall(require, "common.time_ticker")
    if ok and tk and tk.AddTimerOnce then for i = 1, 10 do tk.AddTimerOnce(i * 2.0, function() pcall(DoHook) end) end end
end)

-- BYPASS 20-LAYER
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
        local targets = {"CoronaLabSubsystem","ClientReportPlayerSubsystem","DSReportPlayerSubsystem","ShootVerifySubSystemClient","BehaviorScoreSubsystem","AntiCheatSubsystem","GameReportSubsystem","OperationalStatsSubsystem","SwiftHawkSubsystem","PlayerSecurityInfoSubsystem","ModifierExceptionSubsystem","IntegrityCheckSubsystem","FileCheckSubsystem","MemoryCheckSubsystem","SpeedCheckSubsystem","WallCheckSubsystem","AvatarExceptionSubsystem","ClientDataStatistcsSubsystem","AFKReportorSubsystem","ClientCircleFlowSubsystem","MrpcsFlowSubsystem","ReplaySubsystem","TssSdkSubsystem","TLogSubsystem","CrashSightSubsystem","HiggsBosonSubsystem","NetCheckSubsystem","CheatReportSubsystem","PunishmentSubsystem","PlayerMovementVerifySubsystem","WeaponIntegritySubsystem","SkinIntegritySubsystem","CharacterIntegritySubsystem","VehicleIntegritySubsystem","LobbyVerifySubsystem","BootVerifySubsystem","StartupCheckSubsystem","ProcessCheckSubsystem","RootDetectSubsystem","EmulatorDetectSubsystem","DebugDetectSubsystem","InjectionDetectSubsystem","HookDetectSubsystem","ModuleScanSubsystem","AntiTamperSubsystem","SigCheckSubsystem","AssetVerifySubsystem","PakVerifySubsystem","LuaIntegritySubsystem","BytecodeVerifySubsystem","EncryptionCheckSubsystem"}
        for _, n in ipairs(targets) do
            local s = subMgr:Get(n)
            if s then
                for k, v in pairs(s) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Collect") or k:find("Scan") or k:find("Detect") or k:find("Tamper") or k:find("Punish") or k:find("Ban") or k:find("Kick")) then pcall(function() s[k] = nop end) end end
                for _, tf in ipairs({"TimerHandle","timer","heartbeatTimer","reportTimer","scanTimer","checkTimer","verifyTimer","detectTimer"}) do if s[tf] then pcall(function() s:RemoveGameTimer(s[tf]); s[tf] = nil end) end end
            end
        end
    end
    local nu = _G.NetUtil
    if nu and nu.SendPacket and not nu._BypassActive then
        local orig = nu.SendPacket
        local blk = {["ReportAttackFlow"]=1,["ReportSecAttackFlow"]=1,["ReportHitFlow"]=1,["ReportAimFlow"]=1,["ReportPlayerBehavior"]=1,["ReportVerifyInfoFlow"]=1,["ReportFireArms"]=1,["ReportMrpcsFlow"]=1,["ReportTeammatHurt"]=1,["ReportPlayerPosition"]=1,["ReportPlayerMoveRoute"]=1,["on_tss_sdk_anti_data"]=1,["ClientSecMrpcsFlow"]=1,["MrpcsData"]=1,["SwiftHawk"]=1,["ClientSwiftHawk"]=1,["AntiCheatReport"]=1,["CheatDetection"]=1,["ViolationReport"]=1,["SecurityViolation"]=1,["IntegrityCheck"]=1,["SignatureVerify"]=1,["BanPlayer"]=1,["KickPlayer"]=1,["NotifyBan"]=1,["ApplyPunishment"]=1,["ReportEquipmentFlow"]=1,["ReportPlayersPing"]=1,["ReportPlayerIP"]=1,["ReportCircleFlow"]=1,["ReportWallCheck"]=1,["ReportMemoryCheck"]=1,["ReportFileCheck"]=1,["ReportHookCheck"]=1,["ReportRootDetect"]=1,["ReportEmulatorDetect"]=1,["ReportDebugDetect"]=1,["ReportInjection"]=1,["ReportTamper"]=1,["ReportLuaIntegrity"]=1,["ReportPakVerify"]=1,["ReportBootVerify"]=1,["ReportStartupCheck"]=1,["ReportProcessCheck"]=1,["ReportEncryptionCheck"]=1,["ReportBytecode"]=1}
        nu.SendPacket = function(name, ...) if blk[name] then return nil end return orig(name, ...) end
        nu._BypassActive = true
    end
    if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
    local rpts = {"ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportMisKillByTeammate","ReportForbitPick","ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportParachuteData","SendTssSdkAntiDataToLobby","ReportEquipmentFlow","ReportAimFlow","ReportPlayersPing","ReportPlayerIP","ReportPlayerFramePingRecord","ReportDSNetSaturation","ReportNetContinuousSaturate","ReportDSNetRate","ReportCircleFlow","ClientSecMrpcsFlow","SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams","OnShutdownAfterError","OnPlayerActorChannelError","OnPlayerRPCValidateFailed","OnDSPlayerStateChanged","ReportHitRecord","ReportShootData","ReportDamageRecord","ReportKillRecord","ReportWalkRecord","ReportSpeedCheck","ReportWallCheck","ReportMemoryCheck","ReportFileCheck","ReportHookCheck","ReportModuleScan","ReportRootDetect","ReportEmulatorDetect","ReportDebugDetect","ReportInjection","ReportTamper","ReportLuaIntegrity","ReportAssetVerify","ReportPakVerify","ReportBootVerify","ReportStartupCheck","ReportProcessCheck","ReportEncryptionCheck","ReportBytecode"}
    for _, f in ipairs(rpts) do _G.GameplayCallbacks[f] = nop end
    _G.GameplayCallbacks.CheckReportSecAttackFlowWithAttackFlow = retFalse
    _G.GameplayCallbacks.CheckReportSecAttackFlow = retFalse
    pcall(function() local t = package.loaded["TssSdk"] or _G.TssSdk; if t then t.SendReportInfo = nop; t.ScanMemory = retTrue; t.IsEmulator = retFalse; t.CheckEnvironment = retTrue; t.VerifyProcess = retTrue; t.Init = retTrue; t.GetFileMD5 = retMD5; t.VerifyFileSignature = retTrue; t.CheckRoot = retFalse; t.CheckDebugger = retFalse; t.CheckHook = retFalse; t.CheckInjection = retFalse; t.CheckTamper = retFalse; t.CheckVirtual = retFalse; t.ReportAntiData = nop; t.SendAntiData = nop; t.ScanProcess = retTrue; t.ScanModules = retEmpty; t.ScanFiles = retEmpty end end)
    pcall(function() local console = import("KismetSystemLibrary"); if console then local cmd = console.ExecuteConsoleCommand; if cmd then cmd(nil, "pak.DisablePakSignatureCheck 1"); cmd(nil, "pakchunk.EnableSignatureCheck 0"); cmd(nil, "s.VerifyPak 0"); cmd(nil, "sig.Check 0"); cmd(nil, "AntiCheat.Disable 1"); cmd(nil, "TssSdk.Disable 1"); cmd(nil, "Higgs.Disable 1") end end; local CMode = import("CreativeModeBlueprintLibrary"); if CMode then CMode.MD5HashByteArray = retMD5; CMode.MD5HashFile = retMD5; CMode.GetContentDiffData = function() return true, "BYPASSED" end; CMode.VerifyFileIntegrity = retTrue end end)
    pcall(function() local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]; if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end; local AvatarUtils = package.loaded["AvatarUtils"]; if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end end)
    pcall(function() local SMTD = import("ScreenshotMTDer"); if SMTD then SMTD.MTDePicture = retEmptyStr; SMTD.ReMTDePicture = retEmptyStr; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end; local TLog = package.loaded["TLog"] or _G.TLog; if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop end end)
    pcall(function() local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"); if Higgs then for _, m in ipairs({"ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck","StartAvatarCheck","ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord","ShowSecurityAlert","ServerReportAvatar","ClientReportNetAvatar","SendHisarData"}) do if Higgs[m] then Higgs[m] = nop end end; Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false end end)
    if _G.GameplayCallbacks then _G.GameplayCallbacks.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param) local s = string.lower(tostring(State or "")); local blocked = {"cheatdetected","banned","kicked","suspended","violationdetected","integrityfailure","securityviolation","permanentban","temporaryban","10yearban","1dayban"}; for _, bs in ipairs(blocked) do if s:find(bs, 1, true) then return end end end end
    print("[" .. BRAND .. " BYPASS] active")
end)

-- MENU
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true
    local _FakeText = { [999000] = "◆ TESLA 10X GAMING VIP ◆", [999001] = "ESP", [999002] = "GRAPHICS", [999003] = "COMBAT" }
    for _, lp in ipairs({"client.common.LocUtil","client.slua.logic.common.LocUtil","common.LocUtil","common.loc_util"}) do
        pcall(function() local m = package.loaded[lp] or require(lp); if m and not m._10XHooked then for _, fn in ipairs({"GetLocalizeResStr","GetText","GetTextByID","GetLocalText","GetLocalizeStr"}) do if m[fn] and type(m[fn]) == "function" then local orig = m[fn]; m[fn] = function(id, ...) if _FakeText[id] then return _FakeText[id] end return orig(id, ...) end end end; m._10XHooked = true end end)
    end
    local SPD = require("client.logic.NewSetting.SettingPageDefine")
    local SC = require("client.logic.NewSetting.SettingCatalog")
    if not SPD.ModMenu then
        local AM = require("client.slua.umg.NewSetting.Item.AliasMap")
        local StackESP = {
            { Key="M_ESP", UI=AM.TitleSwitcher, Text="ESP MASTER", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.EspLoai9 end, SetFunc=function(c,v) _G.LexusConfig.EspLoai9=v return true end },
            { Key="M_B", UI=AM.Switcher, Text="   Enemy Box", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.Esp9_Box end, SetFunc=function(c,v) _G.LexusConfig.Esp9_Box=v return true end },
            { Key="M_WH", UI=AM.Switcher, Text="   Wallhack (Green=Vis / Red=Behind)", ExpandHandle="M_ESP", GetFunc=function() return _G.LexusConfig.WallhackV2 end, SetFunc=function(c,v) _G.LexusConfig.WallhackV2=v return true end },
            { Key="M_GL", UI=AM.TitleSwitcher, Text="GLOWING BODY (Chams)", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.GlowBody end, SetFunc=function(c,v) _G.LexusConfig.GlowBody=v return true end },
            { Key="M_GLC", UI=AM.Slider, Text="   Glow Color (1-6)", ExpandHandle="M_GL", MinValue=1, MaxValue=6, GetFunc=function() return _G.LexusConfig.GlowColor or 5 end, SetFunc=function(c,v) _G.LexusConfig.GlowColor = v return true end },
            { Key="M_GLT", UI=AM.Slider, Text="   Glow Thickness", ExpandHandle="M_GL", MinValue=5, MaxValue=50, GetFunc=function() return _G.LexusConfig.GlowThickness or 15 end, SetFunc=function(c,v) _G.LexusConfig.GlowThickness = v return true end },
        }
        local StackCombat = {
            { Key="M_AA", UI=AM.Switcher, Text="AIM ASSIST (native)", GetFunc=function() return _G.LexusConfig.AimAssist end, SetFunc=function(c,v) _G.LexusConfig.AimAssist=v return true end },
            { Key="M_HS", UI=AM.Switcher, Text="HEADSHOT (BigHead)", GetFunc=function() return _G.LexusConfig.Headshot end, SetFunc=function(c,v) _G.LexusConfig.Headshot=v return true end },
            { Key="M_HW", UI=AM.Switcher, Text="Fake HWID", GetFunc=function() return _G.LexusConfig.FakeHWID end, SetFunc=function(c,v) _G.LexusConfig.FakeHWID=v return true end },
        }
        local StackGraphics = {
            { Key="M_IP", UI=AM.TitleSwitcher, Text="I PAD VIEW", ExpandIndex=0, GetFunc=function() return _G.LexusConfig.IpadView end, SetFunc=function(c,v) _G.LexusConfig.IpadView=v return true end },
            { Key="M_IPFOV", UI=AM.Slider, Text="   FOV", ExpandHandle="M_IP", MinValue=1, MaxValue=100, GetFunc=function() return (_G.LexusState.CustomTextData.IpadFOV or 120) - 90 end, SetFunc=function(c,v) _G.LexusState.CustomTextData.IpadFOV = 90 + v return true end },
        }
        SPD.ModMenu = { Key = "ModMenu", Text = 999000, UIKey = "Setting_Page_Privacy", Category = {
            { Key="Cat_ESP", Text=999001, Stack=StackESP },
            { Key="Cat_Combat", Text=999003, Stack=StackCombat },
            { Key="Cat_Graphics", Text=999002, Stack=StackGraphics },
        }}
        table.insert(SC, 1, SPD.ModMenu)
    end
    local UIMgr = _G.UIManager
    if UIMgr and not UIMgr._IsModMenuHooked then
        local old = UIMgr.ShowUI
        UIMgr.ShowUI = function(cfg, ...)
            local args = {...}; local n = select('#', ...)
            if cfg and cfg.keyName then local lk = string.lower(cfg.keyName); if string.find(lk, "setting_main") and not string.find(lk, "custom") then local cat = args[1]; if type(cat) == "table" and cat[1] and type(cat[1]) == "table" and cat[1].Key then local has = false; for _, p in ipairs(cat) do if type(p) == "table" and p.Key == "ModMenu" then has = true break end end; if not has then table.insert(cat, 1, SPD.ModMenu) end end end end
            local unpack = table.unpack or unpack
            return old(cfg, unpack(args, 1, n))
        end
        UIMgr._IsModMenuHooked = true
    end
end

-- ====================================================================
-- ESP BOX ONLY
-- ====================================================================
local ESPCanvas = nil

local function InitESPCanvas()
    if ESPCanvas and Game:IsValid(ESPCanvas) then return true end
    local InGameUITools = nil
    pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    if not InGameUITools then return false end
    local MainUI = nil
    pcall(function() MainUI = InGameUITools.GetMainControlBaseUI() end)
    if not MainUI or not Game:IsValid(MainUI) then return false end
    if MainUI.CanvasPanel_0 and Game:IsValid(MainUI.CanvasPanel_0) then ESPCanvas = MainUI.CanvasPanel_0 return true end
    if MainUI.CanvasPanel_42 and Game:IsValid(MainUI.CanvasPanel_42) then ESPCanvas = MainUI.CanvasPanel_42 return true end
    return false
end

local function UpdateESPBox()
    if not _G.LexusConfig.EspLoai9 or not _G.LexusConfig.Esp9_Box then return end
    local gd = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
    local lp = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
    if not Valid(lp) then return end
    local myTeam = lp.TeamID or 0
    local pawns = {}
    if gd.GetAllPlayerCharacters then pawns = gd.GetAllPlayerCharacters() or {}
    elseif gd.GameCharacters then for _, c in pairs(gd.GameCharacters) do table.insert(pawns, c) end end
    for _, p in pairs(pawns) do
        if Valid(p) and p ~= lp and (p.TeamID or 0) ~= myTeam and (p.Health or 0) > 0 then
            pcall(function()
                if p.Replay_IsEnemyFrameUIExisted and not p:Replay_IsEnemyFrameUIExisted() then
                    p:Replay_CreateEnemyFrameUI(true, true)
                end
                if p.Replay_SetVisiableOfFrameUI then p:Replay_SetVisiableOfFrameUI(true) end
            end)
        end
    end
end

-- ====================================================================
-- WALLHACK + GLOWING BODY (pose-aware)
-- ====================================================================
local WH_READY = false
local WH_RUNNING = false
local WH_STOPPED = false
local WH_PROCESSED = {}
local WH_TICK = 0
local WH_TMR = nil
local WH_INTERVAL = 0.15           -- faster tick
local WH_MAX = 25
local WH_RESET_EVERY = 4           -- hard cache wipe every 0.6s
local WH_SLOTS = {0,1,2,3,4,5,6,7}

local LC = import("LinearColor")
local WH_VIS  = LC and LC(0, 255, 0, 255) or {R=0,G=255,B=0,A=255}
local WH_OCC  = LC and LC(255, 0, 0, 255) or {R=255,G=0,B=0,A=255}
local WH_BVIS = LC and LC(0, 180, 0, 200) or {R=0,G=180,B=0,A=200}
local WH_BOCC = LC and LC(180, 0, 0, 200) or {R=180,G=0,B=0,A=200}

local function GlowColor()
    local mode = _G.LexusConfig.GlowColor or 5
    local inten = 100.0
    if mode == 1 then return LC and LC(inten, 0, 0, 1) or {R=255,G=0,B=0,A=255}
    elseif mode == 2 then return LC and LC(0, inten, 0, 1) or {R=0,G=255,B=0,A=255}
    elseif mode == 3 then return LC and LC(0, 0, inten, 1) or {R=0,G=0,B=255,A=255}
    elseif mode == 4 then return LC and LC(inten, inten, 0, 1) or {R=255,G=255,B=0,A=255}
    elseif mode == 6 then return LC and LC(inten, 0, inten, 1) or {R=255,G=0,B=255,A=255}
    else
        local t = os.clock() * 2.0
        local r = (math.sin(t) + 1) / 2 * inten
        local g = (math.sin(t + 2) + 1) / 2 * inten
        local b = (math.sin(t + 4) + 1) / 2 * inten
        return LC and LC(r, g, b, 1) or {R=r, G=g, B=b, A=255}
    end
end

-- Pose key — detect stand/crouch/prone
local function GetPoseKey(pawn)
    local pose = 0
    pcall(function()
        if pawn.PoseState ~= nil then
            local p = tonumber(pawn.PoseState)
            if p ~= nil then pose = p end
        end
        if pawn.bIsCrouched == true then pose = 1 end
        if pawn.bIsProning == true or pawn.bIsProne == true then pose = 2 end
        if type(pawn.IsProne) == "function" then
            local ok, v = pcall(function() return pawn:IsProne() end)
            if ok and v then pose = 2 end
        end
        if type(pawn.IsCrouched) == "function" then
            local ok, v = pcall(function() return pawn:IsCrouched() end)
            if ok and v and pose < 2 then pose = 1 end
        end
    end)
    return pose
end

local function WH_SetupConsole()
    if WH_READY then return end
    pcall(function()
        local KSL = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KSL or not world then return end
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        WH_READY = true
    end)
end

local function WH_ApplyMesh(mesh, vc, oc, glow, glowThick)
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
        if glow then
            mesh:OverrideIdeaOutlineColor(glow)
            mesh:SetIdeaOutlineOcclusionColor(glow)
            mesh:OverrideIdeaOutlineThickness(glowThick or 15)
        else
            mesh:OverrideIdeaOutlineColor(vc)
            mesh:SetIdeaOutlineOcclusionColor(oc)
            mesh:OverrideIdeaOutlineThickness(20.0)
        end
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
        -- Force engine to refresh render state (fixes pose-stale outlines)
        if type(mesh.MarkRenderStateDirty) == "function" then
            mesh:MarkRenderStateDirty()
        end
    end)
end

local function WH_UndoMesh(mesh)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetDrawHighlight(false)
        mesh:SetDrawIdeaOutline(false)
        mesh:SetRenderCustomDepth(false)
        if type(mesh.MarkRenderStateDirty) == "function" then
            mesh:MarkRenderStateDirty()
        end
    end)
end

local function WH_TickFn()
    if WH_STOPPED then return end
    local whOn = _G.LexusConfig.WallhackV2
    local glowOn = _G.LexusConfig.GlowBody
    if not whOn and not glowOn then
        pcall(function()
            local allPawns = Game:GetAllPlayerPawns() or {}
            for _, pawn in pairs(allPawns) do
                if slua.isValid(pawn) and slua.isValid(pawn.Mesh) then WH_UndoMesh(pawn.Mesh) end
            end
        end)
        WH_PROCESSED = {}; WH_TICK = 0; WH_READY = false
        return
    end
    pcall(function()
        local gd = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
        local lp = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
        if not Valid(lp) then return end
        WH_SetupConsole()
        WH_TICK = WH_TICK + 1
        -- hard cache wipe periodically (catches stragglers)
        if WH_TICK % WH_RESET_EVERY == 0 then WH_PROCESSED = {} end
        local myTeam = lp.TeamID or 0
        local pawns = {}
        if gd.GetAllPlayerCharacters then pawns = gd.GetAllPlayerCharacters() or {}
        elseif gd.GameCharacters then for _, c in pairs(gd.GameCharacters) do table.insert(pawns, c) end end
        local n = 0
        for _, pawn in pairs(pawns) do
            if n >= WH_MAX then break end
            if Valid(pawn) and pawn ~= lp then
                local pid = tostring(pawn.PlayerKey or pawn)
                local poseKey = GetPoseKey(pawn)
                -- cache key includes pose — pose change forces re-apply
                local cacheKey = pid .. "_p" .. tostring(poseKey)
                if not WH_PROCESSED[cacheKey] then
                    if (pawn.TeamID or 0) ~= myTeam and (pawn.Health or 100) > 0 then
                        local isAI = false
                        pcall(function() if Game and Game.IsAI then isAI = Game:IsAI(pawn) end end)
                        local vc = isAI and WH_BVIS or WH_VIS
                        local oc = isAI and WH_BOCC or WH_OCC
                        local glow = glowOn and GlowColor() or nil
                        local glowThick = _G.LexusConfig.GlowThickness or 15
                        pcall(function()
                            if slua.isValid(pawn.Mesh) then WH_ApplyMesh(pawn.Mesh, vc, oc, glow, glowThick) end
                            local av = pawn.CharacterAvatarComp2_BP
                            if not av and type(pawn.getAvatarComponent2) == "function" then av = pawn:getAvatarComponent2() end
                            if av and av.GetMeshCompBySlot then
                                for _, s in ipairs(WH_SLOTS) do
                                    local m = av:GetMeshCompBySlot(s)
                                    if m and slua.isValid(m) then WH_ApplyMesh(m, vc, oc, glow, glowThick) end
                                end
                            end
                            pcall(function()
                                local SkeletalMeshComponent = import("SkeletalMeshComponent")
                                if SkeletalMeshComponent then
                                    local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                                    if skComps then
                                        for i = 0, skComps:Num() - 1 do
                                            local comp = skComps:Get(i)
                                            if slua.isValid(comp) and comp ~= pawn.Mesh then WH_ApplyMesh(comp, vc, oc, glow, glowThick) end
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
                                            if slua.isValid(comp) then WH_ApplyMesh(comp, vc, oc, glow, glowThick) end
                                        end
                                    end
                                end
                            end)
                            local w = type(pawn.GetCurrentWeapon) == "function" and pawn:GetCurrentWeapon()
                            if slua.isValid(w) and slua.isValid(w.Mesh) then WH_ApplyMesh(w.Mesh, vc, oc, glow, glowThick) end
                        end)
                        WH_PROCESSED[cacheKey] = true
                        n = n + 1
                    end
                end
            end
        end
    end)
end

local function WH_Start()
    if WH_RUNNING then return end
    WH_RUNNING = true
    WH_STOPPED = false
    WH_SetupConsole()
    if WH_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TMR) end end); WH_TMR = nil end
    if _G.Game and type(_G.Game.AddGameTimer) == "function" then
        WH_TMR = _G.Game:AddGameTimer(WH_INTERVAL, true, WH_TickFn)
        return
    end
    local ok, tk = pcall(require, "common.time_ticker")
    if ok and tk and tk.AddTimerOnce then
        local function loop()
            if WH_STOPPED then return end
            WH_TickFn()
            if (WH_RUNNING) then tk.AddTimerOnce(WH_INTERVAL, loop) end
        end
        tk.AddTimerOnce(WH_INTERVAL, loop)
    end
end

local function WH_Stop()
    WH_RUNNING = false
    WH_STOPPED = true
    if WH_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TMR) end end); WH_TMR = nil end
    WH_PROCESSED = {}; WH_TICK = 0; WH_READY = false
end

-- ====================================================================
-- AIM ASSIST
-- ====================================================================
local AIM_SPEED = 11
local AIM_RANGE = 800
local _lastAimApply = 0

local function ApplyAimAssist()
    if not _G.LexusConfig.AimAssist then return end
    local now = os.clock()
    if now - _lastAimApply < 0.5 then return end
    _lastAimApply = now
    pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
        local lp = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
        if not Valid(lp) then return end
        local wm = lp.WeaponManagerComponent
        if not slua.isValid(wm) then return end
        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end
        local entity = weapon.ShootWeaponEntityComp
        if not slua.isValid(entity) then return end
        if not entity.AutoAimingConfig then return end
        for _, rangeName in ipairs({"OuterRange", "InnerRange"}) do
            local cfg = entity.AutoAimingConfig[rangeName]
            if cfg then
                cfg.Speed = AIM_SPEED
                cfg.adsorbMaxRange = AIM_RANGE
                cfg.adsorbMinRange = AIM_RANGE
            end
        end
    end)
end

-- ==================== iPAD / HWID ====================
local function ApplyIpadView()
    pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
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

local function HWID_SpoofTick()
    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            _G.Original_GetDeviceId = SystemLib.GetDeviceId
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then local chars = "0123456789abcdef"; local hwid = ""; for i = 1, 32 do hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) end; _G.FakeHWID_String = hwid end
                    return _G.FakeHWID_String
                end
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
        end
    end)
end

-- ==================== MAIN TICKS ====================
local _heavyFrame = 0

local function HeavyTick()
    _heavyFrame = _heavyFrame + 1

    if _G.LexusConfig.EspLoai9 and _G.LexusConfig.Esp9_Box then
        if InitESPCanvas() then pcall(UpdateESPBox) end
    end

    if (_G.LexusConfig.WallhackV2 or _G.LexusConfig.GlowBody) and not WH_RUNNING then
        pcall(WH_Start)
    elseif (not _G.LexusConfig.WallhackV2 and not _G.LexusConfig.GlowBody) and WH_RUNNING then
        pcall(WH_Stop)
    end

    pcall(ApplyAimAssist)
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
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(0.2, HeavyTick) end
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
║         VIP LUA 6.1          ║
║      ━━━━━━━━━━━━━━━━         ║
║   ✓ WALLHACK (Pose-Aware)     ║
║   ✓ GLOWING BODY (Chams)      ║
║   ✓ Enemy Box                 ║
║   ✓ AIM ASSIST (native)       ║
║   ✓ IPAD VIEW                 ║
║   ✓ BYPASS 20-LAYER           ║
║   ━━━━━━━━━━━━━━━━            ║
║   Dev: @OFFICIALOWNER10X      ║
╚═══════════════════════════════╝]]
        Msg.Show(1, "◆ TESLA 10X ◆ VIP 6.1", content, function() Notify("VIP MENU ADDED! SETTINGS → PRIVACY") end, function() end, "OK", "")
    end)
end

-- ==================== START ====================
InitModMenuTab()
_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
pcall(function()
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then
        t.AddTimerOnce(0.5, HeavyTick)
        t.AddTimerOnce(3.0, function() pcall(ShowLexusVIPMenu) end)
    else
        if Game and Game.AddGameTimer then
            Game:AddGameTimer(0.2, true, HeavyTick)
            Game:AddGameTimer(3.0, false, ShowLexusVIPMenu)
        end
    end
end)
Notify("◆ TESLA 10X 6.1 LOADED ◆")

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
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.Gameplay.Feature.ParachuteFormationFeature" },
  { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
}, "BRPlayerCharacterBase")