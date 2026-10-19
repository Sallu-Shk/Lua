-- ====================================================================
-- BRPlayerCharacterBase.lua — TESLA 10X 4.6 AGGRESSIVE
-- Wallhack V3 (Mesh Cache) + Pattern Bypass + Multi-HWID + Lag Fix
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

-- ==================== BASE CLASS (unchanged) ====================
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
-- MOD CORE
-- ====================================================================
local BRAND = "TESLA 10X 4.6 AGGRESSIVE"
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
    FakeHWID = false,
    ShowBrand = true,
    WallhackFullMesh = true,   -- toggle outline-only vs full dyeing
}
_G.LexusState = _G.LexusState or { LoopToken = 0 }

-- ====================================================================
-- FPS 165 UNLOCK (unchanged)
-- ====================================================================
pcall(function()
    local logic_setting_graphics = package.loaded["client.slua.logic.setting.logic_setting_graphics"] or require("client.slua.logic.setting.logic_setting_graphics")
    local GSC_FPS = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
    local GSC_FPSFT = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
    local GraphicSettingDB = package.loaded["client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB"] or require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")

    if logic_setting_graphics then
        local orig = logic_setting_graphics.SetFPS
        function logic_setting_graphics.SetFPS(gi, level)
            if level == 8 and GraphicSettingDB then
                local sw = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if not sw then GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneSwitch, true) end
            end
            if orig then orig(gi, level) end
            if level == 8 and GraphicSettingDB and gi then
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, 165)
                gi:ExecuteCMD("t.MaxFPS", "165")
                gi:ExecuteCMD("r.FrameRateLimit", "165")
            end
        end
    end

    if GSC_FPS and GSC_FPS.__inner_impl then
        local impl = GSC_FPS.__inner_impl
        function impl:GetMaxFPSLevel() return 8, 8 end
        function impl:CanChangeQualityAndFPSPreCheck() return true end
        function impl:InitRealSupportFPS()
            local t = {}
            for i = 1, 8 do t[i] = {true, true} end
            if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, t, false) end
            return t
        end
        function impl:SetFPSAndQualityEnable(bEnable)
            if self.UIRoot and self.UIRoot.Image_Mask then self:SetWidgetVisible(self.UIRoot.Image_Mask, false) end
        end
        function impl:UpdateSelectedFPSState(sel)
            local nodes = {[2]="NodeFps20",[3]="NodeFps25",[4]="NodeFps30",[5]="NodeFps40",[6]="NodeFps60",[7]="NodeFps90",[8]="NodeFps120"}
            if not self.UIRoot then return end
            for lv, nm in pairs(nodes) do
                if self.UIRoot[nm] then
                    self:WidgetSelfHit(self.UIRoot[nm])
                    self.UIRoot[nm]:SetIsEnabled(true)
                    local sw = self.UIRoot["WidgetSwitcher_" .. lv]
                    if sw then sw:SetActiveWidgetIndex(lv == sel and 0 or 1) end
                end
            end
        end
        local orig = impl.UpdateUI
        function impl:UpdateUI()
            if orig then pcall(orig, self) end
            self:SelfHitTestInvisible()
            self:InitRealSupportFPS()
            self:SetFPSAndQualityEnable(true)
            local lv = 8
            if GraphicSettingDB then
                if GraphicSettingDB:GetUIData(GraphicSettingDB.CustomTab) == 2 then
                    lv = GraphicSettingDB:GetUIData(GraphicSettingDB.LobbyFPS) or 8
                else
                    lv = GraphicSettingDB:GetUIData(GraphicSettingDB.SelectedFPS) or 8
                end
            end
            self:UpdateSelectedFPSState(lv)
        end
        function impl:DoClickFPS(lv)
            if slua.isValid(self.UIRoot) then
                if GraphicSettingDB:GetUIData(GraphicSettingDB.CustomTab) == 2 then
                    GraphicSettingDB:UpdateUIData(GraphicSettingDB.LobbyFPS, lv)
                else
                    GraphicSettingDB:UpdateSelectedFPS(lv)
                end
                self:UpdateSelectedFPSState(lv)
                if self:GetParentUI() then
                    self:GetParentUI():SaveQualityAndFPS()
                    self:GetParentUI():SetDirty(true)
                end
            end
        end
    end

    if GSC_FPSFT and GSC_FPSFT.__inner_impl then
        local impl = GSC_FPSFT.__inner_impl
        local NMIN, NSTEP = 90, 5
        local function clamp(v, mn, mx) return v < mn and mn or (v > mx and mx or v) end
        function impl:ShowOrHide() self:SelfHitTestInvisible(); if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end end
        function impl:InitFPSFTSwitch()
            local sw = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
            if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(sw, true) end
            if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, sw) end
            if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
            if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
        end
        function impl:InitFPSFTValue165()
            local r = self.UIRoot
            if not r then return end
            local sw = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
            local num = sw and GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
            if r.Slider_screen3 then r.Slider_screen3:SetLocked(not sw) end
            if r.ProgressBar_screen3 then
                local C = FLinearColor
                if C then r.ProgressBar_screen3:SetFillColorAndOpacity(sw and C(1,1,1,1) or C(1,0.625,0.6,1)) end
            end
            local pct = (num - NMIN) / (165 - NMIN)
            if r.Veihclescreen3 then r.Veihclescreen3:SetText(tostring(num)) end
            if r.Slider_screen3 then r.Slider_screen3:SetValue(pct) end
            if r.ProgressBar_screen3 then r.ProgressBar_screen3:SetPercent(pct) end
        end
        function impl:OnFPSFTValueChange3(num)
            GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, num)
            self:InitFPSFTValue165()
            if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
            local gi = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
            if gi then gi:ExecuteCMD("t.MaxFPS", tostring(num)); gi:ExecuteCMD("r.FrameRateLimit", tostring(num)) end
        end
        function impl:OnFPSFTSliderValueChange3(v)
            if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) then
                local num = math.floor(v * (165 - NMIN) / NSTEP) * NSTEP + NMIN
                pcall(function() local K = import("KismetMathLibrary"); num = K.FCeil(v * (165 - NMIN) / NSTEP) * NSTEP + NMIN end)
                self:OnFPSFTValueChange3(clamp(num, NMIN, 165))
            end
        end
        function impl:OnFPSFTAdd3() local n = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum); if n then self:OnFPSFTValueChange3(math.min(165, n + NSTEP)) end end
        function impl:OnFPSFTMinus3() local n = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum); if n then self:OnFPSFTValueChange3(math.max(NMIN, n - NSTEP)) end end
        impl.OnFPSFTAdd = impl.OnFPSFTAdd3
        impl.OnFPSFTMinus = impl.OnFPSFTMinus3
        impl.OnFPSFTSliderValueChange = impl.OnFPSFTSliderValueChange3
    end
    print("[" .. BRAND .. "] FPS 165 Unlock hooked")
