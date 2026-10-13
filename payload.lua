-- ====================================================================
-- BRPlayerCharacterBase.lua — TESLA 10X 7.0 (CLEAN)
-- Only WH2 Wallhack (from payloadnoob.lua) + iPad + HWID + Bypass
-- ESP Box / Aimbot / Skin / Magic Bullet — all removed
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
local BRAND = "TESLA 10X 7.0"
local _slua = rawget(_G, "slua")
local function Valid(o) if o == nil then return false end; if _slua and _slua.isValid then local ok, v = pcall(_slua.isValid, o); return ok and v end; return true end

local function Notify(msg)
    pcall(function() local Msg = require("client.slua.logic.common.logic_common_msg_box"); if Msg and Msg.Show then Msg.Show(1, "◆ " .. BRAND .. " ◆", tostring(msg), function() end, function() end, "OK", "") return end end)
    pcall(function() local sh = import("ScriptHelperClient"); if sh and sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage("[" .. BRAND .. "]" .. tostring(msg), -1, 3.0, {R=1,G=0.85,B=0,A=1}, {X=1.2, Y=1.2}) end end)
    print("[" .. BRAND .. "] " .. tostring(msg))
end
_G.LexusNotify = Notify

_G.LexusConfig = _G.LexusConfig or {
    WallhackV2 = true,
    IpadView = false,
    FakeHWID = false,
}
_G.LexusState = _G.LexusState or { LoopToken = 0, CustomTextData = { IpadFOV = 120 } }

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

-- MENU (only wallhack + graphics)
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true
    local _FakeText = { [999000] = "◆ TESLA 10X 7.0 ◆", [999002] = "GRAPHICS" }
    for _, lp in ipairs({"client.common.LocUtil","client.slua.logic.common.LocUtil","common.LocUtil","common.loc_util"}) do
        pcall(function() local m = package.loaded[lp] or require(lp); if m and not m._10XHooked then for _, fn in ipairs({"GetLocalizeResStr","GetText","GetTextByID","GetLocalText","GetLocalizeStr"}) do if m[fn] and type(m[fn]) == "function" then local orig = m[fn]; m[fn] = function(id, ...) if _FakeText[id] then return _FakeText[id] end return orig(id, ...) end end end; m._10XHooked = true end end)
    end
    local SPD = require("client.logic.NewSetting.SettingPageDefine")
    local SC = require("client.logic.NewSetting.SettingCatalog")
    if not SPD.ModMenu then
        local AM = require("client.slua.umg.NewSetting.Item.AliasMap")
        local StackMain = {
            { Key="M_WH", UI=AM.Switcher, Text="WALLHACK V2 (Full Mesh)", GetFunc=function() return _G.LexusConfig.WallhackV2 end, SetFunc=function(c,v) _G.LexusConfig.WallhackV2=v return true end },
            { Key="M_IP", UI=AM.Switcher, Text="iPad View", GetFunc=function() return _G.LexusConfig.IpadView end, SetFunc=function(c,v) _G.LexusConfig.IpadView=v return true end },
            { Key="M_IPFOV", UI=AM.Slider, Text="   FOV", MinValue=1, MaxValue=100, GetFunc=function() return (_G.LexusState.CustomTextData.IpadFOV or 120) - 90 end, SetFunc=function(c,v) _G.LexusState.CustomTextData.IpadFOV = 90 + v return true end },
            { Key="M_HW", UI=AM.Switcher, Text="Fake HWID", GetFunc=function() return _G.LexusConfig.FakeHWID end, SetFunc=function(c,v) _G.LexusConfig.FakeHWID=v return true end },
        }
        SPD.ModMenu = { Key = "ModMenu", Text = 999000, UIKey = "Setting_Page_Privacy", Category = {
            { Key="Cat_Main", Text=999002, Stack=StackMain },
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
        UIMgr._ModMenuHooked = true
    end
end

-- ====================================================================
-- WALLHACK V2 (from payloadnoob.lua — as-is, full mesh collection)
-- ====================================================================
local LinearColor = import("LinearColor")

local WH_READY   = false
local WH_SEEN    = {}
local WH_TICKS   = 0
local WH_TMR     = nil
local WH_ITV     = 0.3
local WH_SLOTS   = {0,1,2,3,4,5,6,7}

local WH_VIS  = LinearColor and LinearColor(0, 255, 0, 255) or {R=0,G=255,B=0,A=255}
local WH_OCC  = LinearColor and LinearColor(255, 0, 0, 255) or {R=255,G=0,B=0,A=255}
local WH_BVIS = LinearColor and LinearColor(0, 180, 0, 200) or {R=0,G=180,B=0,A=200}
local WH_BOCC = LinearColor and LinearColor(180, 0, 0, 200) or {R=180,G=0,B=0,A=200}

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
        print("[" .. BRAND .. "] Console ready")
    end)
end

local function WH_ApplyMesh(mesh, vc, oc)
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

local function WH_UndoMesh(mesh)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(false)
        mesh:SetDrawHighlight(false)
        mesh:SetDrawIdeaOutline(false)
        mesh:SetRenderCustomDepth(false)
    end)
