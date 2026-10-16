-- ====================================================================
-- TESLA 10X — Part 1/4
-- Owner: @OfficialOwner10x
-- Channel: TESLA 10X
-- Config: TESLA 10X_settings.txt
-- Build: v3.0 | Bypass: 42 layers FIXED | ESP(RED) + Aimbot + NoRecoil
-- Supports: BGMI, PUBG Global, PUBG TW, PUBG VN, PUBG KR, PUBG IMobile
-- ====================================================================

local BRPlayerCharacterBase = {
  ServerRPC = {}, ClientRPC = {}, MulticastRPC = {}, LuaEventContainer = {}
}
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

-- ====================================================================
-- ORIGINAL CLASS
-- ====================================================================
function BRPlayerCharacterBase:ctor() end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local C = import("CheckFallingDistanceComponent")
    if slua.isValid(C) and not slua.isValid(self:GetComponentByClass(C)) then
      Game:AddComponent(C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then self.STCharacterMovement.bPositiveBlowUp = true end
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
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local PC = self:GetPlayerControllerSafety()
    if slua.isValid(PC) then PC:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  if PawnState == EPawnState.SwitchPP then
    local PC = self:GetPlayerControllerSafety()
    if slua.isValid(PC) then PC:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local M = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(M.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local gt = CGameMode.GameModeType
    local gid = tonumber(CGameState.GameModeID)
    local a = gt == EGameModeType.ETypicalGameMode or gt == EGameModeType.EFourInOneGameMode or gt == EGameModeType.EHeavyWeaponGameMode
    local b = not MatchModeIds[gid]
    return a and b
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(last, new)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, last, new)
  if not Client then
    local PC = self:GetPlayerControllerSafety()
    if slua.isValid(PC) and PC.CheckParachuteOpenFeature then
      if new == EParachuteState.PS_Opening then
        if PC.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then PC.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI() end
      elseif new == EParachuteState.PS_None then
        if PC.CheckParachuteOpenFeature.RecoverParachuteOpenParam then PC.CheckParachuteOpenFeature:RecoverParachuteOpenParam() end
        if PC.CheckParachuteOpenFeature.ClearTimerAndState then PC.CheckParachuteOpenFeature:ClearTimerAndState() end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
  if not Client then
    local PC = self:GetPlayerControllerSafety()
    if slua.isValid(PC) and PC.CheckParachuteOpenFeature then
      if PC.CheckParachuteOpenFeature.ClearTimerAndState then PC.CheckParachuteOpenFeature:ClearTimerAndState() end
      if PC.CheckParachuteOpenFeature.ResetCheckShowUI then PC.CheckParachuteOpenFeature:ResetCheckShowUI() end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(r)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, r)
  if Client then GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local gs = GameplayData:GetGameState()
  if slua.isValid(gs) and Game:IsClassOf(gs, STExtraGameStateBase) then return gs.GameModeType == EGameModeType.EWarGameMode end
  return false
end

function BRPlayerCharacterBase:BPOnRecycled() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:BPOnRespawned() if Client then self:ResetMeshRelativeLocationAndRotation() end end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  if Client then self:ResetMeshRelativeLocationAndRotation(); GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  if Client then self:ResetMeshRelativeLocationAndRotation(); GameplayData.AddCharacter(self.Object) end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local rot = FRotator(0, -90, 0)
    local loc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then self.Mesh:K2_SetRelativeRotation(rot, false, nil, false) end
    self:CacheInitialMeshOffset(loc, rot)
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
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then return end
  local PC = self:GetPlayerControllerSafety()
  if not slua.isValid(PC) then return end
  local AV = self.CharacterAvatarComp2_BP
  if not slua.isValid(AV) then return end
  local U = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local cid = U:ChangeVehicleSkinByClothes(PC, AV)
  local T = import("ESTExtraVehicleShapeType")
  if cid then
    local A = import("AvatarUtils")
    if A.GetVehicleShapeBySkinID(cid) == T.VST_Horse then
      local PS = self:GetPlayerStateSafety()
      if slua.isValid(PS) then PS:AddGeneralCount(468, 1, false) end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local PC = self:GetControllerSafety()
  if slua.isValid(PC) then
    if not self:GetEnsure() then
      if PC:GetCurrentStateType() ~= EStateType.State_ParachuteJump and PC:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        PC:ReInitParachuteItem()
        PC:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(u, n, o)
  if u ~= self.Object then return end
  local MC = self:GetMedievalCraneFromBase(n)
  if MC and MC.AddCharacter then MC:AddCharacter(self.Object)
  else
    MC = self:GetMedievalCraneFromBase(o)
    if MC and MC.RemoveCharacter then MC:RemoveCharacter(self.Object) end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(b)
  if not slua.isValid(b) or not b.GetOwner then return end
  local L = b:GetOwner()
  if not slua.isValid(L) or not L.AddCharacter then return end
  return L
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local PS = self:GetPlayerStateSafety()
  if not slua.isValid(PS) then return false end
  if PS.CanUseFlaregun == false and self:IsLocallyControlled() then
    local PC = self:GetPlayerControllerSafety()
    if slua.isValid(PC) then PC:DisplayGameTipWithMsgID(48532) end
  end
  return not PS.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local C = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(C) and self.bCanNearDeathGiveup == true then
    local PS = self:GetPlayerStateSafety()
    if slua.isValid(PS) then PS:AddGeneralCount(1613, 1, false) end
    C:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(a)
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then self:MulticastRPC_GmPlayAction(a) end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(a)
  if not Client then return end
  local C = self:GetPlayEmoteComponent()
  if not slua.isValid(C) then return end
  local LF = require("common.log_filter"); LF.SetLogTreeEnable(true)
  local cfg = CDataTable.GetTableData("EmoteBPTable", a)
  if not cfg then return end
  local path = cfg.Path
  local H = slua.loadObject(path)
  local arr = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local h = H()
  C:OnLoadEmoteAssetBegin(h, a, arr, "")
  local tb = FuncUtil.LuaArrayToTable(arr)
  local au = require("common.asset_util")
  function loadLater() C:OnLoadEmoteAssetEnd(h, a, 0) end
  au.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(b)
  if slua.isValid(self.ParachuteComponent) then self.ParachuteComponent.bServerSyncShouldCheckPassWall = b end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(b)
  self.Super:OnPlayerLeaveCarryBoxState(b)
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(b) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(u)
  if slua.isValid(u) and Game:IsClassOf(u, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(u)
  end
end

function BRPlayerCharacterBase:SetAreaID(a) self:SetAttrValue("AreaID", a, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end

function BRPlayerCharacterBase:DoModChangeToBT()
  if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then self.ParachuteFormation:OnLandingClearFormationCamera() end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, Ig)
  if self:HasState(EPawnState.AttachToOther) then
    local W = self:GetWeaponBySlot(Slot)
    if slua.isValid(W) then
      local wid = W:GetWeaponID()
      local cfg = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if cfg and cfg.CheckIsWeaponInBlackList and cfg.CheckIsWeaponInBlackList(wid) then
        local PC = self:GetPlayerControllerSafety()
        if Client and slua.isValid(PC) and PC.Role == ENetRole.ROLE_AutonomousProxy then PC:DisplayGameTipWithMsgID(47306) end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local O = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(O) then
      local s = O:GetCurMoveState()
      if s == ESpiderSwingMoveState.Launching or s == ESpiderSwingMoveState.Swinging then return false end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, Ig)
end

-- ====================================================================
-- CORE HELPERS
-- ====================================================================
local _slua = rawget(_G, "slua")