end)

-- ====================================================================
-- AGGRESSIVE BYPASS v2 — pattern matching + multi-source HWID
-- ====================================================================
local BYPASS = { nop = function() end, retFalse = function() return false end, retTrue = function() return true end }
BYPASS.retZero = function() return 0 end
BYPASS.retEmpty = function() return {} end
BYPASS.retEmptyStr = function() return "" end
BYPASS.retMD5 = function() return "00000000000000000000000000000000" end

pcall(function()
    local nop, retFalse, retTrue, retZero, retEmpty, retEmptyStr, retMD5 =
        BYPASS.nop, BYPASS.retFalse, BYPASS.retTrue, BYPASS.retZero, BYPASS.retEmpty, BYPASS.retEmptyStr, BYPASS.retMD5

    -- ============================================================
    -- 1. SUBSYSTEM WIPE — nop reporting methods, keep lifecycle intact
    -- ============================================================
    local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if subMgr then
        local targets = {
            "CoronaLabSubsystem","ClientReportPlayerSubsystem","DSReportPlayerSubsystem","ShootVerifySubSystemClient",
            "BehaviorScoreSubsystem","AntiCheatSubsystem","GameReportSubsystem","OperationalStatsSubsystem",
            "SwiftHawkSubsystem","PlayerSecurityInfoSubsystem","ModifierExceptionSubsystem","IntegrityCheckSubsystem",
            "FileCheckSubsystem","MemoryCheckSubsystem","SpeedCheckSubsystem","WallCheckSubsystem",
            "AvatarExceptionSubsystem","ClientDataStatistcsSubsystem","AFKReportorSubsystem","ClientCircleFlowSubsystem",
            "MrpcsFlowSubsystem","ReplaySubsystem","TssSdkSubsystem","TLogSubsystem","CrashSightSubsystem",
            "HiggsBosonSubsystem","NetCheckSubsystem","CheatReportSubsystem","PunishmentSubsystem",
            "PlayerMovementVerifySubsystem","WeaponIntegritySubsystem","SkinIntegritySubsystem",
            "CharacterIntegritySubsystem","VehicleIntegritySubsystem","LobbyVerifySubsystem","BootVerifySubsystem",
            "StartupCheckSubsystem","ProcessCheckSubsystem","RootDetectSubsystem","EmulatorDetectSubsystem",
            "DebugDetectSubsystem","InjectionDetectSubsystem","HookDetectSubsystem","ModuleScanSubsystem",
            "AntiTamperSubsystem","SigCheckSubsystem","AssetVerifySubsystem","PakVerifySubsystem",
            "LuaIntegritySubsystem","BytecodeVerifySubsystem","EncryptionCheckSubsystem","SessionSecuritySubsystem",
            "NetworkVerifySubsystem","ClientIntegritySubsystem","ReportManagerSubsystem","TelemetrySubsystem",
            "AnalyticsSubsystem","SecurityAuditSubsystem","RiskAssessmentSubsystem","ThreatDetectionSubsystem",
        }
        -- keywords that flag a method as "reporting" — lifecycle functions stay intact
        local KILL_KEYWORDS = { "report","upload","tamper","punish","ban","kick","cheat","integrity",
                                "detect","verify","scan","collect","send","secflow","submit" }
        local KEEP_KEYWORDS = { "init","start","tick","update","destroy","construct","beginplay","endplay",
                                "ctor","oninit","onstart","ontick","onupdate","ondestroy","postconstruct" }
        local function should_kill(k)
            local lk = k:lower()
            for _, keep in ipairs(KEEP_KEYWORDS) do if lk:find(keep, 1, true) then return false end end
            for _, kill in ipairs(KILL_KEYWORDS) do if lk:find(kill, 1, true) then return true end end
            return false
        end
        for _, n in ipairs(targets) do
            local s = subMgr:Get(n)
            if s then
                for k, v in pairs(s) do
                    if type(v) == "function" and should_kill(k) then pcall(function() s[k] = nop end) end
                end
                for _, tf in ipairs({"TimerHandle","timer","heartbeatTimer","reportTimer","scanTimer","checkTimer",
                                     "verifyTimer","detectTimer","banTimer","kickTimer"}) do
                    if s[tf] then pcall(function() s:RemoveGameTimer(s[tf]); s[tf] = nil end) end
                end
            end
        end
    end

    -- ============================================================
    -- 2. PACKET BLOCK — pattern based (catches future packet names)
    -- ============================================================
    local nu = _G.NetUtil
    if nu and nu.SendPacket and not nu._BypassActive then
        local orig = nu.SendPacket
        local BLOCK_PATTERNS = {
            -- pure reporting
            "report", "upload", "submit",
            -- anticheat namespaces
            "anticheat", "cheatdetect", "cheatdetection", "cheatreport",
            "securityviolation", "securityaudit", "integritycheck",
            "signatureverify", "sigcheck", "antitamper", "detectionresult",
            -- action packets
            "banplayer", "kickplayer", "notifyban", "applypunishment", "punish",
            -- subsystem flows
            "secflow", "verifyinfo", "verifyfile", "verifybytecode", "verifymodule",
            "mrpcs", "swifthawk", "higgs", "corona", "tss_", "tsssdk",
            -- scan / detect results
            "scanresult", "hookdetect", "rootdetect", "emulatordetect",
            "debugdetect", "injectiondetect", "tamperdetect", "memoryscan",
            "modulescan", "filescan", "processcheck", "startupcheck",
            "bootverify", "luaverify", "pakverify", "bytecodeverify",
            "encryptioncheck", "assetverify",
        }
        local WHITELIST = {
            -- if any of these appear as the FULL packet name, allow it
            -- (scoreboard etc. -- remove entry to be more aggressive)
        }
        local function should_block(name)
            if type(name) ~= "string" then return false end
            if WHITELIST[name] then return false end
            local l = name:lower()
            for _, pat in ipairs(BLOCK_PATTERNS) do
                if l:find(pat, 1, true) then return true end
            end
            return false
        end
        nu.SendPacket = function(name, ...)
            if should_block(name) then return nil end
            return orig(name, ...)
        end
        nu._BypassActive = true
    end

    -- ============================================================
    -- 3. GAMEPLAY CALLBACKS — nop reporting callbacks (pattern match)
    -- ============================================================
    if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
    local cb_kill_patterns = { "report","verify","secflow","upload","cheat","antitamper","punish","ban","kick","swifthawk","mrpcs","higgs","corona" }
    for k, v in pairs(_G.GameplayCallbacks) do
        if type(k) == "string" then
            local lk = k:lower()
            for _, p in ipairs(cb_kill_patterns) do
                if lk:find(p, 1, true) then _G.GameplayCallbacks[k] = nop; break end
            end
        end
    end
    _G.GameplayCallbacks.CheckReportSecAttackFlowWithAttackFlow = retFalse
    _G.GameplayCallbacks.CheckReportSecAttackFlow = retFalse

    -- ban/kick message suppress
    _G.GameplayCallbacks.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
        local s = string.lower(tostring(State or ""))
        local blocked = {"cheatdetected","banned","kicked","suspended","violationdetected","integrityfailure",
                         "securityviolation","permanentban","temporaryban","10yearban","1dayban"}
        for _, bs in ipairs(blocked) do
            if s:find(bs, 1, true) then return end
        end
        if _G.__BYPASS_ORIG_OnDSPlayerStateChanged then
            pcall(_G.__BYPASS_ORIG_OnDSPlayerStateChanged, UID, State, bPure, bSafe, Param)
        end
    end

    -- ============================================================
    -- 4. TSS SDK / TENCENT SECURITY
    -- ============================================================
    pcall(function()
        local t = package.loaded["TssSdk"] or _G.TssSdk
        if t then
            for _, fn in ipairs({"SendReportInfo","ReportAntiData","SendAntiData","ReportError","Report","Upload",
                                 "SendData","SendReport","OnReport","ReportException"}) do
                if t[fn] then t[fn] = nop end
            end
            t.ScanMemory = retTrue; t.IsEmulator = retFalse; t.CheckEnvironment = retTrue
            t.VerifyProcess = retTrue; t.Init = retTrue; t.GetFileMD5 = retMD5
            t.VerifyFileSignature = retTrue; t.CheckRoot = retFalse; t.CheckDebugger = retFalse
            t.CheckHook = retFalse; t.CheckInjection = retFalse; t.CheckTamper = retFalse
            t.CheckVirtual = retFalse; t.ScanProcess = retTrue
            t.ScanModules = retEmpty; t.ScanFiles = retEmpty
            t.GetDeviceId = function() return _G.FakeHWID_String or "00000000000000000000000000000000" end
        end
    end)

    -- ============================================================
    -- 5. HIGGS BOSON
    -- ============================================================
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck",
                                "StartAvatarCheck","ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord",
                                "ShowSecurityAlert","ServerReportAvatar","ClientReportNetAvatar",
                                "SendHisarData","Report","SendReport","Verify","Check"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.IsMHActive = retFalse
            Higgs.bMHActive = false
        end
    end)

    -- ============================================================
    -- 6. CORE UTILITY HOOKS
    -- ============================================================
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            local cmd = console.ExecuteConsoleCommand
            if cmd then
                cmd(nil, "pak.DisablePakSignatureCheck 1")
                cmd(nil, "pakchunk.EnableSignatureCheck 0")
                cmd(nil, "s.VerifyPak 0")
                cmd(nil, "sig.Check 0")
                cmd(nil, "AntiCheat.Disable 1")
                cmd(nil, "TssSdk.Disable 1")
                cmd(nil, "Higgs.Disable 1")
            end
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = retMD5
            CMode.MD5HashFile = retMD5
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
    end)

    -- ============================================================
    -- 7. DOWNLOAD / TLOG / AVATAR REPORTING
    -- ============================================================
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then
            ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop
            ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop
        end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = retFalse
            AvatarUtils.IsValidAvatar = retTrue
            AvatarUtils.CheckAvatarIntegrity = retTrue
            AvatarUtils.ReportInvalidAvatar = nop
        end
        local SMTD = import("ScreenshotMTDer")
        if SMTD then
            SMTD.MTDePicture = retEmptyStr; SMTD.ReMTDePicture = retEmptyStr
            SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then
            TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop
            TLog.Debug = nop; TLog.Report = nop
        end
    end)

    -- ============================================================
    -- 8. PLAYER CONTROLLER BAN-KICK SUPPRESS
    -- ============================================================
    pcall(function()
        local PC = import("PlayerController")
        if PC and PC.ClientReturnToMainMenuWithTextReason and not PC._bypass_hooked then
            local orig = PC.ClientReturnToMainMenuWithTextReason
            PC.ClientReturnToMainMenuWithTextReason = function(...)
                local args = {...}
                local txt = tostring(args[2] or args[1] or ""):lower()
                local blocked = {"cheat","ban","kick","suspend","violation","integrity","security"}
                for _, bs in ipairs(blocked) do if txt:find(bs, 1, true) then return end end
                return orig(...)
            end
            PC._bypass_hooked = true
        end
    end)

    print("[" .. BRAND .. " BYPASS] aggressive active")