end

local function WH_Tick()
    if not (_G.LexusConfig and _G.LexusConfig.WallhackV2) then
        if WH_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TMR) end end); WH_TMR = nil end
        WH_SEEN = {}; WH_TICKS = 0; WH_READY = false
        return
    end
    pcall(function()
        local gd = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
        local lp = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
        if not Valid(lp) then return end
        WH_SetupConsole()
        WH_TICKS = WH_TICKS + 1
        if WH_TICKS % 6 == 0 then WH_SEEN = {} end
        local myTeam = lp.TeamID or 0
        local pawns = {}
        if gd.GetAllPlayerCharacters then pawns = gd.GetAllPlayerCharacters() or {}
        elseif gd.GameCharacters then for _,c in pairs(gd.GameCharacters) do table.insert(pawns,c) end end
        local n = 0
        for _, pawn in pairs(pawns) do
            if n >= 20 then break end
            if not Valid(pawn) or pawn == lp then goto wh2c end
            local pid = tostring(pawn.PlayerKey or pawn)
            if WH_SEEN[pid] then goto wh2c end
            if (pawn.TeamID or 0) ~= myTeam and (pawn.Health or 100) > 0 then
                local bot = false
                pcall(function() if pawn.bIsAI or pawn.AIData then bot = true end end)
                local vc = bot and WH_BVIS or WH_VIS
                local oc = bot and WH_BOCC or WH_OCC
                pcall(function()
                    if Valid(pawn.Mesh) then WH_ApplyMesh(pawn.Mesh, vc, oc) end
                    local av = pawn.CharacterAvatarComp2_BP
                    if not av and type(pawn.getAvatarComponent2)=="function" then av=pawn:getAvatarComponent2() end
                    if av and av.GetMeshCompBySlot then
                        for _,s in ipairs(WH_SLOTS) do
                            local m=av:GetMeshCompBySlot(s); if Valid(m) then WH_ApplyMesh(m,vc,oc) end
                        end
                    end
                    local w = type(pawn.GetCurrentWeapon)=="function" and pawn:GetCurrentWeapon()
                    if Valid(w) and Valid(w.Mesh) then WH_ApplyMesh(w.Mesh,vc,oc) end
                end)
                WH_SEEN[pid] = true; n = n + 1
            end
            ::wh2c::
        end
    end)
end

local function WH_Start()
    WH_SetupConsole()
    if WH_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TMR) end end); WH_TMR = nil end
    if _G.Game and type(_G.Game.AddGameTimer)=="function" then
        WH_TMR = _G.Game:AddGameTimer(WH_ITV, true, WH_Tick); return
    end
    local ok, tk = pcall(require, "common.time_ticker")
    if ok and tk and tk.AddTimerOnce then
        local function loop() WH_Tick(); if _G.LexusConfig and _G.LexusConfig.WallhackV2 then tk.AddTimerOnce(WH_ITV, loop) end end
        tk.AddTimerOnce(WH_ITV, loop)
    end
end

local function WH_Stop()
    if WH_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TMR) end end); WH_TMR = nil end
    WH_SEEN = {}; WH_TICKS = 0; WH_READY = false
end

_G.StartWallhackV2 = WH_Start
_G.StopWallhackV2  = WH_Stop

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

-- ==================== MAIN LOOP ====================
local _heavyFrame = 0

local function HeavyTick()
    _heavyFrame = _heavyFrame + 1

    -- Wallhack auto start/stop
    if _G.LexusConfig.WallhackV2 and not WH_TMR then
        pcall(WH_Start)
    elseif not _G.LexusConfig.WallhackV2 and WH_TMR then
        pcall(WH_Stop)
    end

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
║          VIP LUA 7.0          ║
║      ━━━━━━━━━━━━━━━━         ║
║   ✓ WALLHACK V2 (Full Mesh)   ║
║   ✓ IPAD VIEW                 ║
║   ✓ FAKE HWID                 ║
║   ✓ BYPASS 20-LAYER           ║
║   ━━━━━━━━━━━━━━━━            ║
║   Dev: @OFFICIALOWNER10X      ║
╚═══════════════════════════════╝]]
        Msg.Show(1, "◆ TESLA 10X ◆ VIP 7.0", content, function() Notify("VIP MENU ADDED! SETTINGS → PRIVACY") end, function() end, "OK", "")
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
Notify("◆ TESLA 10X 7.0 LOADED ◆")

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