_G.Safe = function(tag, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    pcall(function() print("[TESLA10X][ERR][" .. tostring(tag) .. "] " .. tostring(err)) end)
  end
  return ok
end

_G.ModuleCache = _G.ModuleCache or {}
_G.GetModule = function(path)
  local c = _G.ModuleCache[path]
  if c ~= nil then return c or nil end
  local ok, mod = pcall(require, path)
  _G.ModuleCache[path] = ok and mod or false
  return ok and mod or nil
end

_G.FrameDelta = _G.FrameDelta or { Last = 0, Delta = 0.016, ClampedDelta = 0.016 }
_G.TickFrame = function()
  local now = os.clock()
  local d = now - (_G.FrameDelta.Last or now)
  if d <= 0 or d > 1.0 then d = 0.016 end
  _G.FrameDelta.Last = now
  _G.FrameDelta.Delta = d
  _G.FrameDelta.ClampedDelta = math.min(d, 0.05)
end
_G.UpdateFrameDelta = _G.TickFrame

_G.Lerp = function(a, b, t) t = math.max(0, math.min(1, t)); return a + (b - a) * t end
_G.LerpSmooth = function(a, b, speed, dt) return a + (b - a) * (1 - math.exp(-speed * dt)) end

_G.atan2 = function(y, x)
  if x > 0 then return math.atan(y/x) end
  if x < 0 then return math.atan(y/x) + (y >= 0 and math.pi or -math.pi) end
  if y > 0 then return math.pi/2 end
  if y < 0 then return -math.pi/2 end
  return 0
end

local function Notify(msg)
  local s = "[TESLA 10X] " .. tostring(msg)
  pcall(function() print(s) end)
  pcall(function()
    local sh = import("ScriptHelperClient")
    if sh and sh.AddOnScreenDebugMessage then
      sh.AddOnScreenDebugMessage(s, -1, 4.0, {R=1, G=0.85, B=0, A=1}, {X=1.2, Y=1.2})
    end
  end)
end
_G.Notify = Notify

local function Valid(o)
  if not o then return false end
  if _slua and _slua.isValid then
    local ok, v = pcall(_slua.isValid, o)
    if not ok or not v then return false end
  end
  return true
end
_G.Valid = Valid

-- ====================================================================
-- COLORS (RED THEME FOR ESP)
-- ====================================================================
_G.C_GREEN      = {R=0, G=255, B=0, A=255}      -- snapline/skeleton green
_G.C_RED        = {R=255, G=30, B=30, A=255}    -- ESP TEXT RED (new)
_G.C_RED_DEEP   = {R=180, G=20, B=20, A=255}    -- deep red accents
_G.C_RED_TEXT   = {R=255, G=40, B=40, A=255}    -- name + distance red
_G.C_RED_HP     = {R=255, G=25, B=25, A=255}    -- HP fill red
_G.C_RED_BG     = {R=40, G=4, B=4, A=255}       -- HP bg dark red tint
_G.C_CYAN       = {R=0, G=255, B=255, A=255}
_G.C_YELLOW     = {R=255, G=255, B=0, A=255}
_G.C_WHITE      = {R=255, G=255, B=255, A=255}
_G.C_BLUE_TEXT  = {R=0, G=200, B=255, A=255}
_G.C_GOLD       = {R=255, G=217, B=0, A=255}

_G.GLOBAL_BONE_LIST = {
  "head", "neck_01", "pelvis",
  "upperarm_r", "lowerarm_r", "hand_r",
  "upperarm_l", "lowerarm_l", "hand_l",
  "thigh_l", "calf_l", "foot_l",
  "thigh_r", "calf_r", "foot_r"
}

-- ====================================================================
-- CONFIG (all features default OFF)
-- ====================================================================
_G.LexusConfig = _G.LexusConfig or {
  FakeHWID = false,

  -- ESP
  EspLoai9 = false,
  Esp9_Count = false, Esp9_Name = false, Esp9_HP = false, Esp9_Team = false,
  Esp9_Weapon = false, Esp9_Distance = false, Esp9_Line = false, Esp9_Skeleton = false,
  EspAntenna = false, EspDistance = false, EspVipPro = false,

  -- Wallhack (chams only, no outline)
  ColorBodyNew = false,

  -- Combat
  NoRecoilEnabled = false,
  RecoilReduction = 100,
  AimbotEnabled = false,
  WeaponAimbot = false,
  AutoHead = false,
  EspInfo = false,
  EspInfo_Weapon = true,
  EspInfo_Pose = true,

  KillMessage = false,

  -- Visuals
  IpadView = false,
  IpadViewFOV = 120,
  UnlockFPS = false,
  FPSLimit = 165,           -- slider range 30-265

  Crosshair = false,
  CrosshairStyle = 1,
  CrosshairSize = 4,
  CrosshairColor = 2,
}

_G.LexusState = _G.LexusState or {
  LoopToken = 0, NativeESPReady = false, MenuStep = 0,
  EnemyMarks = {}, CustomTextData = nil,
  LastConfigHash = "", DirtySave = false, LastSaveTime = 0,
  FeatureStates = {},
}

-- ====================================================================
-- BYPASS — 42 LAYERS (FIXED)
-- ====================================================================
local function _nop() return true end
local function _retFalse() return false end
local function _retTrue() return true end
local function _retZero() return 0 end
local function _retEmpty() return {} end
local function _retNil() return nil end
local function _retEmptyStr() return "" end

_G.BypassLog = {}

-- ====================================================================
-- EXTRA BYPASS — 6 STRONG LAYERS (from bypass.lua)
-- Safe, tested, non-conflicting with existing 31L
-- ====================================================================
_G.ExtraBypassLog = {}

_G.InitializeExtraBypass = function()
  _G.ExtraBypassLog = {}

  local function extLog(name)
    table.insert(_G.ExtraBypassLog, name)
  end

  -- ============================================================
  -- EB1: SLUA signature bypass
  -- ============================================================
  _G.Safe("eb_slua", function()
    if slua and slua.getSignature then
      slua.getSignature = function() return 0xDEADBEEF end
    end
    local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
    if loader then
      loader.verifyBytecode = _retTrue
      loader.checkIntegrity = _retTrue
      if loader.disableSignatureCheck then loader.disableSignatureCheck = _retTrue end
    end
    local slua_serialize = package.loaded["slua.serialize"]
    if slua_serialize then
      slua_serialize.check = _retTrue
      slua_serialize.verify = _retTrue
    end
    if jit and jit.attach then
      pcall(function() jit.attach(function() end, "bc") end)
    end
    if _G.slua_verify then _G.slua_verify = _retTrue end
    if _G.check_slua_integrity then _G.check_slua_integrity = _retTrue end
    extLog("EB1-SLUA-Signature")
  end)

  -- ============================================================
  -- EB2: MD5 + Pak signature bypass
  -- ============================================================
  _G.Safe("eb_md5", function()
    local console = import("KismetSystemLibrary")
    if console then
      local world = slua.getWorld()
      if world then
        pcall(function() console.ExecuteConsoleCommand(world, "pak.DisablePakSignatureCheck 1") end)
        pcall(function() console.ExecuteConsoleCommand(world, "pakchunk.EnableSignatureCheck 0") end)
        pcall(function() console.ExecuteConsoleCommand(world, "s.VerifyPak 0") end)
        pcall(function() console.ExecuteConsoleCommand(world, "sig.Check 0") end)
        pcall(function() console.ExecuteConsoleCommand(world, "security.DisableChecks 1") end)
      end
    end
    local CreativeModeBlueprintLibrary = import("CreativeModeBlueprintLibrary")
    if CreativeModeBlueprintLibrary then
      CreativeModeBlueprintLibrary.MD5HashByteArray = function() return "00000000000000000000000000000000" end
      CreativeModeBlueprintLibrary.MD5HashFile = function() return "00000000000000000000000000000000" end
      CreativeModeBlueprintLibrary.GetContentDiffData = function() return true, "BYPASSED" end
      CreativeModeBlueprintLibrary.VerifyFileIntegrity = _retTrue
    end
    if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
    if _G.CRC32 then _G.CRC32 = function() return 0 end end
    local FileHashChecker = package.loaded["common.file_hash_checker"]
    if FileHashChecker then
      FileHashChecker.CheckFileMD5 = _retTrue
      FileHashChecker.VerifyAll = _retTrue
      FileHashChecker.GetHash = function() return "BYPASS" end
    end
    local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
    if TssSdk then
      TssSdk.GetFileMD5 = function() return "BYPASS" end
      TssSdk.VerifyFileSignature = _retTrue
    end
    local STExtraLib = import("STExtraBlueprintFunctionLibrary")
    if STExtraLib then
      STExtraLib.CheckMD5 = _retTrue
      STExtraLib.GetMD5 = function() return "BYPASS" end
      STExtraLib.VerifyFile = _retTrue
    end
    extLog("EB2-MD5-PakSignature")
  end)

  -- ============================================================
  -- EB3: Report Flow blocker (Attack/Hit/Circle/Kill/Mrpcs)
  -- ============================================================
  _G.Safe("eb_report_flow", function()
    local reportFlows = {
      "ReportAttackFlow", "ReportSecAttackFlow", "ReportHurtFlow", "ReportFireArms",
      "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt",
      "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute",
      "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow",
      "ReportParachuteData", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing",
      "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation",
      "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow",
      "ReportPlayerKillFlow"
    }
    for _, funcName in ipairs(reportFlows) do
      if _G[funcName] then _G[funcName] = _nop end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[funcName] then
        _G.GameplayCallbacks[funcName] = _nop
      end
    end
    local checkFuncs = {"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}
    for _, funcName in ipairs(checkFuncs) do
      if _G[funcName] then _G[funcName] = _retFalse end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[funcName] then
        _G.GameplayCallbacks[funcName] = _retFalse
      end
    end
    local enableFlags = {
      "IsEnableReportPlayerKillFlow", "IsEnableReportMrpcsInCircleFlow",
      "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow",
      "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"
    }
    for _, flag in ipairs(enableFlags) do
      if _G[flag] then _G[flag] = _retFalse end
    end
    extLog("EB3-ReportFlowBlocker")
  end)

  -- ============================================================
  -- EB4: PlayerSecurityInfo collector kill
  -- ============================================================
  _G.Safe("eb_security_collector", function()
    local collectorPaths = {
      "PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector",
      "ClientSecurityCollector", "PlayerAntiCheatCollector"
    }
    for _, collector in ipairs(collectorPaths) do
      if _G[collector] then
        for k, v in pairs(_G[collector]) do
          if type(v) == "function" and (
            k:find("Report") or k:find("Collect") or k:find("Send") or
            k:find("Upload") or k:find("Record")
          ) then
            _G[collector][k] = _nop
          end
        end
      end
    end
    local SecuritySubsystem = package.loaded["GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem"]
    if SecuritySubsystem then
      SecuritySubsystem.ReportData = _nop
      SecuritySubsystem.CheckCheat = _retFalse
      SecuritySubsystem.ValidatePlayer = _retTrue
      SecuritySubsystem.CollectData = _nop
      SecuritySubsystem.SendToServer = _nop
    end
    if _G.PlayerSecurityInfo then
      _G.PlayerSecurityInfo.ReportCheat = _nop
      _G.PlayerSecurityInfo.ReportSuspicious = _nop
      _G.PlayerSecurityInfo.SendSecurityData = _nop
      _G.PlayerSecurityInfo.CollectSecurityInfo = _nop
    end
    extLog("EB4-SecurityCollector")
  end)

  -- ============================================================
  -- EB5: Heartbeat + SwiftHawk blocker
  -- ============================================================
  _G.Safe("eb_heartbeat_swift", function()
    local heartbeatFuncs = {"Heartbeat", "SendHeartbeat", "ClientHeartbeat", "ServerHeartbeat"}
    for _, func in ipairs(heartbeatFuncs) do
      if _G[func] then _G[func] = _nop end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[func] then
        _G.GameplayCallbacks[func] = _nop
      end
    end
    local swiftFuncs = {"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}
    for _, func in ipairs(swiftFuncs) do
      if _G[func] then _G[func] = _nop end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[func] then
        _G.GameplayCallbacks[func] = _nop
      end
    end
    local SwiftHawkSubsystem = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
    if SwiftHawkSubsystem then
      SwiftHawkSubsystem.ReportData = _nop
      SwiftHawkSubsystem.SendReport = _nop
      SwiftHawkSubsystem.CollectTelemetry = _nop
    end
    extLog("EB5-Heartbeat-SwiftHawk")
  end)

  -- ============================================================
  -- EB6: HiggsBoson + AntiCheat bypass
  -- ============================================================
  _G.Safe("eb_higgs_anticheat", function()
    local Higgs = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"]
    if Higgs then
      local methods = {
        "ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck",
        "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord",
        "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData",
        "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes",
        "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive",
        "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"
      }
      for _, m in ipairs(methods) do
        if Higgs[m] then Higgs[m] = _nop end
      end
      Higgs.GetNetAvatarItemIDs = _retEmpty
      Higgs.GetCurWeaponSkinID = _retZero
      Higgs.IsMHActive = _retFalse
      Higgs.bMHActive = false
      Higgs.bCallPreReplication = false
      if Higgs.BlackList then
        for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end
      end
    end
    if _G.BlackList then _G.BlackList = {} end

    local AvatarCheckCallback = _G.AvatarCheckCallback
    if AvatarCheckCallback then
      AvatarCheckCallback.StartAvatarCheck = _nop
      AvatarCheckCallback.OnReportItemID = _nop
    end

    -- Blocked states (DS report)
    if _G.GameplayCallbacks then
      local originalDSPlayerState = _G.GameplayCallbacks.OnDSPlayerStateChanged
      _G.GameplayCallbacks.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
        local stateStr = InPlayerState and string.lower(tostring(InPlayerState)) or ""
        local blockedStates = {
          ["cheatdetected"] = true, ["connectionlost"] = true, ["connectiontimeout"] = true,
          ["connectionexception"] = true, ["netdrivererror"] = true, ["banned"] = true,
          ["kicked"] = true, ["suspended"] = true, ["violationdetected"] = true,
          ["integrityfailure"] = true, ["securityviolation"] = true
        }
        if blockedStates[stateStr] then return end
        if originalDSPlayerState then pcall(originalDSPlayerState, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason) end
      end
      _G.GameplayCallbacks.OnPlayerNetConnectionClosed = _nop
      _G.GameplayCallbacks.OnPlayerActorChannelError = _nop
      _G.GameplayCallbacks.OnPlayerRPCValidateFailed = _nop
      _G.GameplayCallbacks.OnShutdownAfterError = _nop
    end
    extLog("EB6-HiggsBoson-AntiCheat")
  end)

  -- ============================================================
  -- Runtime re-apply (every 3 seconds)
  -- ============================================================
  _G.Safe("eb_runtime_reapply", function()
    local ticker = _G.GetModule("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
      local function ReapplyExtra()
        _G.Safe("eb_reapply_tick", function()
          -- Re-hook HiggsBoson on PC
          local pc = _G.getCachedGameplayData() and _G.getCachedGameplayData().GetPlayerController and _G.getCachedGameplayData().GetPlayerController()
          if Valid(pc) then
            if pc.HiggsBoson then
              pc.HiggsBoson.bMHActive = false
              pc.HiggsBoson.bCallPreReplication = false
            end
            if pc.HiggsBosonComponent then
              pc.HiggsBosonComponent.bMHActive = false
              pc.HiggsBosonComponent.bCallPreReplication = false
            end
          end
        end)
        ticker.AddTimerOnce(3.0, ReapplyExtra)
      end
      ticker.AddTimerOnce(3.0, ReapplyExtra)
    end
    extLog("EB7-RuntimeReapply")
  end)

  Notify("Extra Bypass — " .. #_G.ExtraBypassLog .. " layers added")
end

_G.InitializeBypass = function()
  _G.BypassLog = {}

  _G.Safe("bp_L1", function()
    local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
    if ptlog then
      ptlog.ReportEvent = _nop; ptlog.ReportDownloadResult = _nop; ptlog.ReportODPTDError = _nop
      ptlog.ReportSkinError = _nop; ptlog.ReportError = _nop; ptlog.OnDownloadError = _nop
      ptlog.ReportODPD = _nop; ptlog.ReportPufferError = _nop
      table.insert(_G.BypassLog, "L1-puffer_tlog")
    end
  end)

  _G.Safe("bp_L2", function()
    local AU = package.loaded["AvatarUtils"]
    if AU then
      AU.CheckIsWeaponInBlackList = _retFalse; AU.IsValidAvatar = _retTrue
      AU.CheckAvatarIntegrity = _retTrue; AU.ReportInvalidAvatar = _nop
      AU.CheckSkinValid = _retTrue; AU.ReportSkinMismatch = _nop
      AU.CheckAvatarValid = _retTrue
      table.insert(_G.BypassLog, "L2-AvatarUtils")
    end
  end)

  _G.Safe("bp_L3", function()
    local eq = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
    if eq then
      eq.Report = _nop; eq.SendException = _nop; eq.ReportException = _nop
      eq.OnException = _nop; eq.SendReport = _nop
      table.insert(_G.BypassLog, "L3-EquipmentException")
    end
  end)

  _G.Safe("bp_L4", function()
    local applied = false
    local SsMgr = _G.GetModule("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SsMgr and SsMgr.Get then
      local ok, sub = pcall(function() return SsMgr:Get("FileCheckSubsystem") end)
      if ok and sub then
        sub.StartCheck = _nop; sub.ReportAbnormalFile = _nop; sub.StopCheck = _nop
        sub.CheckFileHash = _nop; sub.VerifyPak = _retTrue; sub.ReportTamper = _nop
        sub.CheckSignature = _retTrue; sub.ValidateFiles = _retTrue
        sub.RunIntegrityCheck = _retTrue; sub.CheckAllFiles = _retTrue
        applied = true
      end
    end
    local fcs = package.loaded["GameLua.GameCore.Module.Subsystem.FileCheckSubsystem"]
    if fcs then
      fcs.StartCheck = _nop; fcs.VerifyPak = _retTrue; fcs.CheckAllFiles = _retTrue
      fcs.ReportAbnormalFile = _nop
      applied = true
    end
    if applied then table.insert(_G.BypassLog, "L4-FileCheck") end
  end)

  _G.Safe("bp_L5to9", function()
    local paths = {
      "client.slua.logic.report.CheatReport", "client.slua.logic.report.ClientReport",
      "client.slua.logic.report.AntiCheatReport", "client.slua.logic.report.PlayerReport",
      "client.slua.logic.report.ReportManager", "client.slua.logic.report.GameReport",
      "client.slua.logic.report.TamperReport",
    }
    for i, p in ipairs(paths) do
      local m = package.loaded[p]
      if m then
        m.Report = _nop; m.SendReport = _nop; m.ReportCheat = _nop; m.ReportPlayer = _nop
        m.ReportTamper = _nop; m.ReportException = _nop; m.Send = _nop
        table.insert(_G.BypassLog, "L" .. (4+i) .. "-" .. p:match("([^%.]+)$"))
      end
    end
  end)

  _G.Safe("bp_L10", function()
    local SL = import("KismetSystemLibrary")
    if SL and not _G.FakeHWID_Hooked then
      local function Gen(n)
        local c = "0123456789ABCDEF"; local s = ""
        for i = 1, n do
          local idx = math.random(1, #c); s = s .. c:sub(idx, idx)
          if i == 8 or i == 12 or i == 16 or i == 20 then s = s .. "-" end
        end
        return s
      end
      _G.Original_GetDeviceId = SL.GetDeviceId
      SL.GetDeviceId = function(...)
        if _G.LexusConfig.FakeHWID then
          if not _G.FakeHWID_String then _G.FakeHWID_String = Gen(32) end
          return _G.FakeHWID_String
        end
        if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
        return "UNKNOWN"
      end
      _G.FakeHWID_Hooked = true
      table.insert(_G.BypassLog, "L10-DeviceId")
    end
  end)

  _G.Safe("bp_L11", function()
    local SL = import("KismetSystemLibrary")
    if SL and SL.GetUniqueID and not _G.FakeUID_Hooked then
      _G.Original_GetUniqueID = SL.GetUniqueID
      SL.GetUniqueID = function(...)
        if _G.LexusConfig.FakeHWID then
          if not _G.FakeUID_String then
            local c = "0123456789ABCDEF"; _G.FakeUID_String = "UID-"
            for i = 1, 16 do local x = math.random(1, #c); _G.FakeUID_String = _G.FakeUID_String .. c:sub(x, x) end
          end
          return _G.FakeUID_String
        end
        return _G.Original_GetUniqueID(...)
      end
      _G.FakeUID_Hooked = true
      table.insert(_G.BypassLog, "L11-UniqueID")
    end
  end)

  _G.Safe("bp_L12", function()
    local SL = import("KismetSystemLibrary")
    if SL and SL.GetMachineId and not _G.FakeMID_Hooked then
      _G.Original_GetMachineId = SL.GetMachineId
      SL.GetMachineId = function(...)
        if _G.LexusConfig.FakeHWID then
          if not _G.FakeMID_String then
            local c = "0123456789ABCDEF"; _G.FakeMID_String = "MID-"
            for i = 1, 20 do local x = math.random(1, #c); _G.FakeMID_String = _G.FakeMID_String .. c:sub(x, x) end
          end
          return _G.FakeMID_String
        end
        return _G.Original_GetMachineId(...)
      end
      _G.FakeMID_Hooked = true
      table.insert(_G.BypassLog, "L12-MachineId")
    end
  end)

  _G.Safe("bp_L13", function()
    local SL = import("KismetSystemLibrary")
    if SL and SL.GetMacAddress and not _G.FakeMAC_Hooked then
      _G.Original_GetMacAddress = SL.GetMacAddress
      SL.GetMacAddress = function(...)
        if _G.LexusConfig.FakeHWID then
          if not _G.FakeMAC_String then
            local c = "0123456789ABCDEF"; _G.FakeMAC_String = ""
            for i = 1, 12 do
              local x = math.random(1, #c); _G.FakeMAC_String = _G.FakeMAC_String .. c:sub(x, x)
              if i % 2 == 0 and i < 12 then _G.FakeMAC_String = _G.FakeMAC_String .. ":" end
            end
          end
          return _G.FakeMAC_String
        end
        return _G.Original_GetMacAddress(...)
      end
      _G.FakeMAC_Hooked = true
      table.insert(_G.BypassLog, "L13-MacAddress")
    end
  end)

  _G.Safe("bp_L14", function()
    local LF = package.loaded["common.log_filter"]
    if LF and LF.SetLogTreeEnable then
      _G.Original_SetLogTreeEnable = LF.SetLogTreeEnable
      LF.SetLogTreeEnable = _nop
      table.insert(_G.BypassLog, "L14-QuietLog")
    end
  end)

  _G.Safe("bp_L15", function()
    if rawget(_G, "ReportError") then rawset(_G, "ReportError", _nop) end
    if rawget(_G, "SendReport") then rawset(_G, "SendReport", _nop) end
    if rawget(_G, "ReportCheat") then rawset(_G, "ReportCheat", _nop) end
    table.insert(_G.BypassLog, "L15-GlobalReport")
  end)

  _G.Safe("bp_L16", function()
    local utils = package.loaded["GameLua.GameCore.Utils.FStringUtils"] or package.loaded["common.fstring_utils"]
    if utils then
      utils.CRC = _retZero; utils.CheckCRC = _retTrue; utils.FStringCRC = _retZero
      table.insert(_G.BypassLog, "L16-CRC")
    end
  end)

  _G.Safe("bp_L17", function()
    local md5 = package.loaded["common.md5"] or package.loaded["utils.md5"]
    if md5 then md5.Check = _retTrue; md5.Verify = _retTrue; table.insert(_G.BypassLog, "L17-MD5") end
  end)

  _G.Safe("bp_L18", function()
    local pak = package.loaded["client.slua.logic.download.pak_integrity"]
    if pak then pak.Check = _retTrue; pak.Verify = _retTrue; pak.Report = _nop; table.insert(_G.BypassLog, "L18-PakIntegrity") end
  end)

  _G.Safe("bp_L19", function()
    local auth = package.loaded["client.slua.logic.auth.ClientAuthorize"]
    if auth then auth.Verify = _retTrue; auth.Check = _retTrue; auth.Report = _nop; table.insert(_G.BypassLog, "L19-ClientAuth") end
  end)

  _G.Safe("bp_L20", function()
    local dt = package.loaded["common.datatable_check"]
    if dt then dt.Check = _retTrue; dt.Verify = _retTrue; table.insert(_G.BypassLog, "L20-DataTable") end
  end)

  _G.Safe("bp_L21", function()
    local ssl = package.loaded["client.slua.network.ssl_verify"]
    if ssl then ssl.Verify = _retTrue; ssl.CheckCert = _retTrue; table.insert(_G.BypassLog, "L21-SSL") end
  end)

  _G.Safe("bp_L22", function()
    local ad = package.loaded["common.anti_debug"]
    if ad then ad.Check = _retFalse; ad.Detect = _retFalse; table.insert(_G.BypassLog, "L22-AntiDebug") end
  end)

  _G.Safe("bp_L23", function()
    local sa = package.loaded["client.slua.logic.auth.ServerAuthSignature"]
    if sa then sa.Verify = _retTrue; sa.Check = _retTrue; table.insert(_G.BypassLog, "L23-ServerAuth") end
  end)

  _G.Safe("bp_L24", function()
    local em = package.loaded["common.emulator_check"]
    if em then em.IsEmulator = _retFalse; em.Check = _retFalse; table.insert(_G.BypassLog, "L24-Emulator") end
  end)

  _G.Safe("bp_L25", function()
    local root = package.loaded["common.root_check"]
    if root then root.IsRooted = _retFalse; root.Check = _retFalse; table.insert(_G.BypassLog, "L25-Root") end
  end)

  _G.Safe("bp_L26", function()
    local vt = package.loaded["common.vtable_check"]
    if vt then vt.Check = _retTrue; vt.Verify = _retTrue; table.insert(_G.BypassLog, "L26-VTable") end
    local uf = package.loaded["client.slua.integrity.ufunction_guard"]
    if uf then uf.Verify = _retTrue; uf.Check = _retTrue; uf.Report = _nop; table.insert(_G.BypassLog, "L26-UFuncGuard") end
  end)

  _G.Safe("bp_L27", function()
    local hs = package.loaded["client.slua.network.handshake_verify"]
    if hs then hs.Verify = _retTrue; hs.Check = _retTrue; hs.Report = _nop; table.insert(_G.BypassLog, "L27-Handshake") end
    local sig = package.loaded["client.slua.network.packet_signature"]
    if sig then sig.Verify = _retTrue; sig.CheckSig = _retTrue; table.insert(_G.BypassLog, "L27-PacketSig") end
  end)

  _G.Safe("bp_L28", function()
    local ms = package.loaded["common.memory_scan"]
    if ms then ms.Scan = _retEmpty; ms.Detect = _retFalse; ms.Report = _nop; table.insert(_G.BypassLog, "L28-MemScan") end
    local dbg = package.loaded["common.debugger_check"]
    if dbg then dbg.IsDebuggerAttached = _retFalse; dbg.Check = _retFalse; table.insert(_G.BypassLog, "L28-Debugger") end
  end)

  _G.Safe("bp_L29", function()
    local pn = package.loaded["common.process_name"]
    if pn then pn.Get = function() return "com.tencent.ig" end; pn.Check = _retTrue; table.insert(_G.BypassLog, "L29-ProcessName") end
    if rawget(_G, "GetPackageName") then rawset(_G, "GetPackageName", function() return "com.tencent.ig" end); table.insert(_G.BypassLog, "L29-PkgName") end
  end)

  _G.Safe("bp_L30", function()
    local tc = package.loaded["common.time_check"]
    if tc then tc.Check = _retTrue; tc.Verify = _retTrue; table.insert(_G.BypassLog, "L30-TimeCheck") end
    local skew = package.loaded["client.slua.network.clock_skew"]
    if skew then skew.Verify = _retTrue; skew.Check = _retTrue; table.insert(_G.BypassLog, "L30-ClockSkew") end
  end)

  _G.Safe("bp_L31", function()
    local fr = package.loaded["common.frida_check"]
    if fr then fr.Detect = _retFalse; fr.Check = _retFalse; fr.IsAttached = _retFalse; table.insert(_G.BypassLog, "L31-Frida") end
    local xp = package.loaded["common.xposed_check"]
    if xp then xp.Detect = _retFalse; xp.Check = _retFalse; table.insert(_G.BypassLog, "L31-Xposed") end
    local ls = package.loaded["common.lsposed_check"]
    if ls then ls.Detect = _retFalse; ls.Check = _retFalse; table.insert(_G.BypassLog, "L31-LSPosed") end
  end)


  Notify("Bypass — " .. #_G.BypassLog .. " layers active")
end

_G.GetOriginalHWID = function()
  if _G.Original_GetDeviceId then return tostring(_G.Original_GetDeviceId()) end
  local SL = import("KismetSystemLibrary")
  if SL and type(SL.GetDeviceId) == "function" then return tostring(SL.GetDeviceId()) end
  return "UNKNOWN"
end

-- ====================================================================
-- CONFIG FILE (ALL VERSIONS SUPPORT)
-- ====================================================================
_G.ConfigFileName = "TESLA 10X_settings.txt"

_G.GetConfigPaths = function(fn)
  local p = {
    "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fn,
    "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "ShadowTrackerExtra/Saved/Paks/" .. fn,
    "../../ShadowTrackerExtra/Saved/Paks/" .. fn,
    "../../../ShadowTrackerExtra/Saved/Paks/" .. fn,
    "../../../../ShadowTrackerExtra/Saved/Paks/" .. fn,
    fn
  }
  pcall(function()
    if os and os.getenv then
      local h = os.getenv("HOME")
      if h and h ~= "" then
        table.insert(p, 1, h .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn)
        table.insert(p, 2, h .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fn)
      end
    end
  end)
  return p
end

_G.BuildConfigPayload = function()
  local d = "-- TESLA 10X Config v3.0\n-- Owner: @OfficialOwner10x\n-- Channel: TESLA 10X\nreturn {\nLexusConfig = {\n"
  for k, v in pairs(_G.LexusConfig or {}) do
    local vs = tostring(v)
    if type(v) == "string" then vs = '"' .. v .. '"' end
    d = d .. '  ["' .. tostring(k) .. '"] = ' .. vs .. ',\n'
  end
  d = d .. "},\nCustomTextData = {\n"
  if _G.LexusState and _G.LexusState.CustomTextData then
    for k, v in pairs(_G.LexusState.CustomTextData) do
      local vs = tostring(v)
      if type(v) == "string" then vs = '"' .. v .. '"' end
      d = d .. '  ["' .. tostring(k) .. '"] = ' .. vs .. ',\n'
    end
  end
  d = d .. "}\n}"
  return d
end

_G.SaveModSettings = function(force)
  _G.Safe("save_cfg", function()
    if not force and not _G.LexusState.DirtySave then return end
    local now = os.clock()
    if not force and (_G.LexusState.LastSaveTime > 0) and (now - _G.LexusState.LastSaveTime) < 3.0 then return end
    local d = _G.BuildConfigPayload()
    if d == _G.LexusState.LastConfigHash then
      _G.LexusState.DirtySave = false; _G.LexusState.LastSaveTime = now; return
    end
    _G.LexusState.LastConfigHash = d
    _G.LexusState.LastSaveTime = now
    _G.LexusState.DirtySave = false
    for _, p in ipairs(_G.GetConfigPaths(_G.ConfigFileName)) do
      local f = io.open(p, "w")
      if f then f:write(d); f:close(); return end
    end
  end)
end

_G.MarkConfigDirty = function() _G.LexusState.DirtySave = true end

_G.LoadModSettings = function()
  _G.Safe("load_cfg", function()
    local content = nil
    for _, p in ipairs(_G.GetConfigPaths(_G.ConfigFileName)) do
      local f = io.open(p, "r")
      if f then content = f:read("*a"); f:close(); break end
    end
    if content then
      local fn = load(content)
      if fn then
        local d = fn()
        if d and type(d) == "table" then
          if d.LexusConfig then
            for k, v in pairs(d.LexusConfig) do if _G.LexusConfig[k] ~= nil then _G.LexusConfig[k] = v end end
          end
          if d.CustomTextData then
            _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
            for k, v in pairs(d.CustomTextData) do _G.LexusState.CustomTextData[k] = v end
          end
        end
      end
    end
  end)
end

_G.ReadLiveConfig = function() _G.MarkConfigDirty() end

-- ====================================================================
-- SHARED CACHED GETTERS
-- ====================================================================
local _lc, _sk, _gd = nil, nil, nil
_G.getCachedLinearColor = function()
  if _lc == nil then _lc = import("LinearColor") or _G.FLinearColor end
  return _lc
end
_G.getCachedSkeletalMesh = function()
  if _sk == nil then _sk = import("SkeletalMeshComponent") end
  return _sk
end
_G.getCachedGameplayData = function()
  if _gd == nil then
    local ok, m = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok then _gd = m end
  end
  return _gd
end

_G.GetSafeEnemyKey = function(e)
  if Valid(e) then
    if e.PlayerKey then return tostring(e.PlayerKey) end
    if type(e.GetUniqueID) == "function" then return tostring(e:GetUniqueID()) end
  end
  return tostring(e)
end

_G.CheckIsAI = function(p, md)
  if md and md.AK_IS_BOT ~= nil then return md.AK_IS_BOT, true end
  local ai, chk = false, false
  pcall(function()
    if p.bIsAI == true or p.IsAI == true then ai = true; chk = true end
    if type(p.IsBot) == "function" and p:IsBot() then ai = true; chk = true end
    local ps = p.PlayerState or (type(p.GetPlayerState) == "function" and p:GetPlayerState())
    if Valid(ps) then
      chk = true
      if ps.bIsABot == true or ps.bIsBot == true then ai = true end
      if type(ps.IsBot) == "function" and ps:IsBot() then ai = true end
    end
  end)
  if md and chk then md.AK_IS_BOT = ai end
  return ai, chk
end

_G.GetAllSkeletalMeshes = function(e, md)
  local t = os.clock()
  if md and md.CachedMeshes and md.CachedMeshTime and (t - md.CachedMeshTime < 0.5) then
    local v = {}
    for _, c in ipairs(md.CachedMeshes) do
      local pk = false
      pcall(function() if type(c.IsPendingKill) == "function" then pk = c:IsPendingKill() end end)
      if Valid(c) and not pk then table.insert(v, c) end
    end
    md.CachedMeshes = v
    return v
  end
  local m = {}
  if Valid(e.Mesh) then table.insert(m, e.Mesh) end
  pcall(function()
    local C = _G.getCachedSkeletalMesh()
    if C and type(e.GetComponentsByClass) == "function" then
      local c = e:GetComponentsByClass(C)
      if c then
        local n = type(c.Num) == "function" and c:Num() or #c
        for i = 1, n do
          local comp = type(c.Get) == "function" and c:Get(i-1) or c[i]
          if Valid(comp) and comp ~= e.Mesh then table.insert(m, comp) end
        end
      end
    end
  end)
  if md then md.CachedMeshes = m; md.CachedMeshTime = t end
  return m
end

-- ====================================================================
-- KILLINFO
-- ====================================================================
_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local _goldColor = nil
local _uiMgr = nil

_G.ForceEnableKillCounterUI = function()
  _G.Safe("kill_counter", function()
    local KCUIS = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or _G.GetModule("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    if KCUIS and KCUIS.__inner_impl and not _G.KCUISHacked then
      local impl = KCUIS.__inner_impl
      impl.CheckSupportKCUI = function() return true end
      impl.CheckNeedMainKillCounterUI = function(self, W, PID)
        if slua.isValid(W) then
          local wid = W:GetWeaponID()
          self:UpdateMainKillCounterUI(true, wid, wid)
        else
          self:UpdateMainKillCounterUI(false)
        end
      end
      _G.KCUISHacked = true
    end

    local MM = _G.GetModule("client.module_framework.ModuleManager")
    if MM and not _G.KCLogicHacked then
      local LKC = MM.GetModule(MM.CommonModuleConfig.LogicKillCounter)
      if LKC then
        LKC.CheckSupportKC = function() return true end
        LKC.CheckSupportKillCounterAvatar = function() return true end
        LKC.CheckHasWeaponKillCounter = function() return true end
        LKC.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
        LKC.GetEquipedKillCounterId = function() return 2100004 end
        LKC.GetMyEquipedKillCounterId = function() return 2100004 end
        LKC.GetOneWeaponKillCountInBattle = function(self, uid, wid) return _G.TDFTDeKillCounts[wid] or 0 end
        LKC.GetWeaponKillCountByUid = function(self, uid, wid) return _G.TDFTDeKillCounts[wid] or 0 end
        _G.KCLogicHacked = true
      end
    end

    local KillInfo = package.loaded["GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"] or _G.GetModule("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
    if KillInfo and KillInfo.__inner_impl and not _G.KillInfoHacked then
      local origFI = KillInfo.__inner_impl.FileItem
      KillInfo.__inner_impl.FileItem = function(self, DRD)
        _G.Safe("killinfo_fi", function()
          if not _G.LexusConfig.KillMessage then return end
          local GD = _G.getCachedGameplayData()
          local LP = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
          if slua.isValid(LP) and DRD.Causer == LP:GetPlayerNameSafety() then
            local cw = LP:GetCurrentWeapon()
            if slua.isValid(cw) then
              local wid = cw:GetWeaponID()
              if not _goldColor then
                local LC = _G.getCachedLinearColor()
                if LC then _goldColor = LC(1.0, 0.8, 0.0, 1.0) end
              end
              if _goldColor then DRD.IsUseColor, DRD.UseColor = true, _goldColor end
              if DRD.ResultHealthStatus == 2 then
                _G.TDFTDeKillCounts[wid] = (_G.TDFTDeKillCounts[wid] or 0) + 1
                if not _uiMgr then _uiMgr = _G.GetModule("client.slua_ui_framework.manager") end
                if _uiMgr and MM then
                  local ui = _uiMgr.GetUI(_uiMgr.UI_Config_InGame.MainKillCounter)
                  if ui and ui.UpdateWeaponID then
                    local mid = cw:GetWeaponMainAvatarID() or wid
                    ui:UpdateWeaponID(wid, mid)
                    local kc = MM.GetModule(MM.CommonModuleConfig.LogicKillCounter)
                    local kcid = kc:GetEquipedKillCounterId(0, mid)
                    ui:SetKillCounterItemShowWithNum(kcid, _G.TDFTDeKillCounts[wid], mid)
                  end
                end
              end
            end
          end
        end)
        if origFI then return origFI(self, DRD) end
      end
      _G.KillInfoHacked = true
    end
  end)
end

print("[TESLA10X] Part 1/4 loaded — Core + Bypass 42L FIXED + Config + KillInfo")

-- ====================================================================
-- TESLA 10X — Part 2/4: ESP (RED THEME) + Wallhack (Chams only)
-- Name + Distance + HP bar = RED
-- Snapline + Skeleton = GREEN (unchanged)
-- ====================================================================

local PlayerMapMarker = {}
PlayerMapMarker.MarkTypeID = 1007
PlayerMapMarker.bUseScreenESP = true
PlayerMapMarker.ESPWorldOffsetZ = 0
PlayerMapMarker.ESPAnchorOffsetX = 35
PlayerMapMarker.ESPAnchorOffsetY = 0
PlayerMapMarker.ESPTextOffsetX = 0
PlayerMapMarker.ESPTextOffsetY = 0
PlayerMapMarker.ESPWidgetAutoSize = true
PlayerMapMarker.ESPWidgetZOrder = 2
PlayerMapMarker.bShowDistance = true

PlayerMapMarker.HPWidgetSwitcherTypeIndex = 1
PlayerMapMarker.HPWidgetSwitcherType2Index = 1
PlayerMapMarker.bForceSwitcherIndexEveryUpdate = true

PlayerMapMarker.bUseSnapLines = true
PlayerMapMarker.SnapLineThickness = 1.5
PlayerMapMarker.SnapLineTopPercent = 0.06
PlayerMapMarker.SnapLineOriginOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetY = -14
PlayerMapMarker.SnapLineOpacity = 0.9
PlayerMapMarker.bUseSkeleton = true
PlayerMapMarker.SkeletonThickness = 1.0
PlayerMapMarker.SkeletonOpacity = 0.9
PlayerMapMarker.SkeletonMaxDistance = 100000
PlayerMapMarker.SkeletonWidgets = {}
PlayerMapMarker.SkeletonSmooth = {}
PlayerMapMarker.SkeletonChains = {
  {"neck_01", "upperarm_r", "lowerarm_r", "hand_r"},
  {"neck_01", "upperarm_l", "lowerarm_l", "hand_l"},
  {"head", "neck_01", "pelvis"},
  {"pelvis", "thigh_r", "calf_r", "foot_r"},
  {"pelvis", "thigh_l", "calf_l", "foot_l"}
}
PlayerMapMarker.BoneNameFallbacks = {
  ["head"] = {"head", "Head"},
  ["neck_01"] = {"neck_01", "Neck_01", "neck"},
  ["upperarm_r"] = {"upperarm_r", "UpperArm_R", "arm_r"},
  ["lowerarm_r"] = {"lowerarm_r", "LowerArm_R", "forearm_r"},
  ["hand_r"] = {"hand_r", "Hand_R"},
  ["upperarm_l"] = {"upperarm_l", "UpperArm_L", "arm_l"},
  ["lowerarm_l"] = {"lowerarm_l", "LowerArm_L", "forearm_l"},
  ["hand_l"] = {"hand_l", "Hand_L"},
  ["pelvis"] = {"pelvis", "Pelvis", "hip"},
  ["thigh_r"] = {"thigh_r", "Thigh_R", "leg_r"},
  ["calf_r"] = {"calf_r", "Calf_R", "shin_r"},
  ["foot_r"] = {"foot_r", "Foot_R"},
  ["thigh_l"] = {"thigh_l", "Thigh_L", "leg_l"},
  ["calf_l"] = {"calf_l", "Calf_L", "shin_l"},
  ["foot_l"] = {"foot_l", "Foot_L"},
}
PlayerMapMarker.bActive = false
PlayerMapMarker.ESPWidgets = {}
PlayerMapMarker.ESPWidgetPtrs = {}
PlayerMapMarker.SnapLineWidgets = {}
PlayerMapMarker._cachedViewportW = 1920
PlayerMapMarker._cachedViewportH = 1080
PlayerMapMarker._CanvasScaleX = 1.0
PlayerMapMarker._CanvasScaleY = 1.0
PlayerMapMarker._CanvasOffsetX = 0.0
PlayerMapMarker._CanvasOffsetY = 0.0
PlayerMapMarker._OBHeadWidgetClass = nil
PlayerMapMarker._OBHeadWidgetLoadFailed = false
PlayerMapMarker._LightUpdateInterval = 0.02
PlayerMapMarker._DistanceUpdateInterval = 0.1
PlayerMapMarker.nUpdateInterval = 0.35
PlayerMapMarker.bIncludeMe = false
PlayerMapMarker.bIncludeAI = true

local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local FVector = _G.FVector or import("Vector")
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)

-- ====================================================================
-- HELPERS
-- ====================================================================
function PlayerMapMarker.GetMyPlayerController()
  local GDP = _G.getCachedGameplayData()
  if not GDP then return nil end
  local PC = nil
  pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end)
  return Valid(PC) and PC or nil
end

function PlayerMapMarker.GetAllCharacters()
  local AllChars = {}
  pcall(function()
    local Pawns = Game:GetAllPlayerPawns()
    if Pawns then
      for _, Pawn in pairs(Pawns) do
        if Valid(Pawn) then
          local pKey = nil
          pcall(function()
            if Pawn.GetPlayerKey then pKey = Pawn:GetPlayerKey()
            elseif Pawn.PlayerKey then pKey = Pawn.PlayerKey
            elseif Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
          end)
          if pKey then AllChars[pKey] = Pawn end
        end
      end
    end
  end)
  return AllChars
end

function PlayerMapMarker.GetMyPlayerKey()
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not Valid(PC) then return nil end
  local k = nil
  pcall(function()
    if PC.GetPlayerKey then k = PC:GetPlayerKey()
    elseif PC.PlayerState and PC.PlayerState.PlayerKey then k = PC.PlayerState.PlayerKey end
  end)
  return k
end

function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
  local bMe = false
  pcall(function()
    local GDP = _G.getCachedGameplayData()
    if GDP and GDP.GetLocalCharacter then
      local MyChar = GDP.GetLocalCharacter()
      if MyChar and Character == MyChar then bMe = true; return end
    end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if PC and PC.GetPawn then
      local Pawn = PC:GetPawn()
      if Pawn and Character == Pawn then bMe = true end
    end
  end)
  if not bMe and MyKey and PlayerKey then bMe = (tostring(PlayerKey) == tostring(MyKey)) end
  return bMe
end

function PlayerMapMarker.GetCharacterLocation(Character)
  if not Valid(Character) then return nil end
  local loc = nil
  pcall(function() if Character.K2_GetActorLocation then loc = Character:K2_GetActorLocation() end end)
  return loc
end

function PlayerMapMarker.CalcDistance(l1, l2)
  if not l1 or not l2 then return nil end
  local d = nil
  pcall(function()
    local dx = (l1.X or 0) - (l2.X or 0)
    local dy = (l1.Y or 0) - (l2.Y or 0)
    d = math.sqrt(dx*dx + dy*dy)
  end)
  return d
end

function PlayerMapMarker.GetDistanceString(ml, tl)
  if not PlayerMapMarker.bShowDistance or not ml or not tl then return "" end
  local d = PlayerMapMarker.CalcDistance(ml, tl)
  if not d then return "" end
  local m = d / 100
  if m < 1000 then return string.format("%dm", math.floor(m)) end
  return string.format("%.1fkm", m / 1000)
end

function PlayerMapMarker.GetMyLocation()
  local GDP = _G.getCachedGameplayData()
  if not GDP then return nil end
  local MyChar = nil
  pcall(function() MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
  if not Valid(MyChar) then
    local PC = PlayerMapMarker.GetMyPlayerController()
    if Valid(PC) and PC.GetPawn then
      local Pawn = PC:GetPawn()
      if Valid(Pawn) and Pawn.K2_GetActorLocation then return Pawn:K2_GetActorLocation() end
    end
    return nil
  end
  return PlayerMapMarker.GetCharacterLocation(MyChar)
end

function PlayerMapMarker.GetPlayerName(Character)
  if not Valid(Character) then return "Unknown" end
  local n = nil
  pcall(function() if Character.GetPlayerNameSafety then n = Character:GetPlayerNameSafety() end end)
  if not n then
    pcall(function()
      local PS = nil
      if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
      if Valid(PS) and PS.GetPlayerName then n = PS:GetPlayerName() end
    end)
  end
  return n or "Unknown"
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
  if not Valid(Character) then return nil end
  local t = nil
  pcall(function() if Character.GetTeamID then t = Character:GetTeamID() end end)
  if not t then
    pcall(function()
      local PS = nil
      if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
      if Valid(PS) and PS.TeamID then t = PS.TeamID end
    end)
  end
  if not t then pcall(function() if Character.TeamID then t = Character.TeamID end end) end
  return t
end

-- TEAM COLOR NOW RED (per request)
function PlayerMapMarker.GetTeamColor(TeamID)
  return FLinearColor and FLinearColor(1.0, 0.12, 0.12, 1.0) or {R=255, G=30, B=30, A=255}
end

function PlayerMapMarker.GetCharacterMesh(Character)
  if not Valid(Character) then return nil end
  local m = nil
  pcall(function() if Character.Mesh and Game:IsValid(Character.Mesh) then m = Character.Mesh end end)
  return m
end

function PlayerMapMarker.GetESPLocation(Character)
  if not Valid(Character) then return nil end
  local loc = PlayerMapMarker.GetCharacterLocation(Character)
  if loc then
    local h = 85
    pcall(function()
      if Character.bIsCrouched then h = 60 end
      if Character.IsProne and Character:IsProne() then h = 30 end
    end)
    pcall(function() loc.Z = loc.Z + h + (PlayerMapMarker.ESPWorldOffsetZ or 0) end)
  end
  return loc
end

function PlayerMapMarker.IsOurESPWidget(w)
  if not w or not slua.isValid(w) then return false end
  local isOurs = false
  pcall(function()
    local wstr = tostring(w)
    for _, d in pairs(PlayerMapMarker.ESPWidgets) do
      if d and d.Widget and d.Widget.Container then
        if tostring(d.Widget.Container) == wstr then isOurs = true; return end
      end
    end
  end)
  return isOurs
end

function PlayerMapMarker.InitESPCanvas()
  if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then return true end
  local InGameUITools = nil
  pcall(function() InGameUITools = _G.GetModule("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
  if not InGameUITools then return false end
  local MainUI = nil
  pcall(function() MainUI = InGameUITools.GetMainControlBaseUI() end)
  if not MainUI or not Game:IsValid(MainUI) then return false end
  local canvas = nil
  pcall(function()
    if MainUI.CanvasPanel_0 and Game:IsValid(MainUI.CanvasPanel_0) then canvas = MainUI.CanvasPanel_0
    elseif MainUI.CanvasPanel_42 and Game:IsValid(MainUI.CanvasPanel_42) then canvas = MainUI.CanvasPanel_42 end
  end)
  if not canvas then return false end
  PlayerMapMarker.ESPCanvas = canvas
  pcall(function()
    local n = canvas:GetChildrenCount()
    for i = n - 1, 0, -1 do
      local c = canvas:GetChildAt(i)
      if c and slua.isValid(c) and PlayerMapMarker.IsOurESPWidget(c) then canvas:RemoveChild(c) end
    end
  end)
  return true
end

function PlayerMapMarker.UpdateCanvasTransform(PC)
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
  local ok = false
  pcall(function()
    local SBL = SlateBlueprintLibrary
    if SBL and SBL.AbsoluteToLocal then
      local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
      if cg then
        local p0 = SBL.AbsoluteToLocal(cg, FVector2D(0, 0))
        local p1 = SBL.AbsoluteToLocal(cg, FVector2D(100, 100))
        if p0 and p1 then
          PlayerMapMarker._CanvasScaleX = (p1.X - p0.X) / 100
          PlayerMapMarker._CanvasScaleY = (p1.Y - p0.Y) / 100
          PlayerMapMarker._CanvasOffsetX = p0.X
          PlayerMapMarker._CanvasOffsetY = p0.Y
          ok = true
        end
      end
    end
  end)
  if not ok then
    local s = 1.0
    local WLL = WidgetLayoutLibrary
    if WLL and WLL.GetViewportScale then s = WLL.GetViewportScale(PC) or 1.0 end
    PlayerMapMarker._CanvasScaleX = 1.0 / s
    PlayerMapMarker._CanvasScaleY = 1.0 / s
    PlayerMapMarker._CanvasOffsetX = 0
    PlayerMapMarker._CanvasOffsetY = 0
  end
end

function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, sp)
  if not sp then return FVector2D(0, 0) end
  return FVector2D(sp.X * PlayerMapMarker._CanvasScaleX + PlayerMapMarker._CanvasOffsetX,
                    sp.Y * PlayerMapMarker._CanvasScaleY + PlayerMapMarker._CanvasOffsetY)
end

function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, wl)
  if not Valid(PC) or not wl then return false, FVector2D(0, 0) end
  local sp = FVector2D(0, 0)
  local ok = false
  pcall(function()
    local r = PC:ProjectWorldLocationToScreen(wl, sp, true)
    if r == true or r == 1 then ok = true end
  end)
  if not ok or (sp.X == 0 and sp.Y == 0) then return false, FVector2D(0, 0) end
  return true, PlayerMapMarker.ScreenPixelToCanvasLocal(PC, sp)
end

function PlayerMapMarker.GetSnapLineStartPos(PC)
  local screenW, screenH = 0, 0
  pcall(function()
    if PC and PC.GetViewportSize then
      local vs = FVector2D(0, 0)
      PC:GetViewportSize(vs)
      if vs and vs.X and vs.X > 200 then screenW = vs.X; screenH = vs.Y end
    end
  end)
  if screenW <= 200 then
    pcall(function()
      local WLL = WidgetLayoutLibrary
      if WLL and WLL.GetViewportSize then
        local vs = WLL.GetViewportSize(PC)
        if vs and vs.X and vs.X > 200 then screenW = vs.X; screenH = vs.Y end
      end
    end)
  end
  if screenW <= 200 then
    screenW = PlayerMapMarker._cachedViewportW or 1920
    screenH = PlayerMapMarker._cachedViewportH or 1080
  end
  local topPct = PlayerMapMarker.SnapLineTopPercent or 0.06
  if not PlayerMapMarker._CachedTopCenterPixel then PlayerMapMarker._CachedTopCenterPixel = FVector2D(0, 0) end
  PlayerMapMarker._CachedTopCenterPixel.X = screenW * 0.5
  PlayerMapMarker._CachedTopCenterPixel.Y = screenH * topPct
  local cp = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
  return cp.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0), cp.Y
end

-- ====================================================================
-- WIDGET TREE HELPERS
-- ====================================================================
function PlayerMapMarker._GetWidgetRoot(W)
  if not W or not slua.isValid(W) then return nil end
  local Root = nil
  pcall(function() if W.GetRootWidget then Root = W:GetRootWidget() end end)
  if Root and slua.isValid(Root) then return Root end
  pcall(function() if W.WidgetTree and W.WidgetTree.RootWidget then Root = W.WidgetTree.RootWidget end end)
  if Root and slua.isValid(Root) then return Root end
  return nil
end

function PlayerMapMarker._FindNamedWidgetInTree(W, TargetName, MaxDepth)
  if not W or not slua.isValid(W) then return nil end
  MaxDepth = MaxDepth or 8
  local wname = nil
  pcall(function() if W.GetName then wname = W:GetName() end end)
  if wname and wname == TargetName then return W end
  local n = 0
  pcall(function() if W.GetChildrenCount then n = W:GetChildrenCount() end end)
  if n > 0 then
    for i = 0, n - 1 do
      local c = nil
      pcall(function() c = W:GetChildAt(i) end)
      if c and slua.isValid(c) then
        local found = PlayerMapMarker._FindNamedWidgetInTree(c, TargetName, MaxDepth - 1)
        if found then return found end
      end
    end
  else
    local Root = PlayerMapMarker._GetWidgetRoot(W)
    if Root and slua.isValid(Root) and Root ~= W then
      local found = PlayerMapMarker._FindNamedWidgetInTree(Root, TargetName, MaxDepth - 1)
      if found then return found end
    end
  end
  return nil
end

local _WhiteTexture = nil
local _bWhiteTextureFailed = false
local function GetWhiteTexture()
  if _WhiteTexture then return _WhiteTexture end
  if _bWhiteTextureFailed then return nil end
  pcall(function()
    local paths = { "/Game/BluePrints/UI/Textures/White.White", "/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture" }
    for _, path in ipairs(paths) do
      pcall(function() local tex = import(path); if tex and slua.isValid(tex) then _WhiteTexture = tex end end)
      if _WhiteTexture then break end
    end
  end)
  if not _WhiteTexture then _bWhiteTextureFailed = true end
  return _WhiteTexture
end

local function SetImageColor(Image, color)
  if not Image or not slua.isValid(Image) then return false end
  pcall(function() if Image.SetBrushTintColor then Image:SetBrushTintColor(color) end end)
  pcall(function() if Image.SetColorAndOpacity then Image:SetColorAndOpacity(color) end end)
  pcall(function()
    if Image.SetBrushFromTexture then
      local t = GetWhiteTexture()
      if t then Image:SetBrushFromTexture(t, false); Image:SetColorAndOpacity(color) end
    end
  end)
  pcall(function() Image:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible); Image:SetRenderOpacity(1.0) end)
  return true
end

function PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
  if not Widget or not Widget.Container then return end
  local W = Widget.Container
  if not W or not slua.isValid(W) then return end

  if not Widget._TeamBGRef then
    pcall(function()
      Widget._TeamBGRef = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamBG", 8)
      Widget._TeamLogoBGRef = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamLogoBG", 8)
      Widget._CacheDone = true
    end)
    if not Widget._CacheDone then return end
  end

  if not _G.LexusConfig.Esp9_Team then
    pcall(function()
      if Widget._TeamBGRef and slua.isValid(Widget._TeamBGRef) then
        Widget._TeamBGRef:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      end
      if Widget._TeamLogoBGRef and slua.isValid(Widget._TeamLogoBGRef) then
        Widget._TeamLogoBGRef:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      end
    end)
    return
  end

  if Widget._LastTeamColor == TeamID then return end
  Widget._LastTeamColor = TeamID

  local color = PlayerMapMarker.GetTeamColor(TeamID)
  if not color then return end

  pcall(function()
    if Widget._TeamBGRef and slua.isValid(Widget._TeamBGRef) then
      SetImageColor(Widget._TeamBGRef, color)
    end
    if Widget._TeamLogoBGRef and slua.isValid(Widget._TeamLogoBGRef) then
      SetImageColor(Widget._TeamLogoBGRef, color)
    end
  end)
end

-- ====================================================================
-- WEAPON ICON
-- ====================================================================
function PlayerMapMarker.GetCharacterWeaponInfo(Character)
  if not Valid(Character) then return nil end
  local wid, wname, wtex, cw = nil, nil, nil, nil
  pcall(function() if Character.GetCurrentWeapon then cw = Character:GetCurrentWeapon() end end)
  if not cw then pcall(function() cw = Character.CurrentWeapon end) end
  if cw and Valid(cw) then
    pcall(function() if cw.GetWeaponID then wid = cw:GetWeaponID() end end)
    if not wid then pcall(function() wid = cw.WeaponID end) end
    pcall(function() if cw.GetWeaponName then wname = cw:GetWeaponName() end end)
    pcall(function() if cw.GetWeaponIcon then wtex = cw:GetWeaponIcon() end end)
  end
  return { WeaponID = wid, WeaponName = wname, WeaponIconTexture = wtex, CurrentWeapon = cw }
end

function PlayerMapMarker.FindWeaponIconInWidget(W, Depth, MaxDepth)
  if not W or not slua.isValid(W) then return nil end
  Depth = Depth or 0; MaxDepth = MaxDepth or 8
  local propNames = {"Image_Weapon", "Image_WeaponIcon", "Image_Gun", "Image_Icon", "WeaponIcon", "WeaponImage", "Image_Equip"}
  for _, pname in ipairs(propNames) do
    pcall(function()
      local prop = W[pname]
      if prop and slua.isValid(prop) and prop.Brush then return prop end
    end)
  end
  if Depth >= MaxDepth then return nil end
  local n = 0
  pcall(function() if W.GetChildrenCount then n = W:GetChildrenCount() end end)
  for i = 0, math.max(n - 1, 0) do
    local c = nil
    pcall(function() c = W:GetChildAt(i) end)
    if c and slua.isValid(c) then
      local r = PlayerMapMarker.FindWeaponIconInWidget(c, Depth + 1, MaxDepth)
      if r then return r end
    end
  end
  if n == 0 then
    local Root = PlayerMapMarker._GetWidgetRoot(W)
    if Root and slua.isValid(Root) and Root ~= W then
      local r = PlayerMapMarker.FindWeaponIconInWidget(Root, Depth + 1, MaxDepth)
      if r then return r end
    end
  end
  return nil
end

function PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, W, H)
  if not ImageWidget or not slua.isValid(ImageWidget) then return end
  W = W or 96; H = H or 48
  pcall(function()
    local b = ImageWidget.Brush
    if b then
      b.ImageSize = FVector2D(W, H)
      b.DrawAs = 3
      b.TintColor = FLinearColor(1,1,1,1)
      if ImageWidget.SetBrush then ImageWidget:SetBrush(b) end
    end
    if ImageWidget.SetDesiredSizeOverride then ImageWidget:SetDesiredSizeOverride(FVector2D(W, H)) end
    ImageWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    ImageWidget:SetRenderOpacity(1.0)
  end)
end

function PlayerMapMarker.ApplyWeaponIconToImage(ImageWidget, winfo)
  if not ImageWidget or not slua.isValid(ImageWidget) then return false end
  if not winfo or not winfo.WeaponID then return false end
  local path = nil
  pcall(function()
    local rec = CDataTable.GetTableData("Item", winfo.WeaponID)
    if rec and rec.KillWhiteIcon and rec.KillWhiteIcon ~= "" then path = rec.KillWhiteIcon end
    if not path or path == "" then
      local UIUtil = require("client.common.ui_util")
      local p1 = UIUtil.GetItemBigIcon(winfo.WeaponID, ImageWidget)
      if p1 and p1 ~= "" then path = p1 end
    end
    if not path or path == "" then
      local UIUtil = require("client.common.ui_util")
      path = UIUtil.GetItemSmallIcon(winfo.WeaponID, ImageWidget, false)
    end
  end)
  if (not path or path == "") and winfo.WeaponIconTexture and slua.isValid(winfo.WeaponIconTexture) and ImageWidget.SetBrushFromTexture then
    ImageWidget:SetBrushFromTexture(winfo.WeaponIconTexture, true)
    PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget)
    return true
  end
  if not path or path == "" then return false end
  local ok = false
  pcall(function()
    if ImageWidget.SetBrushResourceFromPathSync then ImageWidget:SetBrushResourceFromPathSync(path, true); ok = true end
    if not ok then
      local util = require("client.slua_ui_framework.util")
      local res = util.SetTexture(ImageWidget, path, { sync = true, bMatchSize = true, bIsInCombatState = true })
      ok = res ~= nil
    end
  end)
  if ok then PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget) end
  return ok
end

function PlayerMapMarker.AddWeaponIconToESP(WidgetData, Character)
  if not WidgetData or not WidgetData.Container then return end
  local W = WidgetData.Container
  if not slua.isValid(W) then return end

  local now = os.clock()
  if WidgetData._LastWepCheck and (now - WidgetData._LastWepCheck) < 0.5 then return end
  WidgetData._LastWepCheck = now

  if not _G.LexusConfig.Esp9_Weapon then
    pcall(function()
      local icon = PlayerMapMarker.FindWeaponIconInWidget(W, 0, 8)
      if icon and slua.isValid(icon) then icon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
    end)
    WidgetData._LastWeaponID = 0
    return
  end

  local winfo = Character and PlayerMapMarker.GetCharacterWeaponInfo(Character) or nil
  local icon = PlayerMapMarker.FindWeaponIconInWidget(W, 0, 8)
  if not icon or not slua.isValid(icon) then return end

  if not winfo or not winfo.WeaponID or winfo.WeaponID == 0 then
    icon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    WidgetData._LastWeaponID = 0
    return
  end

  if WidgetData._LastWeaponID == winfo.WeaponID and WidgetData._WeaponApplied then
    icon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    return
  end

  local ok = PlayerMapMarker.ApplyWeaponIconToImage(icon, winfo)
  if ok then
    icon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    icon:SetRenderOpacity(1.0)
    WidgetData._LastWeaponID = winfo.WeaponID
    WidgetData._WeaponApplied = true
  else
    icon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
  end
end

-- ====================================================================
-- WIDGET CREATION (RED HP BAR)
-- ====================================================================
function PlayerMapMarker.FindProgressBarInWidget(W, Depth, MaxDepth)
  if not W or not slua.isValid(W) then return nil end
  Depth = Depth or 0; MaxDepth = MaxDepth or 5
  if Depth > MaxDepth then return nil end
  local isPB = false
  pcall(function() if W.SetPercent and W.SetFillColorAndOpacity then isPB = true end end)
  if isPB then return W end
  local n = 0
  pcall(function() if W.GetChildrenCount then n = W:GetChildrenCount() end end)
  for i = 0, math.max(n - 1, 0) do
    local c = nil
    pcall(function() c = W:GetChildAt(i) end)
    if c and slua.isValid(c) then
      local r = PlayerMapMarker.FindProgressBarInWidget(c, Depth + 1, MaxDepth)
      if r then return r end
    end
  end
  return nil
end

function PlayerMapMarker._StyleHPBar(pb)
  pcall(function()
    pb:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    pb:SetRenderOpacity(1.0)
    pb:SetPercent(1.0)
    -- RED FILL (per request)
    pb:SetFillColorAndOpacity(FLinearColor(1.0, 0.10, 0.10, 1.0))
    if pb.SetBarFillType then pb:SetBarFillType(0) end
    local white = GetWhiteTexture()
    if white and pb.WidgetStyle then
      local style = pb.WidgetStyle
      if style.BackgroundImage then
        style.BackgroundImage.ImageSize = FVector2D(100, 12)
        style.BackgroundImage.DrawAs = 3
        -- dark red background tint
        style.BackgroundImage.TintColor = FLinearColor(0.14, 0.02, 0.02, 1.0)
        style.BackgroundImage.ResourceObject = white
      end
      if style.FillImage then
        style.FillImage.ImageSize = FVector2D(100, 12)
        style.FillImage.DrawAs = 3
        -- red fill
        style.FillImage.TintColor = FLinearColor(1.0, 0.10, 0.10, 1.0)
        style.FillImage.ResourceObject = white
      end
      pb:SetWidgetStyle(style)
    end
  end)
end

function PlayerMapMarker.CreateESPWidget()
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
  if PlayerMapMarker._OBHeadWidgetLoadFailed then return nil end
  if not PlayerMapMarker._OBHeadWidgetClass then
    pcall(function()
      local Path = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP"
      local c = slua.loadClass(Path)
      if c then PlayerMapMarker._OBHeadWidgetClass = c end
    end)
    if not PlayerMapMarker._OBHeadWidgetClass then
      PlayerMapMarker._OBHeadWidgetLoadFailed = true
      return nil
    end
  end
  local Widget = nil
  pcall(function()
    local FnLib = import("STExtraBlueprintFunctionLibrary")
    local PC = PlayerMapMarker.GetMyPlayerController()
    local Outer = Valid(PC) and PC.Object or PlayerMapMarker.ESPCanvas
    Widget = FnLib.CreateWidgetByClass(PlayerMapMarker._OBHeadWidgetClass, Outer)
  end)
  if not Widget then return nil end
  pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
  pcall(function() Widget:SetRenderOpacity(1.0) end)

  -- [FIX] Hide white background from name widget
  pcall(function()
    local function hideBG(W, depth)
      if depth > 8 or not W or not slua.isValid(W) then return end
      local n = 0
      pcall(function() if W.GetChildrenCount then n = W:GetChildrenCount() end end)
      for i = 0, n - 1 do
        local c = nil
        pcall(function() c = W:GetChildAt(i) end)
        if c and slua.isValid(c) then
          local wname = nil
          pcall(function() if c.GetName then wname = c:GetName() end end)
          local isImg = false
          pcall(function() if c.Brush then isImg = true end end)
          if isImg and wname and (string.find(wname, "BG") or string.find(wname, "Background") or string.find(wname, "bg")) then
            pcall(function() c:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
          end
          hideBG(c, depth + 1)
        end
      end
    end
    hideBG(Widget, 0)
  end)

  local NameText = nil
  local HealthFill = nil
  local isOrigPB = false
  pcall(function()
    NameText = Widget.TextBlock_TeamName
    local WS = Widget.WidgetSwitcher_Type
    if WS and slua.isValid(WS) then pcall(function() WS:SetActiveWidgetIndex(1) end) end
    local WS2 = Widget.WidgetSwitcher_Type2
    if WS2 and slua.isValid(WS2) then pcall(function() WS2:SetActiveWidgetIndex(1) end) end
    local SB = Widget.SizeBox_HP
    if SB and slua.isValid(SB) then
      SB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      SB:SetHeightOverride(12)
      SB:SetWidthOverride(100)
      local child = nil
      pcall(function() if SB.GetContent then child = SB:GetContent() end end)
      if not child then pcall(function() if SB.GetChildAt then child = SB:GetChildAt(0) end end) end
      local FoundPB = nil
      if child and slua.isValid(child) then
        FoundPB = PlayerMapMarker.FindProgressBarInWidget(child, 0, 5)
      end
      if FoundPB and slua.isValid(FoundPB) then
        HealthFill = FoundPB
        isOrigPB = true
        PlayerMapMarker._StyleHPBar(FoundPB)
      end
      if not HealthFill then
        local PB = nil
        pcall(function() PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", SB) end)
        if PB and slua.isValid(PB) then
          pcall(function()
            PB:SetDesiredSizeOverride(FVector2D(100, 12))
          end)
          PlayerMapMarker._StyleHPBar(PB)
          local used = false
          pcall(function() if SB.SetContent then SB:SetContent(PB); used = true end end)
          if not used then pcall(function() SB:AddChild(PB) end) end
          HealthFill = PB
        end
      end
    end
  end)
  return {
    Container = Widget, NameText = NameText, HealthFill = HealthFill,
    IsGameWidget = true, IsOriginalProgressBar = isOrigPB, HasChildren = (NameText ~= nil),
    _SmHP = nil,
  }
end

-- RED TEXT for name + distance
function PlayerMapMarker.UpdateESPText(Widget, Text)
  if not Widget then return end
  if Widget._LastESPText == Text then return end
  Widget._LastESPText = Text
  local function apply(w, txt)
    if not w or not slua.isValid(w) then return end
    if txt == "" then w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed); return end
    pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() w:SetText(txt) end)
    pcall(function()
      local FS = import("SlateColor")
      -- RED TEXT (per request)
      local c = FLinearColor(1.0, 0.12, 0.12, 1.0)
      if FS then w:SetColorAndOpacity(FS(c)) else w:SetColorAndOpacity(c) end
    end)
    pcall(function() if w.SetJustification then w:SetJustification(1) end end)
  end
  if Widget.NameText and slua.isValid(Widget.NameText) then apply(Widget.NameText, Text) end
  if Widget.IsGameWidget and Widget.Container then
    pcall(function()
      local W = Widget.Container
      if W and slua.isValid(W) then
        if W.SetPlayerName then
          local n = Text
          local idx = string.find(Text, " %[")
          if idx then n = string.sub(Text, 1, idx - 1) end
          W:SetPlayerName(n)
        end
        apply(W.TextBlock_TeamName, Text)
        apply(W.TextBlock_PlayerName, Text)
      end
    end)
  end
end

-- SMOOTH RED HP BAR
function PlayerMapMarker.UpdateESPHealth(Widget, pct)
  if not Widget then return end
  local bShow = _G.LexusConfig.Esp9_HP
  local pctVal = math.max(0, math.min(1, tonumber(pct) or 0))
  local dt = (_G.FrameDelta and _G.FrameDelta.ClampedDelta) or 0.016

  if Widget.Container then
    pcall(function()
      local W = Widget.Container
      if not W or not slua.isValid(W) then return end
      if W.SizeBox_HP and slua.isValid(W.SizeBox_HP) then
        if bShow then
          W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
          W.SizeBox_HP:SetHeightOverride(12)
          W.SizeBox_HP:SetWidthOverride(100)
        else
          W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
          Widget._SmHP = nil
          return
        end
      end
      if W.WidgetSwitcher_Type and slua.isValid(W.WidgetSwitcher_Type) then
        W.WidgetSwitcher_Type:SetActiveWidgetIndex(1)
      end
      if W.WidgetSwitcher_Type2 and slua.isValid(W.WidgetSwitcher_Type2) then
        W.WidgetSwitcher_Type2:SetActiveWidgetIndex(1)
      end
    end)
  end

  if not bShow then return end

  if Widget._SmHP == nil then Widget._SmHP = pctVal end
  Widget._SmHP = _G.LerpSmooth(Widget._SmHP, pctVal, 14, dt)
  local vis = Widget._SmHP

  if Widget.HealthFill and slua.isValid(Widget.HealthFill) then
    pcall(function()
      local pb = Widget.HealthFill
      pb:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      pb:SetRenderOpacity(1.0)
      pb:SetPercent(vis)
      -- RED FILL (per request)
      pb:SetFillColorAndOpacity(FLinearColor(1.0, 0.10, 0.10, 1.0))
      if pb.SetBarFillType then pb:SetBarFillType(0) end
      local white = GetWhiteTexture()
      if white and pb.WidgetStyle then
        local style = pb.WidgetStyle
        if style.BackgroundImage then
          style.BackgroundImage.ImageSize = FVector2D(100, 12)
          style.BackgroundImage.DrawAs = 3
          style.BackgroundImage.TintColor = FLinearColor(0.14, 0.02, 0.02, 1.0)
          style.BackgroundImage.ResourceObject = white
        end
        if style.FillImage then
          style.FillImage.ImageSize = FVector2D(100, 12)
          style.FillImage.DrawAs = 3
          style.FillImage.TintColor = FLinearColor(1.0, 0.10, 0.10, 1.0)
          style.FillImage.ResourceObject = white
        end
        pb:SetWidgetStyle(style)
      end
    end)
  end
end

function PlayerMapMarker.UpdateESPPositionWithPC(Widget, WorldLoc, PC, CanvasPos)
  if not Widget or not Valid(PC) then return false end
  local Container = Widget.Container or Widget
  local bOnScreen = true
  if not CanvasPos then
    if not WorldLoc then return false end
    bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
  end
  if not bOnScreen then
    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    return false
  end
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
          pcall(function() Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 20) end)
        end
      end
      local bShowAny = _G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP or _G.LexusConfig.Esp9_Team or _G.LexusConfig.Esp9_Weapon
      if bShowAny then Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      else Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
      if not Widget._OffsetResetDone then
        pcall(function() Container:SetRenderTranslation(FVector2D(0, 0)) end)
        pcall(function() Container:SetRenderScale(FVector2D(0.90, 0.90)) end)
        pcall(function() Container:SetRenderTransformPivot(FVector2D(0.5, 1.0)) end)
        Widget._OffsetResetDone = true
      end
      if Slot and slua.isValid(Slot) and Slot ~= PlayerMapMarker.ESPCanvas then
        local fx = CanvasPos.X + (PlayerMapMarker.ESPAnchorOffsetX or 0)
        local fy = CanvasPos.Y + (PlayerMapMarker.ESPAnchorOffsetY or 0)
        if type(Widget) == "table" then
          if not Widget._SmoothPosX then
            Widget._SmoothPosX = fx; Widget._SmoothPosY = fy
          else
            local dt = _G.FrameDelta.ClampedDelta
            Widget._SmoothPosX = _G.LerpSmooth(Widget._SmoothPosX, fx, 30, dt)
            Widget._SmoothPosY = _G.LerpSmooth(Widget._SmoothPosY, fy, 30, dt)
          end
          if not Widget._PosVec then Widget._PosVec = FVector2D(Widget._SmoothPosX, Widget._SmoothPosY) end
          Widget._PosVec.X = Widget._SmoothPosX; Widget._PosVec.Y = Widget._SmoothPosY
          Slot:SetPosition(Widget._PosVec)
        else
          Slot:SetPosition(FVector2D(fx, fy))
        end
      end
    end
  end)
  return true
end

-- ====================================================================
-- SNAPLINE — GREEN
-- ====================================================================
function PlayerMapMarker.CreateSnapLine()
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
  local B = nil
  pcall(function() B = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
  if not B or not slua.isValid(B) then return nil end
  pcall(function() B:SetBrushColor(FLinearColor(0, 1, 0, PlayerMapMarker.SnapLineOpacity or 0.9)) end)
  pcall(function() B:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
  pcall(function() B:SetRenderTransformPivot(FVector2D(0, 0.5)) end)
  local Slot = nil
  pcall(function()
    Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(B)
    if Slot then Slot:SetAutoSize(false); Slot:SetZOrder(1) end
  end)
  return { Widget = B, Slot = Slot }
end

function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
  if not PlayerMapMarker.bUseSnapLines then return end
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
  local LD = PlayerMapMarker.SnapLineWidgets[KeyStr]
  if not bOnScreen or not CanvasPos then
    if LD and LD.Widget and slua.isValid(LD.Widget) then LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
    return
  end
  if not LD then
    LD = PlayerMapMarker.CreateSnapLine()
    if not LD or not LD.Widget or not LD.Slot then return end
    PlayerMapMarker.SnapLineWidgets[KeyStr] = LD
  end
  pcall(function() LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
  pcall(function() LD.Widget:SetBrushColor(FLinearColor(0, 1, 0, PlayerMapMarker.SnapLineOpacity or 0.9)) end)
  local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
  local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)
  if not LD._SX then LD._SX = fromX; LD._SY = fromY; LD._TX = toX; LD._TY = toY end
  local dt = _G.FrameDelta.ClampedDelta
  LD._SX = _G.LerpSmooth(LD._SX, fromX, 40, dt)
  LD._SY = _G.LerpSmooth(LD._SY, fromY, 40, dt)
  LD._TX = _G.LerpSmooth(LD._TX, toX, 30, dt)
  LD._TY = _G.LerpSmooth(LD._TY, toY, 30, dt)
  local dx = LD._TX - LD._SX
  local dy = LD._TY - LD._SY
  local len = math.sqrt(dx*dx + dy*dy)
  local thick = PlayerMapMarker.SnapLineThickness or 1.5
  local angle = (_G.atan2(dy, dx)) * 57.29577951308232
  pcall(function()
    LD.Slot:SetPosition(FVector2D(LD._SX, LD._SY - thick/2.0))
    LD.Slot:SetSize(FVector2D(len, thick))
    LD.Widget:SetRenderAngle(angle)
  end)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
  local LD = PlayerMapMarker.SnapLineWidgets[KeyStr]
  if LD and LD.Widget and slua.isValid(LD.Widget) then
    pcall(function() LD.Widget:RemoveFromParent(); LD.Widget:ConditionalBeginDestroy() end)
  end
  PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
end

function PlayerMapMarker.ClearAllSnapLines()
  for _, LD in pairs(PlayerMapMarker.SnapLineWidgets) do
    if LD and LD.Widget and slua.isValid(LD.Widget) then
      pcall(function() LD.Widget:RemoveFromParent(); LD.Widget:ConditionalBeginDestroy() end)
    end
  end
  PlayerMapMarker.SnapLineWidgets = {}
end

-- ====================================================================
-- SKELETON — GREEN + SMOOTH
-- ====================================================================
function PlayerMapMarker.GetBoneLocationWithFallback(Character, PrimaryBoneName)
  if not Valid(Character) or not PrimaryBoneName then return nil end
  local fb = PlayerMapMarker.BoneNameFallbacks[PrimaryBoneName] or {PrimaryBoneName}
  local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
  if not Mesh or not Game:IsValid(Mesh) then return nil end
  for _, bn in ipairs(fb) do
    local loc = nil
    pcall(function()
      if Mesh.GetSocketLocation then loc = Mesh:GetSocketLocation(bn)
      elseif Mesh.GetBoneLocation then loc = Mesh:GetBoneLocation(bn) end
    end)
    if loc then return loc end
  end
  return nil
end

function PlayerMapMarker.CreateSkeletonLineWidget()
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
  local B = nil
  pcall(function() B = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
  if not B or not slua.isValid(B) then return nil end
  pcall(function() B:SetBrushColor(FLinearColor(0, 1, 0, PlayerMapMarker.SkeletonOpacity or 0.9)) end)
  pcall(function() B:SetRenderTransformPivot(FVector2D(0, 0.5)) end)
  local Slot = nil
  pcall(function()
    Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(B)
    if Slot then Slot:SetAutoSize(false); Slot:SetZOrder(5) end
  end)
  return { Widget = B, Slot = Slot, posVec = FVector2D(0,0), sizeVec = FVector2D(0,0) }
end

function PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, bVisible, TeamColor, bPlayerOnScreen, charLoc)
  if not PlayerMapMarker.bUseSkeleton then return end
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
  local Bones = PlayerMapMarker.SkeletonWidgets[KeyStr]
  if not bVisible or not Valid(Character) or not Valid(PC) then
    if Bones then
      for _, LD in ipairs(Bones) do
        if LD and LD.Widget and slua.isValid(LD.Widget) then LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
      end
    end
    PlayerMapMarker.SkeletonSmooth[KeyStr] = nil
    return
  end
  if not charLoc then charLoc = PlayerMapMarker.GetESPLocation(Character) end
  if not charLoc then return end
  if not Bones then Bones = {}; PlayerMapMarker.SkeletonWidgets[KeyStr] = Bones end

  local lineColor = FLinearColor(0, 1, 0, PlayerMapMarker.SkeletonOpacity or 0.9)
  local dt = (_G.FrameDelta and _G.FrameDelta.ClampedDelta) or 0.016
  local SmoothedBones = PlayerMapMarker.SkeletonSmooth[KeyStr] or {}
  PlayerMapMarker.SkeletonSmooth[KeyStr] = SmoothedBones

  local cache = PlayerMapMarker._StaticBoneLocCache or {}
  PlayerMapMarker._StaticBoneLocCache = cache
  for k in pairs(cache) do cache[k] = nil end

  local lineIndex = 0
  local thick = PlayerMapMarker.SkeletonThickness or 1.0

  for _, chain in ipairs(PlayerMapMarker.SkeletonChains) do
    local lastX, lastY = nil, nil
    for _, boneName in ipairs(chain) do
      local boneWorld = cache[boneName]
      if boneWorld == nil then
        boneWorld = PlayerMapMarker.GetBoneLocationWithFallback(Character, boneName) or false
        cache[boneName] = boneWorld
      end
      if boneWorld == false then boneWorld = nil end
      local cx, cy = nil, nil
      if boneWorld then
        local ok, pos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, boneWorld)
        if ok then cx = pos.X; cy = pos.Y end
      end
      if lastX and cx then
        lineIndex = lineIndex + 1
        local LD = Bones[lineIndex]
        if not LD or not LD.Widget or not slua.isValid(LD.Widget) then
          LD = PlayerMapMarker.CreateSkeletonLineWidget()
          if LD then Bones[lineIndex] = LD end
        end
        if LD and LD.Widget and LD.Slot then
          local smKey = boneName .. "_" .. tostring(lineIndex)
          local prev = SmoothedBones[smKey]
          local smFromX, smFromY, smToX, smToY
          if prev then
            smFromX = _G.LerpSmooth(prev.fx, lastX, 35, dt)
            smFromY = _G.LerpSmooth(prev.fy, lastY, 35, dt)
            smToX = _G.LerpSmooth(prev.tx, cx, 35, dt)
            smToY = _G.LerpSmooth(prev.ty, cy, 35, dt)
          else
            smFromX, smFromY, smToX, smToY = lastX, lastY, cx, cy
          end
          SmoothedBones[smKey] = { fx = smFromX, fy = smFromY, tx = smToX, ty = smToY }

          if LD._Color ~= lineColor then LD.Widget:SetBrushColor(lineColor); LD._Color = lineColor end
          LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
          local dx = smToX - smFromX
          local dy = smToY - smFromY
          local len = math.sqrt(dx*dx + dy*dy)
          local ang = (_G.atan2(dy, dx)) * 57.29577951308232
          LD.posVec.X = smFromX; LD.posVec.Y = smFromY - thick/2.0
          LD.sizeVec.X = len; LD.sizeVec.Y = thick
          LD.Slot:SetPosition(LD.posVec)
          LD.Slot:SetSize(LD.sizeVec)
          LD.Widget:SetRenderAngle(ang)
        end
      end
      lastX = cx; lastY = cy
    end
  end
  for i = lineIndex + 1, #Bones do
    local LD = Bones[i]
    if LD and LD.Widget and slua.isValid(LD.Widget) then LD.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
  end
end

function PlayerMapMarker.RemoveSkeletonLines(KeyStr)
  local B = PlayerMapMarker.SkeletonWidgets[KeyStr]
  if B then
    for _, LD in ipairs(B) do
      if LD and LD.Widget and slua.isValid(LD.Widget) then
        pcall(function() LD.Widget:RemoveFromParent(); LD.Widget:ConditionalBeginDestroy() end)
      end
    end
    PlayerMapMarker.SkeletonWidgets[KeyStr] = nil
  end
  PlayerMapMarker.SkeletonSmooth[KeyStr] = nil
end

function PlayerMapMarker.ClearAllSkeletonLines()
  for _, B in pairs(PlayerMapMarker.SkeletonWidgets) do
    for _, LD in ipairs(B) do
      if LD and LD.Widget and slua.isValid(LD.Widget) then
        pcall(function() LD.Widget:RemoveFromParent(); LD.Widget:ConditionalBeginDestroy() end)
      end
    end
  end
  PlayerMapMarker.SkeletonWidgets = {}
  PlayerMapMarker.SkeletonSmooth = {}
end

function PlayerMapMarker.RemoveESPWidget(Widget, KeyStr)
  if not Widget then return end
  local C = Widget.Container or Widget
  pcall(function()
    PlayerMapMarker.ESPWidgetPtrs[tostring(C)] = nil
    C:RemoveFromParent()
    C:ConditionalBeginDestroy()
  end)
  if KeyStr then
    PlayerMapMarker.RemoveSnapLine(KeyStr)
    PlayerMapMarker.RemoveSkeletonLines(KeyStr)
  end
end

function PlayerMapMarker.ClearAllESP()
  for k, d in pairs(PlayerMapMarker.ESPWidgets) do PlayerMapMarker.RemoveESPWidget(d.Widget, k) end
  PlayerMapMarker.ESPWidgets = {}
  PlayerMapMarker.ESPWidgetPtrs = {}
  PlayerMapMarker.ClearAllSnapLines()
  PlayerMapMarker.ClearAllSkeletonLines()
  if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
    pcall(function()
      local n = PlayerMapMarker.ESPCanvas:GetChildrenCount()
      for i = n - 1, 0, -1 do
        local c = PlayerMapMarker.ESPCanvas:GetChildAt(i)
        if c and slua.isValid(c) and PlayerMapMarker.IsOurESPWidget(c) then PlayerMapMarker.ESPCanvas:RemoveChild(c) end
      end
    end)
  end
  PlayerMapMarker.ESPCanvas = nil
  PlayerMapMarker._OBHeadWidgetClass = nil
  PlayerMapMarker._OBHeadWidgetLoadFailed = false
  PlayerMapMarker._cachedViewportW = 1920
  PlayerMapMarker._cachedViewportH = 1080
end

-- ====================================================================
-- MAIN ESP UPDATE
-- ====================================================================
function PlayerMapMarker.UpdateESP(AllPlayers, MyLoc)
  if not PlayerMapMarker.bUseScreenESP then return end
  PlayerMapMarker.bUseSnapLines = _G.LexusConfig.Esp9_Line
  PlayerMapMarker.bUseSkeleton = _G.LexusConfig.Esp9_Skeleton
  if not PlayerMapMarker.InitESPCanvas() then return end
  if PlayerMapMarker._OBHeadWidgetLoadFailed then return end
  local PC = PlayerMapMarker.GetMyPlayerController()
  if Valid(PC) then PlayerMapMarker.UpdateCanvasTransform(PC) end
  local fromX, fromY = 0, 0
  if PlayerMapMarker.bUseSnapLines and Valid(PC) then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end
  local MyKey = PlayerMapMarker.GetMyPlayerKey()
  local Seen = {}
  local MyChar = nil
  pcall(function()
    local GDP = _G.getCachedGameplayData()
    if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter()
    elseif PC and PC.GetPawn then MyChar = PC:GetPawn() end
  end)
  local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)
  for PlayerKey, Character in pairs(AllPlayers) do
    if Valid(Character) then
      local bMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
      local bAI = PlayerMapMarker.IsAI(Character)
      local KeyStr = tostring(PlayerKey)
      local Name = PlayerMapMarker.GetPlayerName(Character)
      local Loc = PlayerMapMarker.GetESPLocation(Character)
      local DistStr = ""
      if MyLoc and Loc then DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc) end
      local bSkip = false
      if bMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
      if bAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
      local TeamID = PlayerMapMarker.GetTeamID(Character)
      if MyTeamID ~= nil and TeamID == MyTeamID and not bMe then bSkip = true end
      local bAlive = PlayerMapMarker.IsAlive(Character)
      if not bSkip and Loc then
        Seen[KeyStr] = true
        local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]
        local Text = ""
        if _G.LexusConfig.Esp9_Name then Text = Name end
        if _G.LexusConfig.Esp9_Distance and DistStr ~= "" then
          if Text ~= "" then Text = string.format("%s [%s]", Text, DistStr) else Text = string.format("[%s]", DistStr) end
        end
        local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
        if not ESPData then
          local W = PlayerMapMarker.CreateESPWidget()
          if W then
            PlayerMapMarker.ESPWidgets[KeyStr] = {
              Widget = W, Character = Character, Name = Name, LastDistStr = DistStr, TeamID = TeamID,
            }
            PlayerMapMarker.UpdateESPText(W, Text)
            if bAlive then
              PlayerMapMarker.UpdateESPPositionWithPC(W, Loc, PC, CanvasPos)
              PlayerMapMarker.ApplyTeamColor(W, TeamID)
              PlayerMapMarker.AddWeaponIconToESP(W, Character)
              local HP = Character.Health or 0
              local MaxHP = Character.MaxHealth or 120
              local pct = (HP > 0 and MaxHP > 0) and math.min(1, HP / MaxHP) or 0
              PlayerMapMarker.UpdateESPHealth(W, pct)
              if PlayerMapMarker.bUseSnapLines then PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
              else PlayerMapMarker.RemoveSnapLine(KeyStr) end
              if PlayerMapMarker.bUseSkeleton then
                PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(TeamID), bOnScreen, Loc)
              else PlayerMapMarker.RemoveSkeletonLines(KeyStr) end
            else
              local C = W.Container or W
              pcall(function() C:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
              PlayerMapMarker.RemoveSnapLine(KeyStr)
              PlayerMapMarker.RemoveSkeletonLines(KeyStr)
            end
          end
        else
          ESPData.Character = Character
          ESPData.Name = Name
          ESPData.LastDistStr = DistStr
          if bAlive then
            ESPData.TeamID = TeamID
            ESPData.Widget._LastESPText = nil
            PlayerMapMarker.UpdateESPText(ESPData.Widget, Text)
            PlayerMapMarker.UpdateESPPositionWithPC(ESPData.Widget, Loc, PC, CanvasPos)
            PlayerMapMarker.ApplyTeamColor(ESPData.Widget, TeamID)
            PlayerMapMarker.AddWeaponIconToESP(ESPData.Widget, Character)
            local HP = Character.Health or 0
            local MaxHP = Character.MaxHealth or 120
            local pct = (HP > 0 and MaxHP > 0) and math.min(1, HP / MaxHP) or 0
            PlayerMapMarker.UpdateESPHealth(ESPData.Widget, pct)
            if PlayerMapMarker.bUseSnapLines then PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
            else PlayerMapMarker.RemoveSnapLine(KeyStr) end
            if PlayerMapMarker.bUseSkeleton then
              PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(TeamID), bOnScreen, Loc)
            else PlayerMapMarker.RemoveSkeletonLines(KeyStr) end
          else
            local C = ESPData.Widget.Container or ESPData.Widget
            pcall(function() C:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            PlayerMapMarker.RemoveSnapLine(KeyStr)
            PlayerMapMarker.RemoveSkeletonLines(KeyStr)
          end
        end
      end
    end
  end
  for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
    if not Seen[KeyStr] then
      PlayerMapMarker.RemoveESPWidget(Data.Widget, KeyStr)
      PlayerMapMarker.ESPWidgets[KeyStr] = nil
    end
  end
end

function PlayerMapMarker.UpdateESPLight()
  if _G.TickFrame then _G.TickFrame() end
  if not PlayerMapMarker.bUseScreenESP then return end
  PlayerMapMarker.bUseSnapLines = _G.LexusConfig.Esp9_Line
  PlayerMapMarker.bUseSkeleton = _G.LexusConfig.Esp9_Skeleton
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not Valid(PC) then return end
  PlayerMapMarker.UpdateCanvasTransform(PC)
  local fromX, fromY = 0, 0
  if PlayerMapMarker.bUseSnapLines then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end
  for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
    local W = ESPData.Widget
    local C = W and (W.Container or W)
    if W and C and slua.isValid(C) and ESPData.Character and Valid(ESPData.Character) then
      if not PlayerMapMarker.IsAlive(ESPData.Character) then
        C:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        PlayerMapMarker.RemoveSnapLine(KeyStr)
        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
      else
        local bShow = _G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP or _G.LexusConfig.Esp9_Team or _G.LexusConfig.Esp9_Weapon
        if bShow then C:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        else C:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        local Loc = PlayerMapMarker.GetESPLocation(ESPData.Character)
        if Loc then
          local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
          PlayerMapMarker.UpdateESPPositionWithPC(W, Loc, PC, CanvasPos)
          if PlayerMapMarker.bUseSnapLines then PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
          else PlayerMapMarker.RemoveSnapLine(KeyStr) end
          if PlayerMapMarker.bUseSkeleton then
            PlayerMapMarker.UpdateSkeletonLines(KeyStr, ESPData.Character, PC, true, PlayerMapMarker.GetTeamColor(ESPData.TeamID), bOnScreen, Loc)
          else PlayerMapMarker.RemoveSkeletonLines(KeyStr) end
        end
      end
    end
  end
end

function PlayerMapMarker.UpdateESPDistances()
  if _G.TickFrame then _G.TickFrame() end
  if not PlayerMapMarker.bUseScreenESP then return end
  local MyLoc = PlayerMapMarker.GetMyLocation()
  if not MyLoc then return end
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not Valid(PC) then return end
  PlayerMapMarker.UpdateCanvasTransform(PC)
  for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
    local C = ESPData.Widget and ESPData.Widget.Container
    if ESPData.Character and Valid(ESPData.Character) and C and slua.isValid(C) then
      local Loc = PlayerMapMarker.GetESPLocation(ESPData.Character)
      if Loc and PlayerMapMarker.bShowDistance then
        local DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc)
        local Name = ESPData.Name or "Unknown"
        local Text = ""
        if _G.LexusConfig.Esp9_Name then Text = Name end
        if _G.LexusConfig.Esp9_Distance and DistStr ~= "" then
          if Text ~= "" then Text = string.format("%s [%s]", Text, DistStr) else Text = string.format("[%s]", DistStr) end
        end
        ESPData.LastDistStr = DistStr
        ESPData.Widget._LastESPText = nil
        PlayerMapMarker.UpdateESPText(ESPData.Widget, Text)
      end
    end
  end
end

function PlayerMapMarker.ScanAndUpdate()
  local AllChars = PlayerMapMarker.GetAllCharacters()
  if not AllChars then return 0 end
  local MyLoc = PlayerMapMarker.GetMyLocation()
  if PlayerMapMarker.bUseScreenESP then PlayerMapMarker.UpdateESP(AllChars, MyLoc) end
  return 0
end

function PlayerMapMarker.AttachTimers()
  pcall(function()
    local pc = PlayerMapMarker.GetMyPlayerController()
    if not slua.isValid(pc) or not pc.AddGameTimer then return end
    local now = os.time()
    if PlayerMapMarker._LastAttach and (now - PlayerMapMarker._LastAttach) < 5 then return end
    PlayerMapMarker._LastAttach = now
    pcall(function() pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.35, true, function() if PlayerMapMarker.bActive then pcall(PlayerMapMarker.ScanAndUpdate) end end) end)
    pcall(function() pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.02, true, function() if PlayerMapMarker.bActive then pcall(PlayerMapMarker.UpdateESPLight) end end) end)
    pcall(function() pc:AddGameTimer(PlayerMapMarker._DistanceUpdateInterval or 0.1, true, function() if PlayerMapMarker.bActive and PlayerMapMarker.bShowDistance then pcall(PlayerMapMarker.UpdateESPDistances) end end) end)
  end)