end)

-- ====================================================================
-- MULTI-SOURCE HWID SPOOF
-- ====================================================================
local function GenHWID()
    if _G.FakeHWID_String then return _G.FakeHWID_String end
    local chars = "0123456789abcdef"
    local s = ""
    for i = 1, 32 do s = s .. chars:sub(math.random(1, 16), math.random(1, 16)) end
    _G.FakeHWID_String = s
    return s
end

local function InstallHWIDSpoof()
    local fns = {"GetDeviceId","GetUniqueDeviceId","GetLocalMacAddress","GetMachineId",
                 "GetPlatformUserName","GetAndroidId","GetAdvertisingId","GetMobileUniqueId"}
    local libs = {"KismetSystemLibrary","KismetSystemLibraryClient","GameplayStatics","KismetSystemLibraryAndroid"}
    for _, lib in ipairs(libs) do
        pcall(function()
            local L = import(lib)
            if not L then return end
            for _, fn in ipairs(fns) do
                if type(L[fn]) == "function" and not L["_hwid_"..fn] then
                    local orig = L[fn]
                    L[fn] = function(...)
                        if _G.LexusConfig and _G.LexusConfig.FakeHWID then return GenHWID() end
                        return orig(...)
                    end
                    L["_hwid_"..fn] = true
                end
            end
        end)
    end
    pcall(function()
        if slua.getDeviceId and not slua._hwid_hooked then
            local orig = slua.getDeviceId
            slua.getDeviceId = function() if _G.LexusConfig.FakeHWID then return GenHWID() end return orig() end
            slua._hwid_hooked = true
        end
        if slua.getMacAddress and not slua._mac_hooked then
            local orig = slua.getMacAddress
            slua.getMacAddress = function() if _G.LexusConfig.FakeHWID then return "02:00:00:00:00:00" end return orig() end
            slua._mac_hooked = true
        end
    end)
end

-- ====================================================================
-- BRANDING OVERLAY
-- ====================================================================
local function ShowBranding()
    if not _G.LexusConfig.ShowBrand then return end
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage("◆ " .. BRAND .. " ◆ @OFFICIALOWNER10X", 999999, 60.0, {R=1,G=0.85,B=0,A=1}, {X=1.6, Y=1.6})
        end
    end)
end

-- ====================================================================
-- MENU
-- ====================================================================
function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true
    local _FakeText = { [999000] = "◆ TESLA 10X 4.6 ◆", [999002] = "MAIN" }
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
        local StackMain = {
            { Key="M_WH", UI=AM.Switcher, Text="WALLHACK V2 (Full Mesh)", GetFunc=function() return _G.LexusConfig.WallhackV2 end, SetFunc=function(c,v) _G.LexusConfig.WallhackV2=v return true end },
            { Key="M_MESH", UI=AM.Switcher, Text="Full Dyeing (off=outline only)", GetFunc=function() return _G.LexusConfig.WallhackFullMesh end, SetFunc=function(c,v) _G.LexusConfig.WallhackFullMesh=v return true end },
            { Key="M_BR", UI=AM.Switcher, Text="Show Branding", GetFunc=function() return _G.LexusConfig.ShowBrand end, SetFunc=function(c,v) _G.LexusConfig.ShowBrand=v return true end },
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
        UIMgr._IsModMenuHook = true
    end
end

-- ====================================================================
-- WALLHACK V3 — mesh cache, robust pawn finder, distance gated
-- ====================================================================
local LinearColor = import("LinearColor")

local WH_READY   = false
local WH_SEEN    = {}
local WH_TICKS   = 0
local WH_TMR     = nil
local WH_ITV     = 0.7
local WH_SLOTS   = {0, 1, 2}
local WH_MAX_APPLY = 3
local WH_RESET_EVERY = 15
local WH_MAX_DIST_SQ = 60000 * 60000  -- 600m gate

-- per-pawn mesh cache, weak keys so we don't leak
local WH_MESH_CACHE = setmetatable({}, {__mode = "k"})

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
    end)