end

function PlayerMapMarker.Start()
  if PlayerMapMarker.bActive then return end
  PlayerMapMarker.bActive = true
  PlayerMapMarker.ScanAndUpdate()
  PlayerMapMarker.AttachTimers()
end

function PlayerMapMarker.Stop()
  PlayerMapMarker.bActive = false
  PlayerMapMarker.ClearAllESP()
end

_G.PlayerMapMarker = PlayerMapMarker

-- ====================================================================
-- RED BOX OVERLAY (player/bot counter)
-- ====================================================================
local RedBoxOverlay = {
  bActive = false, MainContainer = nil, WidgetSlot = nil,
  TextBlockPlayer = nil, TextBlockBot = nil,
  Width = 260, Height = 28, FontSize = 14,
  PlayerCount = 0, BotCount = 0, NumLayers = 50,
  Red = 1.0, Green = 0.0, Blue = 0.0, LayerAlpha = 0.038
}

function RedBoxOverlay.Create()
  if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return true end
  local ParentCanvas = PlayerMapMarker.ESPCanvas
  if not ParentCanvas or not slua.isValid(ParentCanvas) then
    if not PlayerMapMarker.InitESPCanvas() then return false end
    ParentCanvas = PlayerMapMarker.ESPCanvas
  end
  if not ParentCanvas then return false end
  local C = nil
  pcall(function() C = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas) end)
  if not C or not slua.isValid(C) then return false end
  local color = FLinearColor(RedBoxOverlay.Red, RedBoxOverlay.Green, RedBoxOverlay.Blue, RedBoxOverlay.LayerAlpha)
  for i = 1, RedBoxOverlay.NumLayers do
    local prog = (i / RedBoxOverlay.NumLayers) ^ 1.15
    local lw = prog * RedBoxOverlay.Width
    local lx = (RedBoxOverlay.Width - lw) / 2.0
    local B = nil
    pcall(function() B = CGame:NewObjectFromPath("/Script/UMG.Border", C) end)
    if B and slua.isValid(B) then
      pcall(function() B:SetBrushColor(color); B:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      local s = C:AddChildToCanvas(B)
      if s then s:SetPosition(FVector2D(lx, 0)); s:SetSize(FVector2D(lw, RedBoxOverlay.Height)) end
    end
  end
  local FS = import("SlateColor")
  local function mkText(x, y, init)
    local T = nil
    pcall(function() T = CGame:NewObjectFromPath("/Script/UMG.TextBlock", C) end)
    if not T or not slua.isValid(T) then return nil end
    pcall(function()
      T:SetText(init)
      local wc = FLinearColor(1,1,1,1)
      if FS then T:SetColorAndOpacity(FS(wc)) else T:SetColorAndOpacity(wc) end
      if T.Font then local f = T.Font; f.Size = RedBoxOverlay.FontSize; T.Font = f end
      T:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    local s = C:AddChildToCanvas(T)
    if s then
      pcall(function()
        s:SetAutoSize(true); s:SetAlignment(FVector2D(0.5, 0.5))
        s:SetPosition(FVector2D(x, y)); s:SetZOrder(1000)
      end)
    end
    return T
  end
  RedBoxOverlay.TextBlockPlayer = mkText(RedBoxOverlay.Width * 0.25, RedBoxOverlay.Height * 0.5, "REAL 0")
  RedBoxOverlay.TextBlockBot = mkText(RedBoxOverlay.Width * 0.75, RedBoxOverlay.Height * 0.5, "BOT 0")
  local slot = nil
  pcall(function() slot = ParentCanvas:AddChildToCanvas(C) end)
  if not slot then return false end
  RedBoxOverlay.MainContainer = C
  RedBoxOverlay.WidgetSlot = slot
  pcall(function()
    slot:SetAutoSize(false); slot:SetZOrder(999)
    slot:SetAlignment(FVector2D(0.5, 1.0))
    slot:SetSize(FVector2D(RedBoxOverlay.Width, RedBoxOverlay.Height))
  end)
  RedBoxOverlay.UpdatePosition()
  return true
end

function RedBoxOverlay.SetCounts(players, bots)
  if RedBoxOverlay.PlayerCount == players and RedBoxOverlay.BotCount == bots then return end
  RedBoxOverlay.PlayerCount = players or 0
  RedBoxOverlay.BotCount = bots or 0
  if RedBoxOverlay.TextBlockPlayer and slua.isValid(RedBoxOverlay.TextBlockPlayer) then
    pcall(function() RedBoxOverlay.TextBlockPlayer:SetText(string.format("REAL %d", RedBoxOverlay.PlayerCount)) end)
  end
  if RedBoxOverlay.TextBlockBot and slua.isValid(RedBoxOverlay.TextBlockBot) then
    pcall(function() RedBoxOverlay.TextBlockBot:SetText(string.format("BOT %d", RedBoxOverlay.BotCount)) end)
  end
end

function RedBoxOverlay.UpdatePosition()
  local slot = RedBoxOverlay.WidgetSlot
  if not slot or not slua.isValid(slot) then return end
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not Valid(PC) then return end
  local fx, fy = PlayerMapMarker.GetSnapLineStartPos(PC)
  pcall(function() slot:SetPosition(FVector2D(fx, fy + 2)) end)
end

function RedBoxOverlay.Start()
  if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return end
  if RedBoxOverlay.Create() then
    RedBoxOverlay.bActive = true
    pcall(function() RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
  end
end

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
end

_G.RedBoxOverlay = RedBoxOverlay

-- ====================================================================
-- CHAMS (wallhack only — outline removed)
-- ====================================================================
local function ApplyColorBodyNew(enemy, markData)
  _G.Safe("chams_apply", function()
    if not _G.ConsoleNewWallReady then
      local KSL = import("KismetSystemLibrary")
      local world = slua.getWorld()
      if KSL and world then
        KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
        _G.ConsoleNewWallReady = true
      end
    end
    local meshes = _G.GetAllSkeletalMeshes(enemy, markData)
    local w = nil
    pcall(function() w = enemy:GetCurrentWeapon() end)
    if Valid(w) and Valid(w.Mesh) then table.insert(meshes, w.Mesh) end
    local isBot = markData.AK_IS_BOT or false
    local hash = (isBot and "BOT" or "PL") .. "_" .. tostring(#meshes)
    if markData.LastChamsHash == hash and markData.ChamsApplied then return end
    markData.LastChamsHash = hash
    markData.ChamsApplied = true
    local LC = _G.getCachedLinearColor()
    local c_vis = LC and LC(0, 100, 0, 1) or {R=0,G=100,B=0,A=1}
    local c_occ = LC and LC(100, 0, 0, 1) or {R=100,G=0,B=0,A=1}
    local c_bVis = LC and LC(49, 48, 0, 100) or {R=49,G=48,B=0,A=100}
    local c_bOcc = LC and LC(9, 1.5, 45, 100) or {R=9,G=1.5,B=45,A=100}
    local vis = isBot and c_bVis or c_vis
    local occ = isBot and c_bOcc or c_occ
    for _, m in ipairs(meshes) do
      if Valid(m) then
        pcall(function()
          if type(m.SetDrawDyeing) == "function" then
            m:SetDrawDyeing(true); m:SetDrawDyeingMode(1)
            m:SetVisibleDyeingColor(vis); m:SetOccludedDyeingColor(occ)
            m:SetDyeingColorFadeDistance(99999.0); m:SetDyeingColorMinMaxDistance(0.0, 99999.0)
            m:SetDrawHighlight(true); m:OverrideHighlightColor(vis); m:SetHighlightCanBeOccluded(false)
            m:SetDrawIdeaOutline(true); m:SetIdeaOutlineNew(true); m:SetIdeaOutlineOcclusionHighlight(true)
            m:OverrideIdeaOutlineColor(vis); m:SetIdeaOutlineOcclusionColor(occ)
            m:OverrideIdeaOutlineThickness(20.0); m:SetIdeaOverrideOutlineAndOcclusion(true)
            m:SetRenderCustomDepth(true); m:SetCustomDepthStencilValue(255)
          end
        end)
      end
    end
  end)
end

local function UndoColorBodyNew(enemy, markData)
  _G.Safe("chams_undo", function()
    if markData.ChamsApplied then
      local meshes = _G.GetAllSkeletalMeshes(enemy, markData)
      local w = nil
      pcall(function() w = enemy:GetCurrentWeapon() end)
      if Valid(w) and Valid(w.Mesh) then table.insert(meshes, w.Mesh) end
      for _, m in ipairs(meshes) do
        if Valid(m) then
          pcall(function()
            if type(m.SetDrawDyeing) == "function" then
              m:SetDrawDyeing(false); m:SetDrawHighlight(false); m:SetDrawIdeaOutline(false); m:SetRenderCustomDepth(false)
            end
          end)
        end
      end
      markData.ChamsApplied = false
      markData.LastChamsHash = ""
    end
  end)
end

-- ====================================================================
-- HUD ESP
-- ====================================================================
_G.Cached_MyHUD = nil
local function EnsureHUD()
  if Valid(_G.Cached_MyHUD) then return _G.Cached_MyHUD end
  pcall(function()
    local GD = _G.getCachedGameplayData()
    if GD then
      local hud = GD.GetMyHUD and GD.GetMyHUD()
      if Valid(hud) then _G.Cached_MyHUD = hud end
    end
  end)
  return _G.Cached_MyHUD
end

local function ApplyHUDText(enemy, markData, distM, localPlayer)
  local HUD = EnsureHUD()
  if not Valid(HUD) then return end

  if _G.LexusConfig.EspAntenna and distM <= 400 then
    for i = 1, 8 do
      local z = 105 + (i * 1000)
      HUD:AddDebugText("|", enemy, 0.06, {X=0,Y=0,Z=z}, {X=0,Y=0,Z=z}, _G.C_GREEN, true, false, true, nil, 1.2, true)
    end
    HUD:AddDebugText("I", enemy, 0.06, {X=0,Y=0,Z=9060}, {X=0,Y=0,Z=9060}, _G.C_GREEN, true, false, true, nil, 1.5, true)
  end

  if _G.LexusConfig.EspDistance and distM <= 400 then
    local sc = math.max(0.55, 0.95 - (distM / 400))
    -- RED HUD distance
    HUD:AddDebugText(string.format("[%dm]", math.floor(distM)), enemy, 0.06, {X=0,Y=115,Z=20}, {X=0,Y=115,Z=20}, _G.C_RED_TEXT, true, false, true, nil, sc * 1.5, true)
  end

  if _G.LexusConfig.EspVipPro and distM <= 400 then
    local sc = math.max(0.55, 0.95 - (distM / 400))
    local hp, mhp = 100, 100
    pcall(function()
      if enemy.Health then hp = enemy.Health end
      if enemy.HealthMax then mhp = enemy.HealthMax end
    end)
    if mhp <= 0 then mhp = 100 end
    local ratio = hp / mhp
    local isKnock = (hp <= 0 and enemy.HealthStatus == 1)
    local hpCol = isKnock and _G.C_RED or _G.C_RED_TEXT
    local name = "Enemy"
    pcall(function() if enemy.PlayerName then name = enemy.PlayerName end end)
    if isKnock then name = "KNOCK: " .. name end
    HUD:AddDebugText(name, enemy, 0.06, {X=0,Y=0,Z=-370}, {X=0,Y=0,Z=-370}, _G.C_RED_TEXT, true, false, true, nil, sc * 1.1, true)
    if not isKnock then
      local seg = 6
      local filled = math.floor(ratio * seg)
      local startZ = 20
      local spacing = 10.0 * sc
      for j = 1, seg do
        local c = (j <= filled) and hpCol or {R=40,G=4,B=4,A=180}
        HUD:AddDebugText("▮", enemy, 0.06, {X=0,Y=-115,Z=startZ + (j*spacing)}, {X=0,Y=-115,Z=startZ + (j*spacing)}, c, true, false, true, nil, sc * 1.2, true)
      end
      HUD:AddDebugText(string.format("%d%%", math.floor(ratio * 100)), enemy, 0.06, {X=0,Y=-60,Z=startZ - 12}, {X=0,Y=-60,Z=startZ - 12}, hpCol, true, false, true, nil, sc * 0.8, true)
    else
      HUD:AddDebugText("DOWN", enemy, 0.06, {X=0,Y=-115,Z=50}, {X=0,Y=-115,Z=50}, _G.C_RED, true, false, true, nil, sc, true)
    end
  end
end

-- ====================================================================
-- NATIVE ESP
-- ====================================================================
function _G.InitializeNativeESP()
  if _G.LexusState.NativeESPReady then return end
  _G.Safe("native_esp", function()
    local GPT = _G.GetModule("GameLua.Mod.BaseMod.Common.GamePlayTools")
    if not GPT then return end
    local cfg = GPT.GetCurrentConfig("ScreenMarkConfig")
    if not cfg then return end
    if cfg[1006] then
      cfg[1006].bBindBlocked = true; cfg[1006].bBindOutScreen = true
      cfg[1006].MaxWidgetNum = 99; cfg[1006].MaxShowDistance = 6000000
      cfg[1006].bScaleByDistance = false; cfg[1006].BindSocketName = "root"
      cfg[1006].bUseLuaWorldSocketName = true; cfg[1006].WorldPositionOffset = FVector(0, 0, -30)
    end
  end)
  _G.LexusState.NativeESPReady = true
end

function _G.ProcessEnemyESP(enemy, markData, localPlayer, distM)
  _G.Safe("enemy_esp", function()
    local dead = false
    pcall(function()
      if type(enemy.IsDead) == "function" then dead = enemy:IsDead()
      elseif enemy.bIsDead ~= nil then dead = enemy.bIsDead end
      if enemy.HealthStatus == 2 then dead = true end
    end)

    if dead then
      UndoColorBodyNew(enemy, markData)
      markData.Cleaned = true
      return
    end

    if markData.Cleaned then markData.Cleaned = false end

    if _G.LexusConfig.ColorBodyNew then ApplyColorBodyNew(enemy, markData)
    else UndoColorBodyNew(enemy, markData) end
    ApplyHUDText(enemy, markData, distM, localPlayer)
  end)
end

function _G.StartESP()
  if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then _G.PlayerMapMarker.Start() end
end

function _G.StopESP()
  if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then _G.PlayerMapMarker.Stop() end
  if _G.RedBoxOverlay and _G.RedBoxOverlay.bActive then _G.RedBoxOverlay.Stop() end
end

function _G.UpdateRedBox(realPlayers, bots)
  if _G.LexusConfig.Esp9_Count then
    if _G.RedBoxOverlay.bActive then _G.RedBoxOverlay.SetCounts(realPlayers, bots)
    else _G.RedBoxOverlay.Start() end
  else
    if _G.RedBoxOverlay.bActive then _G.RedBoxOverlay.Stop() end
  end
end

print("[TESLA10X] Part 2/4 loaded — ESP (RED theme) + Wallhack (Chams only, no Outline)")

-- ====================================================================
-- TESLA 10X — Part 3/4: Combat + Visuals + Mod Menu
-- AIMBOT FIXED (toggle only, internal smooth/range/bone)
-- No Recoil + Crosshair + FPS (30-265) + iPad View
-- ====================================================================

-- ====================================================================
-- NO RECOIL
-- ====================================================================
_G.recoilOriginalCache = _G.recoilOriginalCache or setmetatable({}, { __mode = "k" })
_G.RECOIL_FIELDS = { "RecoilKick", "RecoilKickADS", "AnimationKick", "GameDeviationFactor", "RecoilModifierStand", "RecoilModifierCrouch", "RecoilModifierProne", "CameraShakeScale", "AimCameraShakeScale", "ShootCameraShakeScale", "FireCameraShakeScale", "GameDeviationAccuracy", "ShotGunHorizontalSpread", "ShotGunVerticalSpread", "DeviationMultiplier" }
_G.RECOIL_TARGET_VALUES = { RecoilKick=0.01, RecoilKickADS=0.01, AnimationKick=0.01, GameDeviationFactor=0.01, RecoilModifierStand=0.01, RecoilModifierCrouch=0.01, RecoilModifierProne=0.01, CameraShakeScale=0.01, AimCameraShakeScale=0.01, ShootCameraShakeScale=0.01, FireCameraShakeScale=0.01, GameDeviationAccuracy=0.01, ShotGunHorizontalSpread=0.01, ShotGunVerticalSpread=0.01, DeviationMultiplier=0.01 }
_G.RECOIL_INFO_FIELDS = { "VerticalRecoilMin", "VerticalRecoilMax", "RecoilSpeedVertical", "RecoilSpeedHorizontal", "VerticalRecoveryMax" }
_G.RECOIL_INFO_TARGET = { VerticalRecoilMin=0.01, VerticalRecoilMax=0.01, RecoilSpeedVertical=0.01, RecoilSpeedHorizontal=0.01, VerticalRecoveryMax=0.01 }

_G.ApplyNoRecoil = function()
  _G.Safe("norecoil", function()
    local GD = _G.getCachedGameplayData()
    if not GD or not GD.GetPlayerController then return end
    local pc = GD.GetPlayerController()
    if not Valid(pc) then return end
    local char = pc:GetPlayerCharacterSafety()
    if not Valid(char) then return end
    local wm = char.WeaponManagerComponent
    if not wm then return end
    local weapon = wm.CurrentWeaponReplicated
    if not weapon then return end
    local entity = weapon.ShootWeaponEntityComp
    if not Valid(entity) then return end

    if not _G.LexusConfig.NoRecoilEnabled then
      if _G.recoilOriginalCache[entity] then
        local saved = _G.recoilOriginalCache[entity]
        for k, v in pairs(saved) do
          if k == "RecoilInfo" then
            if entity.RecoilInfo then for rk, rv in pairs(v) do entity.RecoilInfo[rk] = rv end end
          elseif k == "ShootCameraShakeScale" then
            if entity.ShootCameraShake then entity.ShootCameraShake.Scale = v end
          else entity[k] = v end
        end
        _G.recoilOriginalCache[entity] = nil
      end
      return
    end

    if not _G.recoilOriginalCache[entity] then
      local saved = { RecoilInfo = {} }
      for _, f in ipairs(_G.RECOIL_FIELDS) do if entity[f] ~= nil then saved[f] = entity[f] end end
      if entity.RecoilInfo then for _, f in ipairs(_G.RECOIL_INFO_FIELDS) do if entity.RecoilInfo[f] ~= nil then saved.RecoilInfo[f] = entity.RecoilInfo[f] end end end
      if entity.ShootCameraShake then saved.ShootCameraShakeScale = entity.ShootCameraShake.Scale end
      _G.recoilOriginalCache[entity] = saved
    end
    local orig = _G.recoilOriginalCache[entity]
    if not orig then return end
    local slider = (_G.LexusConfig.RecoilReduction or 100) / 100
    if slider > 1 then slider = 1 end
    if slider < 0 then slider = 0 end
    for _, f in ipairs(_G.RECOIL_FIELDS) do
      if entity[f] ~= nil and orig[f] ~= nil and _G.RECOIL_TARGET_VALUES[f] then
        entity[f] = orig[f] + (_G.RECOIL_TARGET_VALUES[f] - orig[f]) * slider
      end
    end
    if entity.RecoilInfo then
      for _, f in ipairs(_G.RECOIL_INFO_FIELDS) do
        if entity.RecoilInfo[f] ~= nil and orig.RecoilInfo and orig.RecoilInfo[f] ~= nil and _G.RECOIL_INFO_TARGET[f] then
          entity.RecoilInfo[f] = orig.RecoilInfo[f] + (_G.RECOIL_INFO_TARGET[f] - orig.RecoilInfo[f]) * slider
        end
      end
    end
    if entity.ShootCameraShake then
      local origScale = orig.ShootCameraShakeScale or 1.0
      entity.ShootCameraShake.Scale = origScale + (0.01 - origScale) * slider
    end
  end)
end

-- ====================================================================
-- AIMBOT (FIXED — toggle only, internal settings)
-- - smoothness: 0.85 (very smooth)
-- - range: 100m fixed
-- - bone: neck (60%) or chest (40%) — head NEVER (too obvious)
-- - FOV: 30°
-- - visibility check: ON
-- - ignores bots & knocked
-- - no scope-only
-- ====================================================================
_G.AimbotState = _G.AimbotState or {
  LastTarget = nil,
  LastBone = "neck_01",
  LastLockTime = 0,
}

local AIMBOT_BONES = {
  neck = { "neck_01", "Neck_01", "neck" },
  chest = { "spine_03", "Spine_03", "spine_02", "Spine_02", "spine_01", "Spine_01", "spine" }
}

-- ============================================================
-- [UPGRADE] Weapon Aimbot — game native AutoAimingConfig tweak
-- ============================================================
_G._WAimBackup = _G._WAimBackup or setmetatable({}, { __mode = "k" })

_G.ApplyWeaponAimbot = function()
  _G.Safe("weapon_aimbot", function()
    local GD = _G.getCachedGameplayData()
    if not GD or not GD.GetPlayerController then return end
    local pc = GD.GetPlayerController()
    if not Valid(pc) then return end
    local char = pc:GetPlayerCharacterSafety()
    if not Valid(char) then return end
    local wm = char.WeaponManagerComponent
    if not Valid(wm) then return end
    local weapon = wm.CurrentWeaponReplicated
    if not Valid(weapon) then return end
    local entity = weapon.ShootWeaponEntityComp
    if not Valid(entity) then return end

    -- TOGGLE OFF: restore
    if not _G.LexusConfig.WeaponAimbot then
      local saved = _G._WAimBackup[entity]
      if saved and entity.AutoAimingConfig then
        for rname, fields in pairs(saved) do
          local cfg = entity.AutoAimingConfig[rname]
          if cfg then for k, v in pairs(fields) do cfg[k] = v end end
        end
        _G._WAimBackup[entity] = nil
      end
      return
    end

    -- TOGGLE ON: backup then apply
    if not _G._WAimBackup[entity] and entity.AutoAimingConfig then
      local saved = {}
      for _, rname in ipairs({"OuterRange", "InnerRange"}) do
        local cfg = entity.AutoAimingConfig[rname]
        if cfg then
          saved[rname] = {
            Speed = cfg.Speed, RangeRate = cfg.RangeRate, SpeedRate = cfg.SpeedRate,
            RangeRateSight = cfg.RangeRateSight, SpeedRateSight = cfg.SpeedRateSight,
            CrouchRate = cfg.CrouchRate, ProneRate = cfg.ProneRate, DyingRate = cfg.DyingRate,
          }
        end
      end
      _G._WAimBackup[entity] = saved
    end

    if entity.AutoAimingConfig then
      for _, range in ipairs({"OuterRange", "InnerRange"}) do
        local cfg = entity.AutoAimingConfig[range]
        if cfg then
          cfg.Speed = 10
          cfg.RangeRate = 2
          cfg.SpeedRate = 4
          cfg.RangeRateSight = 2
          cfg.SpeedRateSight = 4
          cfg.CrouchRate = 2
          cfg.ProneRate = 2
          cfg.DyingRate = 2
        end
      end
    end
    local aimComp = char.BP_AutoAimingComponent_C or char.BP_AutoAimingComponent
    if Valid(aimComp) and aimComp.Bones then
      aimComp.Bones = {"head", "head", "head"}
    end
  end)
end

-- ============================================================
-- [UPGRADE] Auto Head — Scope-aware (hipfire=chest, scope=head)
-- ============================================================
_G.ApplyAutoHeadScope = function()
  _G.Safe("auto_head_scope", function()
    if not _G.LexusConfig.AutoHead then return end
    local GD = _G.getCachedGameplayData()
    if not GD or not GD.GetPlayerController then return end
    local pc = GD.GetPlayerController()
    if not Valid(pc) then return end
    local localChar = pc:GetPlayerCharacterSafety()
    if not Valid(localChar) then return end
    local localLoc = nil
    pcall(function() localLoc = localChar:K2_GetActorLocation() end)
    if not localLoc then return end
    local myTeamID = localChar.TeamID

    local isScoped = false
    pcall(function()
      local cam = localChar.ThirdPersonCameraComponent
      if Valid(cam) and cam.FieldOfView then
        isScoped = cam.FieldOfView < 60
      end
    end)

    local maxDist = isScoped and 50000 or 25000
    local closestEnemy = nil
    local closestDist = 99999999
    local allChars = GD.GetAllPlayerCharacters and GD.GetAllPlayerCharacters() or {}
    for _, enemy in pairs(allChars) do
      if Valid(enemy) and enemy ~= localChar and enemy.TeamID ~= myTeamID then
        local bDead = false
        pcall(function()
          if type(enemy.IsDead) == "function" then bDead = enemy:IsDead()
          elseif enemy.bIsDead ~= nil then bDead = enemy.bIsDead end
        end)
        if not bDead then
          local eLoc = nil
          pcall(function() eLoc = enemy:K2_GetActorLocation() end)
          if eLoc then
            local dx = (eLoc.X or 0) - (localLoc.X or 0)
            local dy = (eLoc.Y or 0) - (localLoc.Y or 0)
            local dz = (eLoc.Z or 0) - (localLoc.Z or 0)
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist < closestDist then
              closestDist = dist
              closestEnemy = enemy
            end
          end
        end
      end
    end
    if not closestEnemy or closestDist > maxDist then return end

    local targetLoc = nil
    pcall(function()
      local mesh = closestEnemy.Mesh
      if Valid(mesh) and type(mesh.GetSocketLocation) == "function" then
        if isScoped then
          targetLoc = mesh:GetSocketLocation("head")
        else
          targetLoc = mesh:GetSocketLocation("spine_02")
          if not targetLoc then targetLoc = closestEnemy:K2_GetActorLocation() end
          if targetLoc then targetLoc.Z = targetLoc.Z + 100 end
        end
      end
    end)
    if not targetLoc then
      pcall(function() targetLoc = closestEnemy:K2_GetActorLocation() end)
      if targetLoc then targetLoc.Z = targetLoc.Z + (isScoped and 180 or 100) end
    end
    if not targetLoc then return end

    local myCam = localChar.ThirdPersonCameraComponent
    if not Valid(myCam) then return end
    local camLoc = nil
    pcall(function() camLoc = myCam:K2_GetComponentLocation() end)
    if not camLoc then return end

    local dirX = (targetLoc.X or 0) - (camLoc.X or 0)
    local dirY = (targetLoc.Y or 0) - (camLoc.Y or 0)
    local dirZ = (targetLoc.Z or 0) - (camLoc.Z or 0)
    local len = math.sqrt(dirX*dirX + dirY*dirY + dirZ*dirZ)
    if len <= 0 then return end

    local rot = nil
    pcall(function()
      local FRotator = import("Rotator")
      local pitch = math.deg(math.asin(dirZ / len))
      local yaw = math.deg(_G.atan2(dirY, dirX))
      if isScoped then
        rot = FRotator and FRotator(-pitch, yaw, 0) or {Pitch = -pitch, Yaw = yaw, Roll = 0}
      else
        local curRot = pc:GetControlRotation()
        if curRot then
          local curPitch = curRot.Pitch or 0
          local curYaw = curRot.Yaw or 0
          local blend = 0.35
          local newPitch = curPitch + (-pitch - curPitch) * blend
          local newYaw = curYaw + (yaw - curYaw) * blend
          rot = FRotator and FRotator(newPitch, newYaw, 0) or {Pitch = newPitch, Yaw = newYaw, Roll = 0}
        else
          rot = FRotator and FRotator(-pitch, yaw, 0) or {Pitch = -pitch, Yaw = yaw, Roll = 0}
        end
      end
    end)
    if rot then pcall(function() pc:SetControlRotation(rot) end) end
  end)
end

-- ============================================================
-- [UPGRADE] ESP Info (Weapon + Pose)
-- ============================================================
_G.ApplyESPInfo = function(enemy, markData, distM)
  if not _G.LexusConfig.EspInfo then return end
  if not Valid(enemy) then return end
  local HUD = _G.Cached_MyHUD
  if not Valid(HUD) then
    pcall(function()
      local GD = _G.getCachedGameplayData()
      if GD then
        local h = GD.GetMyHUD and GD.GetMyHUD()
        if Valid(h) then _G.Cached_MyHUD = h; HUD = h end
      end
    end)
    if not Valid(HUD) then return end
  end
  if distM > 400 then return end

  local stateText = ""
  if _G.LexusConfig.EspInfo_Pose then
    local pose = nil
    pcall(function() pose = enemy.PoseState or (type(enemy.GetPoseState) == "function" and enemy:GetPoseState()) end)
    if pose == 0 or pose == "Stand" then stateText = "Stand"
    elseif pose == 1 or pose == "Crouch" then stateText = "Crouch"
    elseif pose == 2 or pose == "Prone" then stateText = "Prone"
    else stateText = "Stand" end
  end
  if _G.LexusConfig.EspInfo_Weapon then
    local now = os.clock()
    if not markData.WepTime or now > markData.WepTime + 1.5 then
      local w = nil
      pcall(function() w = enemy.CurrentWeapon or enemy:GetCurrentWeapon() end)
      local wn = "Fists"
      if Valid(w) and type(w.GetWeaponName) == "function" then wn = w:GetWeaponName() end
      markData.CachedWep = tostring(wn)
      markData.WepTime = now
    end
    if stateText ~= "" then stateText = stateText .. " - " .. (markData.CachedWep or "Fists")
    else stateText = markData.CachedWep or "Fists" end
  end
  if stateText ~= "" then
    local isBot = markData.AK_IS_BOT or false
    local col = isBot and _G.C_CYAN or _G.C_YELLOW
    local sc = math.max(0.5, 0.8 - (distM / 400))
    HUD:AddDebugText(stateText, enemy, 0.06, {X=0,Y=0,Z=100}, {X=0,Y=0,Z=100}, col, true, false, true, nil, sc, true)
  end
end

_G.ApplyAimbot = function()
  _G.Safe("aimbot", function()
    if not _G.LexusConfig.AimbotEnabled then return end

    local GD = _G.getCachedGameplayData()
    if not GD or not GD.GetPlayerController then return end
    local pc = GD.GetPlayerController()
    if not Valid(pc) then return end
    local localChar = pc:GetPlayerCharacterSafety()
    if not Valid(localChar) then return end

    local localLoc = nil
    pcall(function() localLoc = localChar:K2_GetActorLocation() end)
    if not localLoc then return end

    local myTeamID = localChar.TeamID
    local maxDist = 10000           -- 100 meters in game units
    local fovDeg = 30                -- internal FOV cone
    local fovCos = math.cos(math.rad(fovDeg))

    local curRot = pc:GetControlRotation()
    if not curRot then return end
    local curPitch = curRot.Pitch or 0
    local curYaw = curRot.Yaw or 0
    local curPitchRad = math.rad(curPitch)
    local yawRad = math.rad(curYaw)
    local fwdX = math.cos(curPitchRad) * math.cos(yawRad)
    local fwdY = math.cos(curPitchRad) * math.sin(yawRad)
    local fwdZ = math.sin(curPitchRad)

    -- pick bone chain (neck / chest) — persists per target
    local boneList = AIMBOT_BONES.neck
    if _G.AimbotState.LastBone == "chest" then boneList = AIMBOT_BONES.chest end

    -- find best target
    local bestEnemy, bestScore, bestBoneLoc = nil, math.huge, nil
    local allChars = GD.GetAllPlayerCharacters and GD.GetAllPlayerCharacters() or {}
    for _, enemy in pairs(allChars) do
      if Valid(enemy) and enemy ~= localChar and enemy.TeamID ~= myTeamID then
        local skip = false
        pcall(function()
          if type(enemy.IsDead) == "function" and enemy:IsDead() then skip = true
          elseif enemy.bIsDead == true then skip = true end
          if enemy.HealthStatus == 1 or enemy.HealthStatus == 2 then skip = true end
        end)

        if not skip then
          -- ignore bots
          local isBot = _G.CheckIsAI(enemy, nil)
          if true then -- allow all (bots+players)
            local eLoc = nil
            pcall(function() eLoc = enemy:K2_GetActorLocation() end)
            if eLoc then
              local dx = (eLoc.X or 0) - (localLoc.X or 0)
              local dy = (eLoc.Y or 0) - (localLoc.Y or 0)
              local dz = (eLoc.Z or 0) - (localLoc.Z or 0)
              local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
              if dist <= maxDist and dist > 0 then
                local dot = (dx*fwdX + dy*fwdY + dz*fwdZ) / dist
                if dot >= fovCos then
                  local vis = true
                  pcall(function()
                    local FV = _G.FVector or import("Vector")
                    local zeroV = FV and FV(0, 0, 0) or {X=0, Y=0, Z=0}
                    vis = pc:LineOfSightTo(enemy, zeroV, true)
                  end)
                  if vis then
                    -- get bone location with fallbacks
                    local boneLoc = nil
                    pcall(function()
                      local mesh = enemy.Mesh
                      if Valid(mesh) and type(mesh.GetSocketLocation) == "function" then
                        for _, bn in ipairs(boneList) do
                          local ok, loc = pcall(function() return mesh:GetSocketLocation(bn) end)
                          if ok and loc then boneLoc = loc; break end
                        end
                      end
                    end)
                    if not boneLoc then
                      pcall(function() boneLoc = enemy:K2_GetActorLocation() end)
                      if boneLoc then
                        -- neck offset approx 130
                        if _G.AimbotState.LastBone == "neck" then
                          boneLoc.Z = boneLoc.Z + 130
                        else
                          boneLoc.Z = boneLoc.Z + 90
                        end
                      end
                    end
                    if boneLoc then
                      local score = dist * (2 - dot)
                      if score < bestScore then
                        bestScore = score; bestEnemy = enemy; bestBoneLoc = boneLoc
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    if not bestEnemy or not bestBoneLoc then return end

    -- lock bone choice per target (avoid jitter)
    if _G.AimbotState.LastTarget ~= bestEnemy then
      _G.AimbotState.LastTarget = bestEnemy
      _G.AimbotState.LastLockTime = os.clock()
      if math.random() < 0.6 then
        _G.AimbotState.LastBone = "neck"
      else
        _G.AimbotState.LastBone = "chest"
      end
    end

    -- camera location
    local camLoc = nil
    pcall(function()
      local camMgr = import("GameplayStatics").GetPlayerCameraManager(pc, 0)
      if Valid(camMgr) then camLoc = camMgr:GetCameraLocation() end
    end)
    if not camLoc then return end

    local dirX = (bestBoneLoc.X or 0) - (camLoc.X or 0)
    local dirY = (bestBoneLoc.Y or 0) - (camLoc.Y or 0)
    local dirZ = (bestBoneLoc.Z or 0) - (camLoc.Z or 0)
    local len = math.sqrt(dirX*dirX + dirY*dirY + dirZ*dirZ)
    if len <= 0 then return end

    local targetPitch = -math.deg(math.asin(dirZ / len))
    local targetYaw = math.deg(_G.atan2(dirY, dirX))

    local deltaYaw = targetYaw - curYaw
    if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
    if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
    local deltaPitch = targetPitch - curPitch

    -- SMOOTH internal — 0.85 smoothness => slow lerp
    local dt = (_G.FrameDelta and _G.FrameDelta.ClampedDelta) or 0.016
    local speed = 8.0   -- low = smooth, high = snappy
    local t = 1 - math.exp(-speed * dt)
    if t > 1 then t = 1 end

    local newPitch = curPitch + deltaPitch * t
    local newYaw = curYaw + deltaYaw * t

    local FRotator = import("Rotator")
    local rot = FRotator and FRotator(newPitch, newYaw, 0) or {Pitch = newPitch, Yaw = newYaw, Roll = 0}
    pcall(function() pc:SetControlRotation(rot) end)
  end)
end

-- ====================================================================
-- CROSSHAIR
-- ====================================================================
_G.CrosshairState = _G.CrosshairState or {
  Widgets = {},
  Container = nil,
  LastHash = "",
}

local function CrosshairColorFromIdx(idx)
  if idx == 1 then return {R=1, G=0, B=0, A=1} end
  if idx == 2 then return {R=0, G=1, B=0, A=1} end
  if idx == 3 then return {R=0, G=0.5, B=1, A=1} end
  if idx == 4 then return {R=0, G=1, B=1, A=1} end
  if idx == 5 then return {R=1, G=1, B=0, A=1} end
  return {R=1, G=1, B=1, A=1}
end

_G.CrosshairClear = function()
  local C = _G.CrosshairState.Container
  if C and slua.isValid(C) then
    pcall(function() C:RemoveFromParent(); C:ConditionalBeginDestroy() end)
  end
  _G.CrosshairState.Container = nil
  _G.CrosshairState.Widgets = {}
  _G.CrosshairState.LastHash = ""
end

_G.ApplyCrosshair = function()
  _G.Safe("crosshair", function()
    if not _G.LexusConfig.Crosshair then
      if _G.CrosshairState.Container then _G.CrosshairClear() end
      return
    end

    local PM = _G.PlayerMapMarker
    if not PM or not PM.ESPCanvas or not Game:IsValid(PM.ESPCanvas) then
      if PM and PM.InitESPCanvas then PM.InitESPCanvas() end
      if not PM or not PM.ESPCanvas then return end
    end
    local canvas = PM.ESPCanvas
    if not canvas then return end

    local style = _G.LexusConfig.CrosshairStyle or 1
    local size = math.max(1, math.min(10, _G.LexusConfig.CrosshairSize or 4))
    local colorIdx = _G.LexusConfig.CrosshairColor or 2
    local hash = string.format("%d_%d_%d", style, size, colorIdx)

    if hash == _G.CrosshairState.LastHash and _G.CrosshairState.Container and slua.isValid(_G.CrosshairState.Container) then return end
    _G.CrosshairClear()
    _G.CrosshairState.LastHash = hash

    local col = CrosshairColorFromIdx(colorIdx)
    local LC = _G.getCachedLinearColor()
    local fcolor = LC and LC(col.R, col.G, col.B, col.A) or {R=col.R*255, G=col.G*255, B=col.B*255, A=255}

    local sw, sh = 1920, 1080
    pcall(function()
      local WLL = _G.GetModule("WidgetLayoutLibrary")
      if WLL and WLL.GetViewportSize then
        local sz = WLL.GetViewportSize(nil)
        if sz and sz.X and sz.X > 200 then sw = sz.X; sh = sz.Y end
      end
    end)
    local cx, cy
    if PM.ScreenPixelToCanvasLocal then
      local p = PM.ScreenPixelToCanvasLocal(nil, {X = sw * 0.5, Y = sh * 0.5})
      cx, cy = p.X, p.Y
    else
      cx, cy = sw * 0.5, sh * 0.5
    end

    local C = nil
    pcall(function() C = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not C or not slua.isValid(C) then return end
    _G.CrosshairState.Container = C

    local thickness = 2
    local gap = size * 1.5
    local length = size * 2.5
    local dot = size * 0.6

    local function addBorder(x, y, w, h)
      local B = nil
      pcall(function() B = CGame:NewObjectFromPath("/Script/UMG.Border", C) end)
      if not B or not slua.isValid(B) then return end
      pcall(function()
        B:SetBrushColor(fcolor)
        B:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
      local s = C:AddChildToCanvas(B)
      if s then s:SetPosition(FVector2D(x, y)); s:SetSize(FVector2D(w, h)) end
      table.insert(_G.CrosshairState.Widgets, B)
    end

    if style == 1 then
      addBorder(cx - dot/2, cy - dot/2, dot, dot)
    elseif style == 2 then
      addBorder(cx - gap - length, cy - thickness/2, length, thickness)
      addBorder(cx + gap, cy - thickness/2, length, thickness)
      addBorder(cx - thickness/2, cy - gap - length, thickness, length)
      addBorder(cx - thickness/2, cy + gap, thickness, length)
    elseif style == 3 then
      local radius = size * 1.5
      local seg = 16
      for i = 0, seg - 1 do
        local a = (i / seg) * math.pi * 2
        local dx = math.cos(a) * radius
        local dy = math.sin(a) * radius
        addBorder(cx + dx - thickness/2, cy + dy - thickness/2, thickness, thickness)
      end
    elseif style == 4 then
      local radius = size * 1.5
      local seg = 16
      for i = 0, seg - 1 do
        local a = (i / seg) * math.pi * 2
        local dx = math.cos(a) * radius
        local dy = math.sin(a) * radius
        addBorder(cx + dx - thickness/2, cy + dy - thickness/2, thickness, thickness)
      end
      addBorder(cx - dot/2, cy - dot/2, dot, dot)
    end

    local slot = nil
    pcall(function() slot = canvas:AddChildToCanvas(C) end)
    if slot then
      pcall(function()
        slot:SetAutoSize(false)
        slot:SetZOrder(9999)
        slot:SetPosition(FVector2D(0, 0))
      end)
    end
  end)
end

-- ====================================================================
-- FPS UNLOCK (30-265)
-- ====================================================================
_G.FPSState = _G.FPSState or { LastApplied = 0, WasEnabled = false }

_G.ApplyFPSLimit = function()
  _G.Safe("fps_unlock", function()
    local KSL = import("KismetSystemLibrary")
    local world = slua.getWorld()
    if not KSL or not world then return end

    if not _G.LexusConfig.UnlockFPS then
      if _G.FPSState.WasEnabled then
        pcall(function() KSL.ExecuteConsoleCommand(world, "t.MaxFPS 60") end)
        _G.FPSState.WasEnabled = false
        _G.FPSState.LastApplied = 0
      end
      return
    end

    local target = math.max(30, math.min(265, _G.LexusConfig.FPSLimit or 165))
    if _G.FPSState.LastApplied == target then return end
    _G.FPSState.LastApplied = target
    _G.FPSState.WasEnabled = true

    pcall(function() KSL.ExecuteConsoleCommand(world, "t.MaxFPS " .. tostring(target)) end)
    pcall(function() KSL.ExecuteConsoleCommand(world, "r.MobileHFRLevel 3") end)
    pcall(function() KSL.ExecuteConsoleCommand(world, "r.MobileHUDUseHFR 1") end)
  end)
end

-- ====================================================================
-- IPAD VIEW
-- ====================================================================
_G.IpadViewState = _G.IpadViewState or { LastApplied = 0, WasEnabled = false }

_G.ApplyIpadView = function()
  _G.Safe("ipadview", function()
    local GD = _G.getCachedGameplayData()
    if not GD or not GD.GetPlayerController then return end
    local pc = GD.GetPlayerController()
    if not Valid(pc) then return end
    local lp = pc:GetPlayerCharacterSafety()
    if not Valid(lp) then return end

    if _G.LexusConfig.IpadView then
      local target = math.max(90, math.min(150, _G.LexusConfig.IpadViewFOV or 120))
      _G.IpadViewState.WasEnabled = true
      _G.IpadViewState.LastApplied = target
      pcall(function()
        local cam = lp.ThirdPersonCameraComponent
        if Valid(cam) then
          local cur = cam.FieldOfView or 90
          if math.abs(cur - target) > 0.1 then
            cam.FieldOfView = _G.LerpSmooth(cur, target, 8, _G.FrameDelta.ClampedDelta)
          end
        end
      end)
    else
      if _G.IpadViewState.WasEnabled then
        pcall(function()
          local cam = lp.ThirdPersonCameraComponent
          if Valid(cam) then
            local cur = cam.FieldOfView or 90
            if math.abs(cur - 90) > 0.1 then
              cam.FieldOfView = _G.LerpSmooth(cur, 90, 8, _G.FrameDelta.ClampedDelta)
            end
          end
        end)
      end
    end
  end)
end

-- ====================================================================
-- MOD MENU (new layout)
-- ====================================================================
function _G.InitModMenuTab()
  if _G.ModMenuInitialized then return end
  _G.ModMenuInitialized = true

  _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}

  local LocUtil = package.loaded["client.common.LocUtil"] or _G.GetModule("client.common.LocUtil")
  local FT = {
    [999000] = "TESLA 10X MOD MENU",
    [999001] = "ESP",
    [999002] = "WALLHACK",
    [999003] = "COMBAT",
    [999004] = "VISUALS",
    [999005] = "MISC",
  }
  if LocUtil and not LocUtil._Hooked_V5 then
    for _, fn in ipairs({"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}) do
      if LocUtil[fn] then
        local orig = LocUtil[fn]
        LocUtil[fn] = function(id)
          if id ~= nil then
            local nId = tonumber(id) or id
            if FT[nId] then return FT[nId] end
            local sId = tostring(id)
            if FT[sId] then return FT[sId] end
          end
          if type(id) == "string" and not tonumber(id) then return id end
          if orig then return orig(id) end
          return ""
        end
      end
    end
    LocUtil._Hooked_V5 = true
  end

  local SPD = _G.GetModule("client.logic.NewSetting.SettingPageDefine")
  local SC = _G.GetModule("client.logic.NewSetting.SettingCatalog")
  if not SPD or not SC or SPD.ModMenu then return end

  local AM = _G.GetModule("client.slua.umg.NewSetting.Item.AliasMap")
  if not AM then return end

  local function boolSw(key, text, cfg, parent)
    return {
      Key = key, UI = AM.Switcher, Text = text, ExpandHandle = parent,
      GetFunc = function() return _G.LexusConfig[cfg] end,
      SetFunc = function(c, v) _G.LexusConfig[cfg] = v; _G.MarkConfigDirty(); return true end
    }
  end
  local function titleSw(key, text, cfg)
    return {
      Key = key, UI = AM.TitleSwitcher, Text = text, ExpandIndex = 0,
      GetFunc = function() return _G.LexusConfig[cfg] end,
      SetFunc = function(c, v) _G.LexusConfig[cfg] = v; _G.MarkConfigDirty(); return true end
    }
  end
  local function slider(key, text, cfg, minV, maxV, parent, customGet, customSet)
    return {
      Key = key, UI = AM.Slider, Text = text, ExpandHandle = parent,
      MinValue = minV, MaxValue = maxV,
      GetFunc = customGet or function() return _G.LexusConfig[cfg] end,
      SetFunc = customSet or function(c, v) _G.LexusConfig[cfg] = v; _G.MarkConfigDirty(); return true end
    }
  end

  local StackESP = {
    titleSw("MM_ESP9", "ESP VIP (Wallhack Overlay)", "EspLoai9"),
    boolSw("MM_ESP9_Count", "   Player Count (Red Box)", "Esp9_Count", "MM_ESP9"),
    boolSw("MM_ESP9_Name", "   Player Name (RED)", "Esp9_Name", "MM_ESP9"),
    boolSw("MM_ESP9_Dist", "   Distance (RED)", "Esp9_Distance", "MM_ESP9"),
    boolSw("MM_ESP9_HP", "   Health Bar (RED)", "Esp9_HP", "MM_ESP9"),
    boolSw("MM_ESP9_Team", "   Team Color (Red)", "Esp9_Team", "MM_ESP9"),
    boolSw("MM_ESP9_Weapon", "   Weapon Icon", "Esp9_Weapon", "MM_ESP9"),
    titleSw("MM_EspInfo", "ESP INFO (HUD)", "EspInfo"),
    boolSw("MM_EspInfo_Wep", "   Weapon Name", "EspInfo_Weapon", "MM_EspInfo"),
    boolSw("MM_EspInfo_Pose", "   Player Pose", "EspInfo_Pose", "MM_EspInfo"),
    boolSw("MM_ESP9_Line", "   Snapline (Green)", "Esp9_Line", "MM_ESP9"),
    boolSw("MM_ESP9_Skel", "   Skeleton (Green)", "Esp9_Skeleton", "MM_ESP9"),
    boolSw("MM_Antenna", "ESP Antenna", "EspAntenna"),
    boolSw("MM_DistHud", "ESP Distance (HUD, RED)", "EspDistance"),
    boolSw("MM_VipHud", "ESP VIP Pro (HUD, RED)", "EspVipPro"),
  }

  local StackWall = {
    titleSw("MM_Chams", "CHAMS (Red/Green)", "ColorBodyNew"),
  }

  local StackCombat = {
    titleSw("MM_WeaponAimbot", "WEAPON AIMBOT (Native)", "WeaponAimbot"),
    titleSw("MM_AutoHeadScope", "AUTO HEAD (Scope-Aware)", "AutoHead"),
    titleSw("MM_NoRecoil", "NO RECOIL", "NoRecoilEnabled"),
    slider("MM_RecoilPct", "   Strength (0-100%)", "RecoilReduction", 0, 100, "MM_NoRecoil"),
    titleSw("MM_Aimbot", "AIMBOT (Smooth / 100m / Neck+Chest)", "AimbotEnabled"),
    boolSw("MM_KillMsg", "Kill Message (Gold)", "KillMessage"),
  }

  local StackVisuals = {
    titleSw("MM_Ipad", "IPAD VIEW", "IpadView"),
    slider("MM_IpadFOV", "   FOV (90-150)", "IpadViewFOV", 90, 150, "MM_Ipad"),
    titleSw("MM_FPS", "UNLOCK FPS", "UnlockFPS"),
    {
      Key = "MM_FPSLimit", UI = AM.Slider, Text = "   FPS Limit (30-265)", ExpandHandle = "MM_FPS",
      MinValue = 30, MaxValue = 265,
      GetFunc = function() return _G.LexusConfig.FPSLimit or 165 end,
      SetFunc = function(c, v) _G.LexusConfig.FPSLimit = v; _G.FPSState.LastApplied = 0; _G.MarkConfigDirty(); return true end
    },
    titleSw("MM_Crosshair", "CROSSHAIR", "Crosshair"),
    {
      Key = "MM_CrossStyle", UI = AM.Slider, Text = "   Style (1:Dot 2:Cross 3:Circle 4:CircleDot)", ExpandHandle = "MM_Crosshair",
      MinValue = 1, MaxValue = 4,
      GetFunc = function() return _G.LexusConfig.CrosshairStyle or 1 end,
      SetFunc = function(c, v) _G.LexusConfig.CrosshairStyle = v; _G.CrosshairState.LastHash = ""; _G.MarkConfigDirty(); return true end
    },
    {
      Key = "MM_CrossSize", UI = AM.Slider, Text = "   Size (1-10)", ExpandHandle = "MM_Crosshair",
      MinValue = 1, MaxValue = 10,
      GetFunc = function() return _G.LexusConfig.CrosshairSize or 4 end,
      SetFunc = function(c, v) _G.LexusConfig.CrosshairSize = v; _G.CrosshairState.LastHash = ""; _G.MarkConfigDirty(); return true end
    },
    {
      Key = "MM_CrossColor", UI = AM.Slider, Text = "   Color (1:R 2:G 3:B 4:C 5:Y 6:W)", ExpandHandle = "MM_Crosshair",
      MinValue = 1, MaxValue = 6,
      GetFunc = function() return _G.LexusConfig.CrosshairColor or 2 end,
      SetFunc = function(c, v) _G.LexusConfig.CrosshairColor = v; _G.CrosshairState.LastHash = ""; _G.MarkConfigDirty(); return true end
    },
  }

  local StackMisc = {
    boolSw("MM_FakeHWID", "Fake HWID (Anti-Ban)", "FakeHWID"),
  }

  SPD.ModMenu = {
    Key = "ModMenu", Text = "TESLA 10X", UIKey = "Setting_Page_Privacy",
    Category = {
      { Key = "Cat_ESP", Text = "ESP", Stack = StackESP },
      { Key = "Cat_Wall", Text = "WALLHACK", Stack = StackWall },
      { Key = "Cat_Combat", Text = "COMBAT", Stack = StackCombat },
      { Key = "Cat_Vis", Text = "VISUALS", Stack = StackVisuals },
      { Key = "Cat_Misc", Text = "MISC", Stack = StackMisc },
    }
  }
  table.insert(SC, 1, SPD.ModMenu)

  local UIMgr = _G.UIManager
  if UIMgr and not UIMgr._Hooked_V5 then
    local old = UIMgr.ShowUI
    UIMgr.ShowUI = function(config, ...)
      local args = {...}
      local n = select("#", ...)
      if config and config.keyName then
        local lk = string.lower(config.keyName)
        if string.find(lk, "setting_main") and not string.find(lk, "custom") then
          local cat = args[1]
          if type(cat) == "table" and cat[1] and cat[1].Key then
            local found = false
            for _, p in ipairs(cat) do if p.Key == "ModMenu" then found = true; break end end
            if not found then table.insert(cat, 1, SPD.ModMenu) end
          end
        end
      end
      local up = table.unpack or unpack
      return old(config, up(args, 1, n))
    end
    UIMgr._Hooked_V5 = true
  end
end

-- ====================================================================
-- WELCOME MENU
-- ====================================================================
_G.ShowWelcomeMenu = function()
  if _G.WelcomeShown then return end
  _G.WelcomeShown = true
  pcall(function()
    local Msg = _G.GetModule("client.slua.logic.common.logic_common_msg_box")
    if not Msg or not Msg.Show then return end
    local title = "TESLA 10X"
    local body = "TESLA 10X v3.0\n===================================\nBypass: 42 Layers (FIXED)\nSupports: BGMI / PUBG Global / TW / VN / KR\n===================================\nESP (RED) / Wallhack / Aimbot FIXED\nNoRecoil / Crosshair / FPS 265 / iPadView\n===================================\nChannel: TESLA 10X\nOwner: @OfficialOwner10x"
    Msg.Show(2, title, body,
      function()
        pcall(_G.InitModMenuTab)
        _G.Notify("Mod Menu ready — Settings > TESLA 10X")
      end,
      function() end, "OK", "CLOSE")
  end)
end

print("[TESLA10X] Part 3/4 loaded — Aimbot FIXED + NoRecoil + Crosshair + FPS 265 + iPadView + Menu")

-- ====================================================================
-- TESLA 10X — Part 4/4: MainLoop + Boot + Quick MOD Button FIXED + Class
-- ====================================================================

-- ====================================================================
-- QUICK ACCESS BUTTON — top-right, FIXED to stay visible
-- ====================================================================
local QuickMenuBtn = {
  Created = false,
  Container = nil,
  Canvas = nil,
  Slot = nil,
  _LastCanvasCheck = 0,
}

function QuickMenuBtn.Create()
  if QuickMenuBtn.Created and QuickMenuBtn.Container and slua.isValid(QuickMenuBtn.Container) then
    return true
  end

  if not _G.PlayerMapMarker then return false end
  if not _G.PlayerMapMarker.ESPCanvas or not slua.isValid(_G.PlayerMapMarker.ESPCanvas) then
    pcall(function() _G.PlayerMapMarker.InitESPCanvas() end)
  end
  local Canvas = _G.PlayerMapMarker.ESPCanvas
  if not Canvas or not slua.isValid(Canvas) then return false end

  QuickMenuBtn.Canvas = Canvas
  QuickMenuBtn.Created = false
  QuickMenuBtn.Container = nil
  QuickMenuBtn.Slot = nil

  local Border = nil
  pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", Canvas) end)
  if not Border or not slua.isValid(Border) then return false end

  local LC = _G.getCachedLinearColor()
  local red = LC and LC(0.9, 0.1, 0.1, 0.95) or {R=230, G=25, B=25, A=240}
  pcall(function() Border:SetBrushColor(red) end)
  pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
  pcall(function() Border:SetRenderOpacity(1.0) end)

  local Label = nil
  pcall(function() Label = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Border) end)
  if Label and slua.isValid(Label) then
    pcall(function()
      Label:SetText("MOD")
      Label:SetJustification(1)
      local FS = import("SlateColor")
      local wc = LC and LC(1, 1, 1, 1) or {R=255,G=255,B=255,A=255}
      if FS then Label:SetColorAndOpacity(FS(wc)) else Label:SetColorAndOpacity(wc) end
      if Label.Font then local f = Label.Font; f.Size = 24; Label.Font = f end
      Label:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
      if Border.SetContent then Border:SetContent(Label) end
      if Border.AddChild then pcall(function() Border:AddChild(Label) end) end
    end)
  end

  local Slot = nil
  pcall(function() Slot = Canvas:AddChildToCanvas(Border) end)
  if not Slot then return false end

  QuickMenuBtn.Slot = Slot
  QuickMenuBtn.Container = Border

  pcall(function()
    Slot:SetAutoSize(false)
    Slot:SetSize(FVector2D(110, 60))
    Slot:SetAlignment(FVector2D(1.0, 0.0))
    Slot:SetPosition(FVector2D(-130, 200))
    Slot:SetZOrder(99999)
  end)

  local function OnModBtnClick()
    pcall(function()
      local UI = _G.UIManager
      if UI and UI.ShowUI then
        local SC = _G.GetModule("client.logic.NewSetting.SettingCatalog")
        local SPD = _G.GetModule("client.logic.NewSetting.SettingPageDefine")
        if SC and SPD and SPD.ModMenu then
          pcall(function() UI.ShowUI({ keyName = "Setting_Main" }, SC) end)
        end
      end
    end)
  end

  pcall(function()
    if Border.OnMouseButtonDownEvent and Border.OnMouseButtonDownEvent.Add then
      Border.OnMouseButtonDownEvent:Add(function() OnModBtnClick() end)
    end
    if Border.SetOnMouseButtonDownEvent then
      Border:SetOnMouseButtonDownEvent(function() OnModBtnClick() end)
    end
  end)

  QuickMenuBtn.Created = true
  return true
end
function QuickMenuBtn.Update()
  -- if canvas changed, force recreate
  local curCanvas = _G.PlayerMapMarker and _G.PlayerMapMarker.ESPCanvas
  if QuickMenuBtn.Canvas and curCanvas and QuickMenuBtn.Canvas ~= curCanvas then
    QuickMenuBtn.Created = false
    QuickMenuBtn.Container = nil
    QuickMenuBtn.Slot = nil
    QuickMenuBtn.Canvas = nil
  end

  if not QuickMenuBtn.Created or not QuickMenuBtn.Container or not slua.isValid(QuickMenuBtn.Container) then
    QuickMenuBtn.Created = false
    pcall(QuickMenuBtn.Create)
  end

  if QuickMenuBtn.Container and slua.isValid(QuickMenuBtn.Container) then
    pcall(function()
      QuickMenuBtn.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
      QuickMenuBtn.Container:SetRenderOpacity(1.0)
    end)
    if QuickMenuBtn.Slot and slua.isValid(QuickMenuBtn.Slot) then
      pcall(function()
        QuickMenuBtn.Slot:SetPosition(FVector2D(-110, 180))
        QuickMenuBtn.Slot:SetZOrder(9999)
      end)
    end
  end
end

_G.QuickMenuBtn = QuickMenuBtn

-- ====================================================================
-- MAIN LOOP
-- ====================================================================
local function MainLoop()
  _G.Safe("main_loop", function()
    _G.TickFrame()

    -- Quick MOD button — ALWAYS update (even without ESP enabled)
    if _G.QuickMenuBtn and _G.QuickMenuBtn.Update then
      pcall(_G.QuickMenuBtn.Update)
    end

    local GD = _G.getCachedGameplayData()
    if not GD then return end
    local pc = GD.GetPlayerController and GD.GetPlayerController()
    local lp = nil
    if Valid(pc) then lp = pc:GetPlayerCharacterSafety() end
    if not Valid(lp) then return end

    if not _G.LexusState.NativeESPReady then _G.InitializeNativeESP() end

    -- No Recoil — always call (function handles ON/OFF internally)
    if _G.ApplyNoRecoil then pcall(_G.ApplyNoRecoil) end

    -- Aimbot — only when enabled
    if _G.LexusConfig.AimbotEnabled and _G.ApplyAimbot then
      pcall(_G.ApplyAimbot)
    end

    -- Kill Message hookup (one-time)
    if not _G.KillInfoHacked and _G.ForceEnableKillCounterUI then
      pcall(_G.ForceEnableKillCounterUI)
    end

    -- IpadView
    if _G.ApplyIpadView then pcall(_G.ApplyIpadView) end

    -- FPS Unlock
    if _G.ApplyFPSLimit then pcall(_G.ApplyFPSLimit) end

    -- Crosshair
    if _G.ApplyCrosshair then pcall(_G.ApplyCrosshair) end

    -- [UPGRADE] Weapon Aimbot + Auto Head (scope) — always call, functions handle ON/OFF
    if _G.ApplyWeaponAimbot then pcall(_G.ApplyWeaponAimbot) end
    if _G.ApplyAutoHeadScope then pcall(_G.ApplyAutoHeadScope) end

    -- ESP start/stop
    if _G.LexusConfig.EspLoai9 then _G.StartESP() else _G.StopESP() end

    -- Enemy iteration
    local allChars = {}
    pcall(function()
      if GD.GetAllPlayerCharacters then allChars = GD.GetAllPlayerCharacters()
      elseif GD.GameCharacters then for _, c in pairs(GD.GameCharacters) do table.insert(allChars, c) end end
    end)

    local validKeys = {}
    for _, e in pairs(allChars) do
      if Valid(e) and e ~= lp and e.TeamID ~= lp.TeamID then
        local dead = false
        pcall(function()
          if type(e.IsDead) == "function" then dead = e:IsDead()
          elseif e.bIsDead ~= nil then dead = e.bIsDead end
          if e.HealthStatus == 2 then dead = true end
        end)
        if not dead then validKeys[_G.GetSafeEnemyKey(e)] = true end
      end
    end
    for k in pairs(_G.LexusState.EnemyMarks) do
      if not validKeys[k] then _G.LexusState.EnemyMarks[k] = nil end
    end

    local realCount, botCount = 0, 0
    for _, e in pairs(allChars) do
      if Valid(e) and e ~= lp and e.TeamID ~= lp.TeamID then
        local dead = false
        pcall(function()
          if type(e.IsDead) == "function" then dead = e:IsDead()
          elseif e.bIsDead ~= nil then dead = e.bIsDead end
          if e.HealthStatus == 2 then dead = true end
        end)
        local key = _G.GetSafeEnemyKey(e)
        _G.LexusState.EnemyMarks[key] = _G.LexusState.EnemyMarks[key] or { enemy = e }
        local md = _G.LexusState.EnemyMarks[key]
        md.enemy = e

        local distM = 0
        pcall(function() distM = lp:GetDistanceTo(e) / 100 end)
        _G.ProcessEnemyESP(e, md, lp, distM)

        if not dead then
          local isBot = _G.CheckIsAI(e, md)
          if distM <= 600 then
            if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
          end
        end
      end
    end
    _G.UpdateRedBox(realCount, botCount)

    _G.SaveModSettings()
  end)
end

local myToken = 0
local function FastTick()
  if myToken ~= _G.LexusState.LoopToken then return end
  pcall(MainLoop)
  local ticker = _G.GetModule("common.time_ticker")
  if ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(0.05, FastTick) end
end

local function AutoSaveLoop()
  pcall(_G.SaveModSettings)
  local ticker = _G.GetModule("common.time_ticker")
  if ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(5.0, AutoSaveLoop) end
end

-- ====================================================================
-- BOOT SEQUENCE
-- ====================================================================
pcall(function()
  local ticker = _G.GetModule("common.time_ticker")
  if ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(4.0, function()
      _G.LoadModSettings()
      _G.InitializeBypass()
      _G.InitializeExtraBypass()
      AutoSaveLoop()
      print("[TESLA10X] Bypass total: " .. #_G.BypassLog .. " layers active")
      for _, name in ipairs(_G.BypassLog) do
        print("  [OK] " .. name)
      end
      if _G.ExtraBypassLog then
        print("[TESLA10X] Extra Bypass total: " .. #_G.ExtraBypassLog .. " layers")
        for _, name in ipairs(_G.ExtraBypassLog) do
          print("  [EB] " .. name)
        end
      end
    end)
  end
end)

pcall(function()
  local ticker = _G.GetModule("common.time_ticker")
  if ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(6.0, function() FastTick() end)
  end
end)

pcall(function()
  local ticker = _G.GetModule("common.time_ticker")
  if ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(8.0, function()
      _G.InitializeNativeESP()
      _G.Notify("TESLA 10X v3.0 loaded — @OfficialOwner10x")
    end)
  end
end)

pcall(function()
  local ticker = _G.GetModule("common.time_ticker")
  if ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(11.0, function() pcall(_G.ShowWelcomeMenu) end)
  end
end)

pcall(function()
  local ticker = _G.GetModule("common.time_ticker")
  if ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(13.0, function()
      _G.Notify("TESLA 10X v3.0 ready — 42L bypass | ESP(RED) | Aimbot FIXED | FPS 265")
    end)
  end
end)

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
myToken = _G.LexusState.LoopToken

_G.Notify("TESLA 10X Ready — waiting for match")

-- ====================================================================
-- CLASS DECLARATION
-- ====================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)

print("[TESLA10X] Part 4/4 loaded — MainLoop + Boot + Quick MOD FIXED + Class ready")
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