end

local function WH_ApplyMesh(mesh, vc, oc, full)
    if not mesh or not slua.isValid(mesh) then return end
    if mesh._isDyeingApplied then return end
    pcall(function()
        if full then
            mesh:SetDrawDyeing(true)
            mesh:SetDrawDyeingMode(1)
            mesh:SetVisibleDyeingColor(vc)
            mesh:SetOccludedDyeingColor(oc)
            mesh:SetDyeingColorFadeDistance(99999.0)
            mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        end
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
        mesh._isDyeingApplied = true
    end)
end

-- discover meshes ONCE per pawn, then reuse
local function WH_GetPawnMeshes(pawn)
    local cached = WH_MESH_CACHE[pawn]
    if cached then return cached end
    cached = {}
    local seen = {}
    local function add(m)
        if Valid(m) and not seen[m] then seen[m] = true; table.insert(cached, m) end
    end
    pcall(function() add(pawn.Mesh) end)
    pcall(function()
        local av = pawn.CharacterAvatarComp2_BP
        if not av and type(pawn.getAvatarComponent2) == "function" then av = pawn:getAvatarComponent2() end
        if av and av.GetMeshCompBySlot then
            for _, s in ipairs(WH_SLOTS) do
                local m = av:GetMeshCompBySlot(s)
                add(m)
            end
        end
    end)
    pcall(function()
        local w = type(pawn.GetCurrentWeapon) == "function" and pawn:GetCurrentWeapon()
        if Valid(w) and Valid(w.Mesh) then add(w.Mesh) end
    end)
    WH_MESH_CACHE[pawn] = cached
    return cached
end

local function WH_ApplyPawn(pawn, vc, oc, full)
    local meshes = WH_GetPawnMeshes(pawn)
    for _, m in ipairs(meshes) do WH_ApplyMesh(m, vc, oc, full) end
end

-- robust pawn list — original code called gd.GetAllPlayerCharacters / gd.GameCharacters which don't exist
local function WH_GetPawnList(gd)
    local out = {}
    local seen = {}
    local function add(c)
        if Valid(c) and not seen[c] then seen[c] = true; table.insert(out, c) end
    end
    -- 1. primary API
    if type(gd.GetAllPlayerCharacters) == "function" then
        local ok, r = pcall(gd.GetAllPlayerCharacters)
        if ok and type(r) == "table" then
            for _, c in ipairs(r) do add(c) end
        end
    end
    -- 2. common internal keys
    if #out == 0 then
        local keys = {"Characters","CharacterList","AllCharacters","PlayerCharacters","GameCharacters",
                      "CharacterMap","CharacterTable","_characters","_characterList","m_Characters"}
        for _, k in ipairs(keys) do
            local t = gd[k]
            if type(t) == "table" then
                for _, c in pairs(t) do add(c) end
                if #out > 0 then break end
            end
        end
    end
    -- 3. UGameplayStatics fallback
    if #out == 0 then
        pcall(function()
            local world = slua.getWorld()
            if not world then return end
            local arr = slua.Array(UEnums.EPropertyClass.Object)
            local cls = slua.loadObject("/Script/ShadowTrackerExtra.BRPlayerCharacter")
            if not cls then cls = slua.loadObject("/Script/ShadowTrackerExtra.STExtraSimpleCharacter") end
            if cls and UGameplayStatics then
                UGameplayStatics.GetAllActorsOfClass(world, cls, arr)
                local tbl = FuncUtil.LuaArrayToTable(arr)
                for _, c in ipairs(tbl) do add(c) end
            end
        end)
    end
    return out
end

local function WH_Tick()
    if not (_G.LexusConfig and _G.LexusConfig.WallhackV2) then
        if WH_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TMR) end end); WH_TMR = nil end
        WH_SEEN = {}; WH_TICKS = 0; WH_READY = false; WH_MESH_CACHE = setmetatable({}, {__mode = "k"})
        return
    end
    pcall(function()
        local gd = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
        local lp = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
        if not Valid(lp) then return end
        WH_SetupConsole()
        WH_TICKS = WH_TICKS + 1
        if WH_TICKS % WH_RESET_EVERY == 0 then
            WH_SEEN = {}
            -- don't clear mesh cache — meshes persist across ticks
        end
        local myTeam = lp.TeamID or 0
        local myLoc = type(lp.K2_GetActorLocation) == "function" and lp:K2_GetActorLocation() or nil
        local pawns = WH_GetPawnList(gd)
        local full = _G.LexusConfig.WallhackFullMesh
        local n = 0
        for _, pawn in ipairs(pawns) do
            if n >= WH_MAX_APPLY then break end
            if Valid(pawn) and pawn ~= lp then
                local pid = tostring(pawn.PlayerKey or pawn)
                if not WH_SEEN[pid] then
                    if (pawn.TeamID or 0) ~= myTeam and (pawn.Health or 100) > 0 then
                        local skip = false
                        if myLoc and type(pawn.K2_GetActorLocation) == "function" then
                            local pLoc = pawn:K2_GetActorLocation()
                            if pLoc then
                                local dx = (myLoc.X or 0) - (pLoc.X or 0)
                                local dy = (myLoc.Y or 0) - (pLoc.Y or 0)
                                if (dx*dx + dy*dy) > WH_MAX_DIST_SQ then skip = true end
                            end
                        end
                        if not skip then
                            local bot = false
                            pcall(function() if pawn.bIsAI or pawn.AIData then bot = true end end)
                            WH_ApplyPawn(pawn, bot and WH_BVIS or WH_VIS, bot and WH_BOCC or WH_OCC, full)
                            n = n + 1
                        end
                    end
                    WH_SEEN[pid] = true
                end
            end
        end
    end)
end

local function WH_Start()
    WH_SetupConsole()
    if WH_TMR then pcall(function() if _G.Game then _G.Game:RemoveGameTimer(WH_TMR) end end); WH_TMR = nil end
    if _G.Game and type(_G.Game.AddGameTimer) == "function" then
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

-- ====================================================================
-- SPLIT TIMERS (LAG FIX)
-- ====================================================================
local _fastTick = 0
local _slowTick = 0
local _brandCooldown = 0
local _hwid_installed = false

local function FastTick()
    _fastTick = _fastTick + 1
    if _G.LexusConfig.WallhackV2 and not WH_TMR then
        pcall(WH_Start)
    elseif not _G.LexusConfig.WallhackV2 and WH_TMR then
        pcall(WH_Stop)
    end
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(0.5, FastTick) end
end

local function SlowTick()
    _slowTick = _slowTick + 1
    -- hwid install once, then just verify hooks alive
    if not _hwid_installed then pcall(InstallHWIDSpoof); _hwid_installed = true else pcall(InstallHWIDSpoof) end
    pcall(function()
        local GD = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
        local pc = GD and GD.GetPlayerController and GD.GetPlayerController()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)
    _brandCooldown = _brandCooldown + 1
    if _brandCooldown >= 3 then
        _brandCooldown = 0
        pcall(ShowBranding)
    end
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then t.AddTimerOnce(2.0, SlowTick) end
end

-- ====================================================================
-- WELCOME
-- ====================================================================
function _G.ShowLexusVIPMenu()
    if _G.LexusMenuShown then return end
    _G.LexusMenuShown = true
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end
        local content = [[
╔═══════════════════════════════╗
║   ◆ TESLA 10X GAMING ◆        ║
║     VIP LUA 4.6 AGGRESSIVE    ║
║      ━━━━━━━━━━━━━━━━         ║
║   ✓ WALLHACK V3 (Mesh Cache)  ║
║   ✓ FPS 165 UNLOCK            ║
║   ✓ BRANDING OVERLAY          ║
║   ✓ MULTI-HWID SPOOF          ║
║   ✓ AGGRESSIVE BYPASS v2      ║
║   ✓ LAG FIXED                 ║
║   ━━━━━━━━━━━━━━━━            ║
║   Dev: @OFFICIALOWNER10X      ║
╚═══════════════════════════════╝]]
        Msg.Show(1, "◆ TESLA 10X ◆ VIP 4.6", content, function() Notify("VIP MENU ADDED! SETTINGS → PRIVACY") end, function() end, "OK", "")
    end)
end

-- ====================================================================
-- START
-- ====================================================================
InitModMenuTab()
_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
pcall(function()
    local ok, t = pcall(require, "common.time_ticker")
    if ok and t and t.AddTimerOnce then
        t.AddTimerOnce(0.5, FastTick)
        t.AddTimerOnce(1.0, SlowTick)
        t.AddTimerOnce(2.0, function() pcall(ShowBranding) end)
        t.AddTimerOnce(3.0, function() pcall(ShowLexusVIPMenu) end)
    else
        if Game and Game.AddGameTimer then
            Game:AddGameTimer(0.5, true, FastTick)
            Game:AddGameTimer(2.0, true, SlowTick)
            Game:AddGameTimer(3.0, false, ShowLexusVIPMenu)
        end
    end
end)
Notify("◆ TESLA 10X 4.6 AGGRESSIVE LOADED ◆")

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