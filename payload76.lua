local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
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

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

local function Notify(msg)
  local s = "[OfficialOwner10x\240\159\148\165VIP] " .. tostring(msg)
  pcall(function()
    if _G.LexusNotify then
      _G.LexusNotify(s)
    end
  end)
  pcall(function()
    local sh = import("ScriptHelperClient")
    if sh and sh.AddOnScreenDebugMessage then
      sh.AddOnScreenDebugMessage(s, -1, 3.0, {
        R = 1,
        G = 1,
        B = 0,
        A = 1
      }, {X = 1.2, Y = 1.2})
    end
  end)
  print(s)
end

local _slua = rawget(_G, "slua")

local function Valid(obj)
  if not obj then
    return false
  end
  if _slua and _slua.isValid then
    local ok, v = pcall(_slua.isValid, obj)
    if not ok or not v then
      return false
    end
  end
  return true
end

local C_GREEN = {
  R = 0,
  G = 255,
  B = 0,
  A = 255
}
local C_RED = {
  R = 255,
  G = 0,
  B = 0,
  A = 255
}
local C_CYAN = {
  R = 0,
  G = 255,
  B = 255,
  A = 255
}
local C_YELLOW = {
  R = 255,
  G = 255,
  B = 0,
  A = 255
}
local C_WHITE = {
  R = 255,
  G = 255,
  B = 255,
  A = 255
}
local C_BLUE_TEXT = {
  R = 0,
  G = 200,
  B = 255,
  A = 255
}
local SCALE_COLOR_V2 = {
  R = 3,
  G = 3,
  B = 0,
  A = 0
}
local GLOBAL_BONE_LIST = {
  "head",
  "neck_01",
  "pelvis",
  "upperarm_r",
  "lowerarm_r",
  "hand_r",
  "upperarm_l",
  "lowerarm_l",
  "hand_l",
  "thigh_l",
  "calf_l",
  "foot_l",
  "thigh_r",
  "calf_r",
  "foot_r"
}
_G.LexusConfig = _G.LexusConfig or {
  EspLoai9 = false,
  Esp9_Count = true,
  Esp9_Name = true,
  Esp9_HP = true,
  Esp9_Team = true,
  Esp9_Weapon = true,
  Esp9_Distance = true,
  Esp9_Line = true,
  Esp9_Skeleton = true,
  AimTouchEnable = false,
  AimTouchIgKnock = true,
  AimTouchIgBot = true,
  AimTouchVisCheck = true,
  CustomMagicBullet = false,
  AutoHead = false,
  GodMode = false,
  Crosshair = false,
  Accuracy = false,
  LessShake = false,
  CustomHRecoil = false,
  CustomVRecoil = false,
  LessRecoil = false,
  VerticalRecoil = false,
  CustomAimbot = false,
  CustomAimbotClose = false,
  UnlockFPS = false,
  IpadView = false,
  RemoveGrass = false,
  RemoveFog = false,
  BlackSky = false,
  WallhackNew = true,
  WallXuyenTuong = false,
  ColorBodyV2 = false,
  ColorBodyV3 = false,
  ColorBodyNew = false,
  EspOutline = false,
  OutlineThickness = 10,
  EspAntenna = false,
  EspLoai6 = false,
  EspLoai7 = false,
  Esp7_SoLuong = false,
  Esp7_TuThe = false,
  Esp7_VuKhi = false,
  EspVipPro = false,
  EspDistance = false,
  EspRadar = false,
  EspVip = false,
  EspLoai8 = false,
  EspLoai5 = false,
  BugManEnable = false,
  ModSkin = false,
  KillCounter = false,
  DeadBoxSkin = false,
  FakeHWID = false,
  WhiteBody = false,
  RemoveTrees = false
}
_G.LexusState = _G.LexusState or {
  LoopToken = 0,
  AimbotLoopToken = 0,
  NativeESPReady = false,
  GraphicsUnlocked = false,
  MenuStep = 0,
  LastCmdTime = 0,
  TrackedMarks = {},
  EnemyMarks = {},
  CustomTextData = {
    OuterSpeed = 10,
    InnerSpeed = 10,
    OuterRecoil = 0,
    HRecoil = 0.3,
    VRecoil = 0.3,
    IpadViewFOV = 120,
    MagicHead = 1.0,
    MagicBody = 1.0,
    MagicLegs = 1.0,
    SkinSuit = 0,
    SkinBag = 0,
    SkinHelmet = 0,
    SkinM416 = 0,
    SkinAKM = 0,
    SkinSCAR = 0,
    SkinM762 = 0,
    SkinAUG = 0,
    SkinHoney = 0,
    SkinQBZ = 0,
    SkinASM = 2,
    SkinACE32 = 0,
    SkinUMP = 6,
    SkinUZI = 0,
    SkinVector = 0,
    SkinGroza = 0,
    SkinKar98K = 0,
    SkinAWM = 2,
    SkinAMR = 0,
    SkinS12K = 0,
    SkinDBS = 0,
    SkinDacia = 0,
    SkinUAZ = 0,
    SkinCoupe = 0,
    SkinBuggy = 0,
    SkinMirado = 0,
    OutlineColor = 4,
    BugManRatio = 133
  },
  LastMagicConfigHash = "",
  MagicUpdateVersion = 1,
  PrevGraphicsState = {},
  SkinWasApplied = false
}
local limitTime = os.time({
  year = 2026,
  month = 12,
  day = 30,
  hour = 13,
  min = 59,
  sec = 0
})
local currentTime = os.time(os.date("!*t"))
local isExpired = false
pcall(function()
  local fileName = ".sys_time_cache"
  local paths = {
    "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
    "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
    "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
    "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName
  }
  local tm = package.loaded["client.logic.common.TimeManager"]
  if not tm then
    local s, r = pcall(require, "client.logic.common.TimeManager")
    if s and r then
      tm = r
    end
  end
  if tm and type(tm.GetServerTime) == "function" then
    local serverTime = tm.GetServerTime()
    if serverTime and 1700000000 < serverTime then
      currentTime = serverTime
    end
  end
  local lastSeenTime = 0
  for _, path in ipairs(paths) do
    local file = io.open(path, "r")
    if file then
      local data = file:read("*a")
      local savedTime = tonumber(data) or 0
      if lastSeenTime < savedTime then
        lastSeenTime = savedTime
      end
      file:close()
    end
  end
  if lastSeenTime > currentTime then
    currentTime = lastSeenTime
  else
    for _, path in ipairs(paths) do
      local file = io.open(path, "w")
      if file then
        file:write(tostring(currentTime))
        file:close()
      end
    end
  end
end)
isExpired = limitTime < currentTime

local function nop()
  return true
end

local function retFalse()
  return false
end

local function retZero()
  return 0
end

local function retEmpty()
  return {}
end

local function retNil()
  return nil
end

local function retTrue()
  return true
end

local function retEmptyString()
  return ""
end

local function InitializeSLUABypass()
  pcall(function()
    if slua and slua.getSignature then
      function slua.getSignature()
        return 3735928559
      end
    end
    local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
    if loader then
      loader.verifyBytecode = retTrue
      loader.checkIntegrity = retTrue
      if loader.disableSignatureCheck then
        loader.disableSignatureCheck = retTrue
      end
    end
    local slua_serialize = package.loaded["slua.serialize"]
    if slua_serialize then
      slua_serialize.check = retTrue
      slua_serialize.verify = retTrue
    end
    if jit and jit.attach then
      jit.attach(function()
      end, "bc")
    end
    if _G.slua_verify then
      _G.slua_verify = retTrue
    end
    if _G.check_slua_integrity then
      _G.check_slua_integrity = retTrue
    end
  end)
end

local function InitializeMD5Bypass()
  pcall(function()
    local console = import("KismetSystemLibrary")
    if console then
      console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
      console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
      console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
      console.ExecuteConsoleCommand(nil, "sig.Check 0")
      console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
    end
    local CMode = import("CreativeModeBlueprintLibrary")
    if CMode then
      function CMode.MD5HashByteArray()
        return "00000000000000000000000000000000"
      end
      
      function CMode.MD5HashFile()
        return "00000000000000000000000000000000"
      end
      
      function CMode.GetContentDiffData()
        return true, "BYPASSED"
      end
      
      CMode.VerifyFileIntegrity = retTrue
    end
    if _G.MD5Hash then
      function _G.MD5Hash()
        return "00000000000000000000000000000000"
      end
    end
    if _G.CRC32 then
      function _G.CRC32()
        return 0
      end
    end
    if _G.SHA1 then
      function _G.SHA1()
        return "BYPASS"
      end
    end
    local FileHashChecker = package.loaded["common.file_hash_checker"]
    if FileHashChecker then
      FileHashChecker.CheckFileMD5 = retTrue
      FileHashChecker.VerifyAll = retTrue
      
      function FileHashChecker.GetHash()
        return "BYPASS"
      end
    end
    local TssSdk = package.loaded.TssSdk or _G.TssSdk
    if TssSdk then
      function TssSdk.GetFileMD5()
        return "BYPASS"
      end
      
      TssSdk.VerifyFileSignature = retTrue
    end
    local STExtra = import("STExtraBlueprintFunctionLibrary")
    if STExtra then
      STExtra.CheckMD5 = retTrue
      
      function STExtra.GetMD5()
        return "BYPASS"
      end
      
      STExtra.VerifyFile = retTrue
    end
  end)
end

local function InitializeSkinBypass()
  pcall(function()
    local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
    if ptlog then
      ptlog.ReportEvent = nop
      ptlog.ReportDownloadResult = nop
      ptlog.ReportODPTDError = nop
      ptlog.ReportSkinError = nop
    end
    local AvatarUtils = package.loaded.AvatarUtils
    if AvatarUtils then
      AvatarUtils.CheckIsWeaponInBlackList = retFalse
      AvatarUtils.IsValidAvatar = retTrue
      AvatarUtils.CheckAvatarIntegrity = retTrue
      AvatarUtils.ReportInvalidAvatar = nop
    end
    local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
    if sub then
      sub.StartCheck = nop
      sub.ReportAbnormalFile = nop
      sub.StopCheck = nop
    end
    local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
    if eqEx then
      eqEx.Report = nop
      eqEx.SendException = nop
    end
  end)
end

local function InitializeLogBlocker()
  pcall(function()
    local SMTD = import("ScreenshotMTDer")
    if SMTD then
      function SMTD.MTDePicture()
        return ""
      end
      
      function SMTD.ReMTDePicture()
        return ""
      end
      
      SMTD.HasCaptured = retTrue
      SMTD.TakeScreenshot = nop
    end
    local TLog = package.loaded.TLog or _G.TLog
    if TLog then
      TLog.Info = nop
      TLog.Warning = nop
      TLog.Error = nop
      TLog.Debug = nop
      TLog.Report = nop
      TLog.Send = nop
      TLog.Flush = nop
    end
    local CrashSight = package.loaded.CrashSight or _G.CrashSight
    if CrashSight then
      CrashSight.ReportException = nop
      CrashSight.SetCustomData = nop
      CrashSight.Log = nop
      CrashSight.SendCrash = nop
      CrashSight.ReportUserException = nop
    end
    local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
    if GRUtils then
      GRUtils.BugglyPostExceptionFull = retFalse
      GRUtils.CheckCanBugglyPostException = retFalse
      GRUtils.ReplayReportData = nop
      GRUtils.ReportGameException = nop
      GRUtils.PostException = nop
    end
    local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
    if CTR then
      CTR.SendReport = nop
      CTR.SendException = nop
      CTR.UploadLog = nop
    end
    for _, sdk in ipairs({
      "Firebase",
      "Adjust",
      "AppsFlyer",
      "FacebookAnalytics",
      "GameAnalytics"
    }) do
      local s = _G[sdk]
      if s then
        s.logEvent = nop
        s.trackEvent = nop
        s.setEnabled = retFalse
        s.sendEvent = nop
        s.report = nop
      end
    end
  end)
end

local function InitializeScannerBlocker()
  pcall(function()
    local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubMgr then
      local subs = {
        "AFKReportorSubsystem",
        "ClientDataStatistcsSubsystem",
        "AvatarExceptionSubsystem",
        "ShootVerifySubSystemClient",
        "MemoryCheckSubsystem",
        "SpeedCheckSubsystem",
        "WallCheckSubsystem",
        "FileCheckSubsystem",
        "BehaviorScoreSubsystem"
      }
      for _, name in ipairs(subs) do
        local sub = SubMgr:Get(name)
        if sub then
          for k, v in pairs(sub) do
            if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then
              pcall(function()
                sub[k] = nop
              end)
            end
          end
          if sub.ReportPingDelayTimer then
            sub:RemoveGameTimer(sub.ReportPingDelayTimer)
            sub.ReportPingDelayTimer = nil
          end
          sub.DelayCount = 0
        end
      end
    end
    local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
    if AvaEx then
      AvaEx.CheckAvatarException = nop
      AvaEx.CheckAvatarExceptionOnce = nop
      AvaEx.ReportAvatarException = nop
      AvaEx.CheckSlotMeshVisible = retFalse
      AvaEx.CheckPawnVisible = retFalse
      AvaEx.CheckCanBugglyPostException = retFalse
    end
    local TssSdk = package.loaded.TssSdk or _G.TssSdk
    if TssSdk then
      local origData = TssSdk.OnRecvData
      
      function TssSdk.OnRecvData(data)
        if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then
          return
        end
        if origData then
          origData(data)
        end
      end
      
      TssSdk.SendReportInfo = nop
      TssSdk.ScanMemory = retTrue
      TssSdk.IsEmulator = retFalse
      TssSdk.GetTssSdkReportInfo = retEmptyString
      TssSdk.CheckEnvironment = retTrue
      TssSdk.VerifyProcess = retTrue
    end
  end)
end

local function InitializeReplayTelemetryBlocker()
  pcall(function()
    local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if SubMgr then
      for _, name in ipairs({
        "GameReportSubsystem",
        "ReplaySubsystem"
      }) do
        local sub = SubMgr:Get(name)
        if sub then
          for k, v in pairs(sub) do
            if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then
              pcall(function()
                sub[k] = nop
              end)
            end
          end
        end
      end
    end
    local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
    if logRep then
      logRep.ReportReplay = nop
      logRep.SendReportReq = nop
      logRep.UploadReplay = nop
    end
  end)
end

local function InitializeReportFlowBlocker()
  pcall(function()
    local flows = {
      "ReportAimFlow",
      "ReportHitFlow",
      "ReportAttackFlow",
      "ReportSecAttackFlow",
      "ReportFireArms",
      "ReportVerifyInfoFlow",
      "ReportMrpcsFlow",
      "ReportPlayerBehavior",
      "ReportTeammatHurt",
      "ReportMisKillByTeammate",
      "ReportForbitPick",
      "ReportPlayerMoveRoute",
      "ReportPlayerPosition",
      "ReportVehicleMoveFlow",
      "ReportSecTgameMovingFlow",
      "ReportParachuteData",
      "ReportEquipmentFlow",
      "ReportPlayersPing",
      "ReportPlayerIP",
      "ReportPlayerFramePingRecord",
      "ReportDSNetSaturation",
      "ReportNetContinuousSaturate",
      "ReportDSNetRate",
      "ReportCircleFlow",
      "ReportSecMrpcsFlow"
    }
    for _, f in ipairs(flows) do
      if _G[f] then
        _G[f] = nop
      end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then
        _G.GameplayCallbacks[f] = nop
      end
    end
    for _, f in ipairs({
      "CheckReportSecAttackFlowWithAttackFlow",
      "CheckReportSecAttackFlow"
    }) do
      if _G[f] then
        _G[f] = retFalse
      end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then
        _G.GameplayCallbacks[f] = retFalse
      end
    end
    for _, f in ipairs({
      "IsEnableReportMrpcsInCircleFlow",
      "IsEnableReportMrpcsInPartCircleFlow",
      "IsEnableReportMrpcsFlow",
      "IsEnableReportAttackFlow",
      "IsEnableReportHitFlow",
      "IsEnableReportCircleFlow"
    }) do
      if _G[f] then
        _G[f] = retFalse
      end
    end
  end)
end

local function InitializePlayerSecurityBypass()
  pcall(function()
    for _, c in ipairs({
      "PlayerSecurityInfoCollector",
      "PlayerSecurityInfo",
      "SecurityInfoCollector",
      "ClientSecurityCollector",
      "PlayerAntiCheatCollector"
    }) do
      if _G[c] then
        for k, v in pairs(_G[c]) do
          if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then
            _G[c][k] = nop
          end
        end
      end
    end
    local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
    if SecSub then
      SecSub.ReportData = nop
      SecSub.CheckCheat = retFalse
      SecSub.ValidatePlayer = retTrue
      SecSub.CollectData = nop
      SecSub.SendToServer = nop
    end
  end)
end

local function InitializeClientFlowBypass()
  pcall(function()
    for _, name in ipairs({
      "ClientSecMrpcsFlow",
      "MrpcsFlow",
      "MrpcsData",
      "ClientCircleFlowSubsystem",
      "ClientKillFlowSubsystem",
      "ClientSecPlayerKillFlow"
    }) do
      local sub = package.loaded[name] or _G[name]
      if sub then
        for k, v in pairs(sub) do
          if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then
            pcall(function()
              sub[k] = nop
            end)
          end
        end
      end
    end
  end)
end

local function InitializeSwiftHawkBypass()
  pcall(function()
    for _, f in ipairs({
      "SwiftHawk",
      "ClientSwiftHawk",
      "ClientSwiftHawkWithParams",
      "SendSwiftHawkData"
    }) do
      if _G[f] then
        _G[f] = nop
      end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then
        _G.GameplayCallbacks[f] = nop
      end
    end
    local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
    if sub then
      sub.ReportData = nop
      sub.SendReport = nop
      sub.CollectTelemetry = nop
    end
  end)
end

local function InitializeCoronaLabBypass()
  pcall(function()
    if _G.CoronaLab then
      _G.CoronaLab.ReportData = nop
      _G.CoronaLab.SendData = nop
      _G.CoronaLab.CollectData = nop
      _G.CoronaLab.Telemetry = nop
    end
    local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
    if sub then
      sub.ReportData = nop
      sub.SendToServer = nop
      sub.CollectTelemetry = nop
      sub.StopCollection = nop
    end
  end)
end

local function InitializeModifierExceptionBypass()
  pcall(function()
    if _G.bReportedModifierException then
      _G.bReportedModifierException = false
    end
    local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
    if sub then
      sub.ReportException = nop
      sub.CheckModifier = retTrue
      sub.ValidateModifier = retTrue
      sub.ReportModifierError = nop
    end
  end)
end

local function InitializeSimulateCharacterLocationBypass()
  pcall(function()
    local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
    if sub then
      sub.ReportLocation = nop
      sub.SendLocationData = nop
      sub.VerifyLocation = retTrue
    end
  end)
end

local function InitializeShootVerificationBypass()
  pcall(function()
    local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
    if sub then
      sub.OnShootVerifyFailed = nop
      sub.SendVerifyData = nop
      sub.ReportBulletHit = nop
      sub.UploadHitInfo = nop
      sub.VerifyShot = retTrue
    end
    if _G.BulletHitInfoUploadData then
      _G.BulletHitInfoUploadData.Report = nop
      _G.BulletHitInfoUploadData.Send = nop
      _G.BulletHitInfoUploadData.Upload = nop
    end
  end)
end

local function InitializeNetworkPacketBlock()
  pcall(function()
    if NetUtil and NetUtil.SendPacket then
      local orig = NetUtil.SendPacket
      local blocked = {
        ReportAttackFlow = 1,
        ReportSecAttackFlow = 1,
        ReportFireArms = 1,
        ReportVerifyInfoFlow = 1,
        ReportMrpcsFlow = 1,
        ReportPlayerBehavior = 1,
        ReportTeammatHurt = 1,
        ReportPlayerMoveRoute = 1,
        ReportPlayerPosition = 1,
        ReportSecVehicleMoveFlow = 1,
        report_parachute_data = 1,
        on_tss_sdk_anti_data = 1,
        ReportAimFlow = 1,
        ReportHitFlow = 1,
        ReportCircleFlow = 1,
        report_players_ping = 1,
        report_player_ip = 1,
        report_net_saturate = 1,
        report_speed_hack = 1,
        report_wall_hack = 1,
        report_aim_bot = 1,
        report_esp_usage = 1,
        report_modded_files = 1,
        detect_cheat = 1,
        ban_player = 1,
        client_anti_cheat_report = 1,
        ClientSecMrpcsFlow = 1,
        MrpcsData = 1,
        CheckReportSecAttackFlow = 1,
        CheckReportSecAttackFlowWithAttackFlow = 1,
        RPC_ClientCoronaLab = 1,
        CoronaLabReport = 1,
        CoronaLabData = 1,
        PlayerSecurityInfo = 1,
        ReportSecurityInfo = 1,
        SendSecurityData = 1,
        ClientCircleFlow = 1,
        IsEnableReportMrpcsInCircleFlow = 1,
        IsEnableReportMrpcsInPartCircleFlow = 1,
        bReportedModifierException = 1,
        ReportModifierException = 1,
        RPC_Server_ReportSimulateCharacterLocation = 1,
        ReportSimulateCharacterLocation = 1,
        RPC_Client_ShootVertifyRes = 1,
        BulletHitInfoUploadData = 1,
        ShootVerifyFailed = 1,
        report_unrealnet_exception = 1,
        tss_sdk_report = 1,
        SwiftHawk = 1,
        ClientSwiftHawk = 1,
        ClientSwiftHawkWithParams = 1,
        SwiftHawkReport = 1,
        SwiftHawkData = 1,
        AntiCheatReport = 1,
        CheatDetection = 1,
        ViolationReport = 1,
        SecurityViolation = 1,
        IntegrityCheck = 1,
        SignatureVerify = 1
      }
      
      function NetUtil.SendPacket(packetName, ...)
        if blocked[packetName] then
          return nil
        end
        return orig(packetName, ...)
      end
      
      NetUtil.IsBypassed = true
    end
    if _G.SendRPC then
      local origRPC = _G.SendRPC
      local blockedRPC = {
        "RPC_Server_ClientSecMrpcsFlow",
        "RPC_Server_SwiftHawk",
        "RPC_Server_ClientSwiftHawkWithParams",
        "RPC_Server_ReportSimulateCharacterLocation",
        "RPC_Client_ShootVertifyRes",
        "RPC_ClientCoronaLab"
      }
      
      function _G.SendRPC(rpcName, ...)
        for _, b in ipairs(blockedRPC) do
          if rpcName == b then
            return nil
          end
        end
        return origRPC(rpcName, ...)
      end
    end
  end)
end

local function InitializeHiggsBosonBypass()
  pcall(function()
    local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
    if Higgs then
      for _, m in ipairs({
        "ControlMHActive",
        "Tick",
        "OnTick",
        "MHActiveLogic",
        "TriggerAvatarCheck",
        "StartAvatarCheck",
        "ReportItemID",
        "ReceiveAnyDamage",
        "OnWeaponHitRecord",
        "ShowSecurityAlert",
        "ServerReportAvatar",
        "ClientReportNetAvatar",
        "SendHisarData",
        "ValidateSecurityData",
        "StaticShowSecurityAlertInDev",
        "RPC_Client_ShootVertifyRes",
        "RPC_Server_ReportSimulateCharacterLocation",
        "DisableHiggsBoson",
        "CheckMHActive",
        "ReportViolation",
        "ProcessSecurityEvent",
        "ValidatePlayer",
        "CheckIntegrity"
      }) do
        if Higgs[m] then
          Higgs[m] = nop
        end
      end
      Higgs.GetNetAvatarItemIDs = retEmpty
      Higgs.GetCurWeaponSkinID = retZero
      Higgs.IsMHActive = retFalse
      Higgs.bMHActive = false
      Higgs.bCallPreReplication = false
      if Higgs.BlackList then
        for k in pairs(Higgs.BlackList) do
          Higgs.BlackList[k] = nil
        end
      end
    end
    _G.BlackList = {}
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) then
      if pc.HiggsBoson then
        pc.HiggsBoson.bMHActive = false
        pc.HiggsBoson.bCallPreReplication = false
        if pc.HiggsBoson.ControlMHActive then
          pc.HiggsBoson:ControlMHActive(0)
        end
      end
      if pc.HiggsBosonComponent then
        pc.HiggsBosonComponent.bMHActive = false
        pc.HiggsBosonComponent.bCallPreReplication = false
        pc.HiggsBosonComponent:ControlMHActive(0)
      end
    end
  end)
end

local function InitializeAntiCheatHooks()
  pcall(function()
    local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
    if HBC and HBC.StaticShowSecurityAlertInDev then
      HBC.StaticShowSecurityAlertInDev = nop
    end
  end)
  if _G.AvatarCheckCallback then
    _G.AvatarCheckCallback.StartAvatarCheck = nop
    _G.AvatarCheckCallback.OnReportItemID = nop
    
    function _G.AvatarCheckCallback.PostPlayerControllerLoginInit(PlayerController)
      if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then
        PlayerController.HiggsBosonComponent:ControlMHActive(0)
        PlayerController.HiggsBosonComponent.bMHActive = false
      end
    end
  end
end

local function InitializeAntiReport()
  pcall(function()
    for _, path in ipairs({
      "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
      "Client.Security.ClientReportPlayerSubsystem",
      "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"
    }) do
      local sub = package.loaded[path]
      if not sub then
        local s, r = pcall(require, path)
        if s and r then
          sub = r
        end
      end
      if sub then
        for k, v in pairs(sub) do
          if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then
            pcall(function()
              sub[k] = nop
            end)
          end
        end
      end
    end
  end)
end

local function InitializeGameplayBypass()
  pcall(function()
    if not _G.GameplayCallbacks then
      _G.GameplayCallbacks = {}
    end
    if _G.GameplayCallbacks.IsBypassed then
      return
    end
    local GC = _G.GameplayCallbacks
    local reports = {
      "ReportAttackFlow",
      "ReportSecAttackFlow",
      "ReportFireArms",
      "ReportVerifyInfoFlow",
      "ReportMrpcsFlow",
      "ReportPlayerBehavior",
      "ReportTeammatHurt",
      "ReportMisKillByTeammate",
      "ReportForbitPick",
      "ReportPlayerMoveRoute",
      "ReportPlayerPosition",
      "ReportVehicleMoveFlow",
      "ReportSecTgameMovingFlow",
      "ReportParachuteData",
      "SendTssSdkAntiDataToLobby",
      "ReportEquipmentFlow",
      "ReportAimFlow",
      "ReportPlayersPing",
      "ReportPlayerIP",
      "ReportPlayerFramePingRecord",
      "OnDSConnectionSaturated",
      "ReportDSNetSaturation",
      "ReportNetContinuousSaturate",
      "ReportDSNetRate",
      "SendClientStats",
      "SendServerAvgTickDelta",
      "ReportCircleFlow",
      "ClientSecMrpcsFlow",
      "SwiftHawk",
      "ClientSwiftHawk",
      "ClientSwiftHawkWithParams"
    }
    for _, f in ipairs(reports) do
      GC[f] = nop
    end
    GC.CheckReportSecAttackFlowWithAttackFlow = retFalse
    GC.CheckReportSecAttackFlow = retFalse
    local origState = GC.OnDSPlayerStateChanged
    
    function GC.OnDSPlayerStateChanged(UID, State, bPure, bSafe, Param)
      local s = State and string.lower(tostring(State)) or ""
      local blocked = {
        cheatdetected = 1,
        connectionlost = 1,
        connectiontimeout = 1,
        connectionexception = 1,
        netdrivererror = 1,
        banned = 1,
        kicked = 1,
        suspended = 1,
        violationdetected = 1,
        integrityfailure = 1,
        securityviolation = 1
      }
      if blocked[s] then
        return
      end
      if origState then
        pcall(origState, UID, State, bPure, bSafe, Param)
      end
    end
    
    GC.OnPlayerNetConnectionClosed = nop
    GC.OnPlayerActorChannelError = nop
    GC.OnPlayerRPCValidateFailed = nop
    GC.OnPlayerSpectateException = nop
    GC.OnShutdownAfterError = nop
    GC.IsBypassed = true
  end)
end

local function InitializeKillAllSubsystems()
  pcall(function()
    local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if not subMgr then
      return
    end
    local toKill = {
      "CoronaLabSubsystem",
      "PlayerSecurityInfoSubsystem",
      "ClientCircleFlowSubsystem",
      "ModifierExceptionSubsystem",
      "SimulateCharacterSubsystem",
      "ShootVerifySubSystemClient",
      "HiggsBosonComponent",
      "ClientReportPlayerSubsystem",
      "DSReportPlayerSubsystem",
      "ClientHawkEyePatrolSubsystem",
      "DSHawkEyePatrolSubsystem",
      "ClientDataStatistcsSubsystem",
      "AFKReportorSubsystem",
      "BehaviorScoreSubsystem",
      "FileCheckSubsystem",
      "MemoryCheckSubsystem",
      "SpeedCheckSubsystem",
      "WallCheckSubsystem",
      "AvatarExceptionSubsystem",
      "GameReportSubsystem",
      "ClientSecMrpcsFlowSubsystem",
      "MrpcsFlowSubsystem",
      "CircleFlowSubsystem",
      "SwiftHawkSubsystem",
      "AntiCheatSubsystem",
      "IntegrityCheckSubsystem",
      "SignatureVerifySubsystem",
      "MD5CheckSubsystem",
      "PakVerifySubsystem"
    }
    for _, name in ipairs(toKill) do
      local sub = subMgr:Get(name)
      if sub then
        for k, v in pairs(sub) do
          if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then
            pcall(function()
              sub[k] = nop
            end)
          end
        end
        if sub.timer then
          pcall(function()
            sub:RemoveGameTimer(sub.timer)
          end)
        end
        if sub.heartbeatTimer then
          pcall(function()
            sub:RemoveGameTimer(sub.heartbeatTimer)
          end)
        end
        if sub.reportTimer then
          pcall(function()
            sub:RemoveGameTimer(sub.reportTimer)
          end)
        end
      end
    end
  end)
end

local function InitializeFinalProtection()
  pcall(function()
    for _, flag in ipairs({
      "ENABLE_REPORT",
      "ENABLE_ANTI_CHEAT",
      "ENABLE_SECURITY",
      "ENABLE_TELEMETRY",
      "ENABLE_ANALYTICS",
      "ENABLE_CRASH_REPORT",
      "ENABLE_PERFORMANCE_REPORT"
    }) do
      if _G[flag] then
        _G[flag] = false
      end
    end
    local origReq = require
    local blocked = {
      "HiggsBosonComponent",
      "PlayerSecurityInfoSubsystem",
      "CoronaLabSubsystem",
      "ClientCircleFlowSubsystem",
      "ModifierExceptionSubsystem",
      "ShootVerifySubSystemClient",
      "ClientReportPlayerSubsystem",
      "DSReportPlayerSubsystem"
    }
    
    function _G.require(m)
      for _, b in ipairs(blocked) do
        if m:find(b) then
          return {}
        end
      end
      return origReq(m)
    end
  end)
end

local function InitializeOperationalStatsBypass()
  pcall(function()
    local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    local OperationalStatsSubsystem = subMgr and subMgr:Get("OperationalStatsSubsystem") or _G.OperationalStatsSubsystem
    if OperationalStatsSubsystem then
      OperationalStatsSubsystem.ReportOperationalStats = nop
      OperationalStatsSubsystem.AddOperationalStats = nop
      OperationalStatsSubsystem.HandleTouchBegin = nop
      OperationalStatsSubsystem.HandleTouchEnd = nop
      OperationalStatsSubsystem.OnInit = nop
      OperationalStatsSubsystem.HandleEnterFighting = nop
      OperationalStatsSubsystem.OnBattleResult = nop
      if OperationalStatsSubsystem.TimerHandle then
        pcall(function()
          OperationalStatsSubsystem:RemoveGameTimer(OperationalStatsSubsystem.TimerHandle)
        end)
        OperationalStatsSubsystem.TimerHandle = nil
      end
      OperationalStatsSubsystem.StatsData = {}
      print("[ULTIMATE BYPASS] OperationalStatsSubsystem blocked!")
    end
  end)
end

local function InitializeDebugHookRemoval()
  pcall(function()
    if debug then
      if debug.sethook then
        debug.sethook()
      end
      if debug.setmetatable then
        local orig_setmt = debug.setmetatable
        
        function debug.setmetatable(t, mt)
          if t == _G then
            return
          end
          return orig_setmt(t, mt)
        end
      end
    end
    if jit then
      pcall(function()
        jit.off()
      end)
      pcall(function()
        if jit.attach then
          jit.attach(function()
          end, "bc")
        end
      end)
    end
  end)
end

local function InitializeDSStateBanFilter()
  pcall(function()
    if not _G.GameplayCallbacks then
      _G.GameplayCallbacks = {}
    end
    local GC = _G.GameplayCallbacks
    local _origState = GC.OnDSPlayerStateChanged
    
    function GC.OnDSPlayerStateChanged(UID, State, bPure, bSafe, Param)
      local s = string.lower(tostring(State or ""))
      local blocked_states = {
        "cheatdetected",
        "banned",
        "kicked",
        "suspended",
        "violationdetected",
        "integrityfailure",
        "securityviolation",
        "hackdetected",
        "moddetected",
        "anticheat",
        "permanentban",
        "temporaryban",
        "10yearban",
        "1dayban",
        "punished",
        "penalized",
        "sanctioned",
        "restricted",
        "accountsuspended",
        "cheatingpenalty",
        "fairplaybanned"
      }
      for _, bs in ipairs(blocked_states) do
        if s:find(bs, 1, true) then
          return
        end
      end
      if _origState then
        pcall(_origState, UID, State, bPure, bSafe, Param)
      end
    end
    
    local ban_rpcs = {
      "OnPlayerBanned",
      "OnPlayerKicked",
      "OnPlayerSuspended",
      "OnCheatDetected",
      "OnViolationDetected",
      "OnSecurityBan",
      "OnFairPlayBan",
      "OnPermanentBan",
      "OnTemporaryBan",
      "OnAccountSuspended",
      "NotifyBanResult",
      "OnBanNotification",
      "OnPunishmentApplied",
      "OnPenaltyApplied",
      "OnSanctionApplied",
      "OnPlayerNetConnectionClosed",
      "OnPlayerActorChannelError",
      "OnPlayerRPCValidateFailed",
      "OnShutdownAfterError"
    }
    for _, rpc in ipairs(ban_rpcs) do
      GC[rpc] = function()
      end
    end
    for _, path in ipairs({
      "GameLua.Mod.BaseMod.Client.Security.BanNotificationSubsystem",
      "GameLua.Mod.BaseMod.Client.Security.PunishmentSubsystem",
      "GameLua.Mod.BaseMod.Client.Security.FairPlaySubsystem",
      "GameLua.Mod.BaseMod.Client.AntiCheat.BanProcessSubsystem"
    }) do
      if not package.loaded[path] then
        package.preload[path] = function()
          return {
            OnBanReceived = function()
            end,
            ProcessBan = function()
            end,
            NotifyBan = function()
            end,
            ApplyPunishment = function()
            end,
            StartBanTimer = function()
            end
          }
        end
      end
    end
  end)
end

local function InitializeBanPacketAbsorber()
  pcall(function()
    if not NetUtil or not NetUtil.SendPacket then
      return
    end
    if NetUtil._BanAbsorberActive then
      return
    end
    local orig = NetUtil.SendPacket
    local ban_packets = {
      BanPlayer = 1,
      KickPlayer = 1,
      SuspendPlayer = 1,
      NotifyBan = 1,
      ApplyPunishment = 1,
      ReportCheatResult = 1,
      ProcessBanRequest = 1,
      FairPlayBan = 1,
      SecurityBan = 1,
      TemporaryBan = 1,
      PermanentBan = 1,
      AccountBan = 1,
      CheatPenalty = 1,
      ViolationPenalty = 1,
      BanNotification = 1,
      SendBanInfo = 1,
      BanResultPacket = 1,
      PunishmentPacket = 1
    }
    
    function NetUtil.SendPacket(name, ...)
      if ban_packets[name] then
        return nil
      end
      return orig(name, ...)
    end
    
    NetUtil._BanAbsorberActive = true
  end)
end

local function InitializePrintFilter()
  pcall(function()
    if _G._PrintFilterActive then
      return
    end
    local orig_print = print
    
    function print(...)
      local args = {
        ...
      }
      for _, v in ipairs(args) do
        local s = tostring(v)
        if s:find("OfficialOwner10x\240\159\148\165", 1, true) or s:find("ESP", 1, true) or s:find("Bypass", 1, true) or s:find("Aimbot", 1, true) or s:find("bypass", 1, true) or s:find("BYPASS", 1, true) or s:find("StartBypass", 1, true) or s:find("VIP", 1, true) then
          return
        end
      end
      orig_print(...)
    end
    
    _G._PrintFilterActive = true
  end)
end

local function InitializeMetatableShield()
  pcall(function()
    local orig_mt = getmetatable(_G) or {}
    local orig_index = orig_mt.__index
    
    function orig_mt.__index(t, k)
      if k == "_lost_vibe404\240\159\148\165_BYPASS_DONE" or k == "_bypass_active" then
        return nil
      end
      if orig_index then
        return orig_index(t, k)
      end
      return rawget(t, k)
    end
    
    setmetatable(_G, orig_mt)
  end)
end

local function InitializeSubsystemTimerKiller()
  pcall(function()
    local subMgr
    pcall(function()
      subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    end)
    if not subMgr then
      return
    end
    local timerSubs = {
      "CoronaLabSubsystem",
      "SwiftHawkSubsystem",
      "BehaviorScoreSubsystem",
      "ClientDataStatistcsSubsystem",
      "AFKReportorSubsystem",
      "AntiCheatSubsystem",
      "IntegrityCheckSubsystem",
      "ClientReportPlayerSubsystem",
      "DSReportPlayerSubsystem",
      "GameReportSubsystem",
      "TelemetrySubsystem",
      "OperationalStatsSubsystem",
      "MD5CheckSubsystem"
    }
    for _, name in ipairs(timerSubs) do
      pcall(function()
        local sub = subMgr:Get(name)
        if not sub then
          return
        end
        for _, field in ipairs({
          "TimerHandle",
          "timer",
          "heartbeatTimer",
          "reportTimer",
          "scanTimer",
          "checkTimer",
          "uploadTimer",
          "sendTimer",
          "collectTimer",
          "telemetryTimer",
          "statsTimer"
        }) do
          if sub[field] then
            pcall(function()
              sub:RemoveGameTimer(sub[field])
              sub[field] = nil
            end)
          end
        end
        if sub.OnInit then
          function sub.OnInit()
          end
        end
        if sub.StartTimer then
          function sub.StartTimer()
          end
        end
        if sub.RestartTimer then
          function sub.RestartTimer()
          end
        end
      end)
    end
  end)
end

function _G.StartBypass_VIP_v3()
  pcall(function()
    print("[ULTIMATE BYPASS] Starting initialization...")
    InitializeSLUABypass()
    InitializeMD5Bypass()
    InitializeSkinBypass()
    InitializeLogBlocker()
    InitializeScannerBlocker()
    InitializeReplayTelemetryBlocker()
    InitializeReportFlowBlocker()
    InitializePlayerSecurityBypass()
    InitializeClientFlowBypass()
    InitializeSwiftHawkBypass()
    InitializeCoronaLabBypass()
    InitializeModifierExceptionBypass()
    InitializeSimulateCharacterLocationBypass()
    InitializeShootVerificationBypass()
    InitializeNetworkPacketBlock()
    InitializeHiggsBosonBypass()
    InitializeAntiCheatHooks()
    InitializeAntiReport()
    InitializeGameplayBypass()
    InitializeKillAllSubsystems()
    InitializeOperationalStatsBypass()
    InitializeFinalProtection()
    InitializeDebugHookRemoval()
    InitializeDSStateBanFilter()
    InitializeBanPacketAbsorber()
    InitializePrintFilter()
    InitializeMetatableShield()
    InitializeSubsystemTimerKiller()
    print("[OfficialOwner10x\240\159\148\165 BYPASS v5] All 28 layers active - 10yr/1day ban blocked")
  end)
end

local function SafeAddMark(id, pos, z, str, size, actor)
  local mark
  pcall(function()
    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
    if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
      mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
      if mark then
        _G.LexusState.TrackedMarks[mark] = true
      end
    end
  end)
  return mark
end

local function SafeRemoveMark(mark)
  if not mark then
    return
  end
  pcall(function()
    local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
    if InGameMarkTools and InGameMarkTools.HideMapMark then
      InGameMarkTools.HideMapMark(mark)
    end
    if InGameMarkTools and InGameMarkTools.RemoveMapMark then
      InGameMarkTools.RemoveMapMark(mark)
    end
  end)
  _G.LexusState.TrackedMarks[mark] = nil
end

local function GetSafeEnemyKey(enemy)
  if Valid(enemy) then
    if enemy.PlayerKey then
      return tostring(enemy.PlayerKey)
    end
    if type(enemy.GetUniqueID) == "function" then
      return tostring(enemy:GetUniqueID())
    end
  end
  return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
  if markData.AK_IS_BOT ~= nil then
    return markData.AK_IS_BOT, true
  end
  local isAI = false
  local hasChecked = false
  pcall(function()
    if pawn.bIsAI == true or pawn.IsAI == true then
      isAI = true
      hasChecked = true
    end
    if type(pawn.IsBot) == "function" and pawn:IsBot() then
      isAI = true
      hasChecked = true
    end
    local pState = pawn.PlayerState or type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState()
    if Valid(pState) then
      hasChecked = true
      if pState.bIsABot == true or pState.bIsBot == true then
        isAI = true
      end
      if type(pState.IsBot) == "function" and pState:IsBot() then
        isAI = true
      end
    end
    if not isAI then
      local name = pawn.PlayerName or type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName() or ""
      if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
        isAI = true
        hasChecked = true
      end
    end
  end)
  if hasChecked then
    markData.AK_IS_BOT = isAI
  end
  return isAI, hasChecked
end

local function GetConfigPaths(fileName)
  local paths = {
    "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
    "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
    "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
    fileName
  }
  pcall(function()
    if os and os.getenv then
      local homeDir = os.getenv("HOME")
      if homeDir and homeDir ~= "" then
        table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
        table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
      end
    end
  end)
  return paths
end

local ConfigFileName = "10XGAMING_settings.txt"
_G.LastConfigSaveStr = ""

function _G.SaveModSettings()
  pcall(function()
    local data = [[
return {
LexusConfig = {
]]
    for k, v in pairs(_G.LexusConfig or {}) do
      data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
    end
    data = data .. [[
},
CustomTextData = {
]]
    if _G.LexusState and _G.LexusState.CustomTextData then
      for k, v in pairs(_G.LexusState.CustomTextData) do
        data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
      end
    end
    data = data .. [[
}
}]]
    if data == _G.LastConfigSaveStr then
      return
    end
    _G.LastConfigSaveStr = data
    local paths = GetConfigPaths(ConfigFileName)
    for _, path in ipairs(paths) do
      local file = io.open(path, "w")
      if file then
        file:write(data)
        file:close()
        break
      end
    end
  end)
end

function _G.LoadModSettings()
  pcall(function()
    local paths = GetConfigPaths(ConfigFileName)
    local content
    for _, path in ipairs(paths) do
      local file = io.open(path, "r")
      if file then
        content = file:read("*a")
        file:close()
        break
      end
    end
    if content then
      local func = load(content)
      if func then
        local savedData = func()
        if savedData and type(savedData) == "table" then
          if savedData.LexusConfig then
            for k, v in pairs(savedData.LexusConfig) do
              _G.LexusConfig[k] = v
            end
          end
          if savedData.CustomTextData then
            _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
            for k, v in pairs(savedData.CustomTextData) do
              _G.LexusState.CustomTextData[k] = v
            end
          end
        end
      end
    end
    _G.SaveModSettings()
  end)
end

local function AutoSaveLoop()
  pcall(function()
    if _G.SaveModSettings then
      _G.SaveModSettings()
    end
  end)
  pcall(function()
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
      ticker.AddTimerOnce(3.0, AutoSaveLoop)
    end
  end)
end

if not _G.ModConfigLoaded then
  _G.LoadModSettings()
  AutoSaveLoop()
  _G.ModConfigLoaded = true
end

function _G.ReadLiveConfig()
  if _G.SaveModSettings then
    _G.SaveModSettings()
  end
end

_G.ColorConfig = _G.ColorConfig or {
  VisibleColor = 4,
  InvisibleColor = 1,
  Brightness = 25,
  Glow = 3.0
}
local COLOR_MAP = {
  [1] = {
    R = 255,
    G = 0,
    B = 0
  },
  [2] = {
    R = 255,
    G = 255,
    B = 255
  },
  [3] = {
    R = 255,
    G = 255,
    B = 0
  },
  [4] = {
    R = 0,
    G = 255,
    B = 0
  },
  [5] = {
    R = 0,
    G = 255,
    B = 255
  },
  [6] = {
    R = 0,
    G = 0,
    B = 255
  },
  [7] = {
    R = 255,
    G = 0,
    B = 255
  }
}

local function GetAppliedColor(colorIdx, brightness)
  local base = COLOR_MAP[colorIdx] or COLOR_MAP[4]
  local b = brightness or _G.ColorConfig.Brightness or 25
  return {
    R = math.min(255, (base.R or 0) * b / 25),
    G = math.min(255, (base.G or 0) * b / 25),
    B = math.min(255, (base.B or 0) * b / 25),
    A = 255
  }
end

_G.VIP_Attachments = {
  [1101004236] = {
    1010042307,
    1010042306,
    1010042308,
    1010042304,
    1010042300,
    1010042305,
    1010042299,
    1010042298,
    1010042297,
    1010042296,
    1010042295,
    1010042294,
    0,
    1010042314,
    1010042309,
    1010042316,
    1010042317,
    1010042318,
    1010042310,
    1010042315,
    1010042319,
    0
  },
  [1101001116] = {
    1010011106,
    1010011107,
    1010011108,
    0,
    1010011109,
    1010011112,
    1010011105,
    1010011104,
    1010011103,
    0,
    1010011102,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1101001128] = {
    1010011232,
    1010011233,
    1010011234,
    1010011228,
    1010011227,
    1010011229,
    1010011226,
    1010011225,
    1010011224,
    1010011223,
    1010011222,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1101001154] = {
    1010011487,
    1010011488,
    1010011489,
    1010011493,
    1010011490,
    1010011494,
    1010011486,
    1010011485,
    1010011484,
    1010011483,
    1010011482,
    1010011497,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010011498,
    0
  },
  [1101001174] = {
    1010011667,
    1010011668,
    1010011669,
    1010011673,
    1010011670,
    1010011674,
    1010011666,
    1010011665,
    1010011664,
    1010011663,
    1010011662,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1101001213] = {
    1010012067,
    1010012068,
    1010012069,
    1010012072,
    1010012070,
    1010012073,
    1010012066,
    1010012065,
    1010012064,
    1010012063,
    1010012062,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010012074,
    0
  },
  [1101001231] = {
    1010012267,
    1010012268,
    1010012269,
    1010012273,
    1010012272,
    1010012274,
    1010012266,
    1010012265,
    1010012264,
    1010012263,
    1010012262,
    1010012075,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010012275,
    0
  },
  [1101001242] = {
    1010012357,
    1010012358,
    1010012359,
    1010012363,
    1010012362,
    1010012364,
    1010012356,
    1010012355,
    1010012354,
    1010012353,
    1010012352,
    1010012276,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010012365,
    0
  },
  [1101001249] = {
    1010012437,
    1010012438,
    1010012439,
    1010012443,
    1010012442,
    1010012444,
    1010012436,
    1010012435,
    1010012434,
    1010012433,
    1010012432,
    1010012366,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010012445,
    0
  },
  [1101001256] = {
    1010012588,
    1010012589,
    1010012590,
    1010012593,
    1010012592,
    1010012594,
    1010012587,
    1010012586,
    1010012585,
    1010012584,
    1010012583,
    1010012582,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010012595,
    0
  },
  [1101001265] = {
    1010012698,
    1010012699,
    1010012700,
    1010012703,
    1010012702,
    1010012704,
    1010012697,
    1010012696,
    1010012695,
    1010012694,
    1010012693,
    1010012692,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010012705,
    0
  },
  [1101001276] = {
    1010012698,
    1010012699,
    1010012700,
    1010012703,
    1010012702,
    1010012704,
    1010012697,
    1010012696,
    1010012695,
    1010012694,
    1010012693,
    1010012692,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010012705,
    0
  },
  [1101002029] = {
    1010020249,
    1010020250,
    1010020255,
    1010020247,
    1010020246,
    1010020248,
    1010020240,
    1010020239,
    1010020238,
    1010020237,
    1010020236,
    1010020235,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010020257,
    1010020256,
    1010020258
  },
  [1101002056] = {
    1010020519,
    0,
    0,
    1010020517,
    1010020516,
    1010020518,
    1010020500,
    1010020509,
    1010020508,
    1010020507,
    1010020506,
    1010020505,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1101002081] = {
    1010020768,
    1010020769,
    1010020770,
    1010020766,
    1010020760,
    1010020767,
    1010020759,
    1010020758,
    1010020757,
    1010020756,
    1010020755,
    1010020776,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010020775,
    1010020777,
    1010020778
  },
  [1101003070] = {
    1010030654,
    1010030653,
    1010030655,
    1010030649,
    1010030648,
    1010030650,
    1010030647,
    1010030646,
    1010030645,
    1010030644,
    1010030643,
    1010030642,
    0,
    1010030658,
    1010030656,
    1010030660,
    1010030662,
    1010030659,
    1010030657,
    0,
    1010030663,
    0
  },
  [1101003080] = {
    1010030754,
    1010030753,
    1010030755,
    1010030749,
    1010030748,
    1010030750,
    1010030747,
    1010030746,
    1010030745,
    1010030744,
    1010030743,
    1010030742,
    0,
    1010030758,
    1010030756,
    1010030760,
    1010030762,
    1010030759,
    1010030757,
    0,
    1010030763,
    0
  },
  [1101003099] = {
    1010030943,
    1010030944,
    1010030945,
    1010030939,
    1010030938,
    1010030942,
    1010030937,
    1010030936,
    1010030935,
    1010030934,
    1010030933,
    1010030932,
    0,
    1010030947,
    1010030946,
    1010030948,
    1010030949,
    1010030953,
    1010030952,
    0,
    1010030955,
    0
  },
  [1101003119] = {
    1010031139,
    1010031140,
    1010031142,
    1010031138,
    1010031137,
    1010031146,
    1010031136,
    1010031135,
    1010031134,
    1010031133,
    1010031132,
    0,
    0,
    1010031144,
    1010031143,
    0,
    0,
    0,
    1010031145,
    0,
    0,
    0
  },
  [1101003146] = {
    1010031229,
    1010031230,
    1010031237,
    1010031228,
    1010031227,
    1010031242,
    1010031226,
    1010031225,
    1010031224,
    1010031223,
    1010031222,
    0,
    0,
    1010031239,
    1010031238,
    0,
    0,
    0,
    1010031240,
    0,
    0,
    0
  },
  [1101003167] = {
    1010031609,
    1010031610,
    1010031613,
    1010031608,
    1010031607,
    1010031617,
    1010031606,
    1010031605,
    1010031604,
    1010031603,
    1010031602,
    1010031618,
    0,
    1010031615,
    1010031614,
    1010031620,
    1010031622,
    1010031619,
    1010031616,
    0,
    1010031623,
    0
  },
  [1101003181] = {
    1010031765,
    1010031764,
    1010031766,
    1010031759,
    1010031758,
    1010031763,
    1010031757,
    1010031756,
    1010031755,
    1010031754,
    1010031753,
    1010031752,
    0,
    1010031769,
    1010031767,
    1010031773,
    1010031774,
    1010031772,
    1010031768,
    0,
    1010031775,
    0
  },
  [1101003195] = {
    1010031912,
    1010031911,
    1010031913,
    1010031908,
    1010031907,
    1010031909,
    1010031906,
    1010031905,
    1010031904,
    1010031903,
    1010031902,
    1010031901,
    0,
    1010031916,
    1010031914,
    1010031918,
    1010031919,
    1010031917,
    1010031915,
    0,
    1010031921,
    0
  },
  [1101003208] = {
    1010032034,
    1010032033,
    1010032045,
    1010032029,
    1010032028,
    1010032032,
    1010032027,
    1010032026,
    1010032025,
    1010032024,
    1010032023,
    1010032022,
    0,
    1010032038,
    1010032036,
    1010032042,
    1010032043,
    1010032039,
    1010032037,
    0,
    1010032044,
    0
  },
  [1101004046] = {
    1010040474,
    1010040475,
    1010040476,
    1010040472,
    1010040471,
    1010040473,
    1010040470,
    1010040469,
    1010040468,
    1010040467,
    1010040466,
    1010040481,
    0,
    1010040479,
    1010040477,
    1010040482,
    1010040483,
    1010040484,
    1010040478,
    1010040480,
    1010040485,
    0
  },
  [1101004062] = {
    1010040578,
    1010040577,
    1010040579,
    1010040575,
    1010040570,
    1010040576,
    1010040569,
    1010040568,
    1010040567,
    1010040566,
    1010040565,
    1010040564,
    0,
    1010040585,
    1010040580,
    1010040587,
    1010040588,
    1010040589,
    1010040584,
    1010040586,
    1010040590,
    1010040594
  },
  [1101004098] = {
    1010040924,
    1010040926,
    1010040925,
    0,
    1010040937,
    1010040938,
    1010040935,
    1010040934,
    1010040929,
    1010040928,
    1010040927,
    0,
    0,
    1010040939,
    1010040945,
    0,
    0,
    0,
    1010040944,
    1010040936,
    0,
    0
  },
  [1101004138] = {
    1010041136,
    1010041137,
    1010041138,
    1010041134,
    1010041129,
    1010041135,
    1010041128,
    1010041127,
    1010041126,
    1010041125,
    1010041124,
    0,
    0,
    1010041145,
    1010041139,
    0,
    0,
    0,
    1010041144,
    1010041146,
    0,
    0
  },
  [1101004163] = {
    1010041570,
    1010041574,
    1010041575,
    1010041568,
    1010041567,
    1010041569,
    1010041566,
    1010041565,
    1010041564,
    1010041560,
    1010041554,
    0,
    0,
    1010041578,
    1010041576,
    0,
    0,
    0,
    1010041577,
    1010041579,
    0,
    0
  },
  [1101004201] = {
    1010041956,
    1010041957,
    1010041958,
    1010041950,
    1010041949,
    1010041955,
    1010041948,
    1010041947,
    1010041946,
    1010041945,
    1010041944,
    1010041967,
    0,
    1010041965,
    1010041959,
    0,
    0,
    0,
    1010041960,
    1010041966,
    0,
    0
  },
  [1101004209] = {
    1010042038,
    1010042037,
    1010042039,
    1010042035,
    1010042034,
    1010042036,
    1010042029,
    1010042028,
    1010042027,
    1010042026,
    1010042025,
    1010042024,
    0,
    1010042046,
    1010042044,
    1010042048,
    1010042049,
    1010042054,
    1010042045,
    1010042047,
    1010042055,
    0
  },
  [1101004218] = {
    1010042128,
    1010042127,
    1010042129,
    1010042125,
    1010042124,
    1010042126,
    1010042119,
    1010042118,
    1010042117,
    1010042116,
    1010042115,
    1010042114,
    0,
    1010042136,
    1010042134,
    1010042138,
    1010042139,
    1010042144,
    1010042135,
    1010042137,
    1010042145,
    0
  },
  [1101004226] = {
    1010042238,
    1010042237,
    1010042239,
    1010042235,
    1010042234,
    1010042236,
    1010042233,
    1010042232,
    1010042231,
    1010042219,
    1010042218,
    1010042217,
    0,
    1010042243,
    1010042241,
    1010042245,
    1010042246,
    1010042247,
    1010042242,
    1010042244,
    1010042248,
    0
  },
  [1101004246] = {
    1010042406,
    1010042407,
    1010042408,
    1010042404,
    1010042400,
    1010042405,
    1010042399,
    1010042398,
    1010042397,
    1010042396,
    1010042395,
    1010042394,
    0,
    1010042414,
    1010042409,
    1010042416,
    1010042417,
    1010042418,
    1010042410,
    1010042415,
    1010042419,
    1010042420
  },
  [1101005038] = {
    0,
    0,
    1010050327,
    1010050329,
    1010050328,
    1010050330,
    1010050326,
    1010050325,
    1010050324,
    1010050323,
    1010050322,
    1010050334,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1101005052] = {
    0,
    0,
    1010050467,
    1010050469,
    1010050468,
    1010050470,
    1010050466,
    1010050465,
    1010050464,
    1010050463,
    1010050462,
    1010050473,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1101005098] = {
    0,
    0,
    1010050928,
    1010050930,
    1010050929,
    1010050932,
    1010050927,
    1010050926,
    1010050925,
    1010050924,
    1010050923,
    1010050922,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1101006062] = {
    1010060573,
    1010060572,
    1010060574,
    1010060564,
    1010060563,
    1010060571,
    1010060562,
    1010060561,
    1010060554,
    1010060553,
    1010060552,
    1010060551,
    0,
    1010060583,
    1010060581,
    1010060591,
    1010060592,
    1010060584,
    1010060582,
    0,
    1010060593,
    0
  },
  [1101006075] = {
    1010060702,
    1010060701,
    1010060703,
    1010060698,
    1010060697,
    1010060699,
    1010060696,
    1010060695,
    1010060694,
    1010060693,
    1010060692,
    1010060691,
    0,
    1010060706,
    1010060704,
    1010060708,
    1010060709,
    1010060707,
    1010060705,
    0,
    1010060711,
    0
  },
  [1101006085] = {
    1010060796,
    1010060795,
    1010060797,
    1010060793,
    1010060789,
    1010060794,
    1010060788,
    1010060787,
    1010060786,
    1010060785,
    1010060784,
    1010060783,
    0,
    1010060800,
    1010060798,
    1010060804,
    1010060805,
    1010060803,
    1010060799,
    0,
    1010060806,
    0
  },
  [1101007046] = {
    1010070410,
    1010070413,
    1010070414,
    1010070408,
    1010070407,
    1010070409,
    1010070406,
    1010070405,
    1010070404,
    1010070403,
    1010070402,
    1010070418,
    0,
    1010070417,
    1010070415,
    1010070420,
    1010070422,
    1010070419,
    1010070416,
    0,
    1010070423,
    0
  },
  [1101007062] = {
    1010070579,
    1010070578,
    1010070581,
    1010070576,
    1010070575,
    1010070577,
    1010070574,
    1010070573,
    1010070572,
    1010070571,
    1010070569,
    1010070568,
    0,
    1010070584,
    1010070582,
    1010070585,
    1010070586,
    1010070587,
    1010070583,
    0,
    1010070588,
    0
  },
  [1101007071] = {
    1010070663,
    1010070662,
    1010070664,
    1010070659,
    1010070658,
    1010070660,
    1010070657,
    1010070656,
    1010070655,
    1010070654,
    1010070653,
    1010070652,
    0,
    1010070667,
    1010070665,
    1010070668,
    1010070669,
    1010070670,
    1010070666,
    0,
    1010070672,
    0
  },
  [1101008051] = {
    1010080463,
    1010080464,
    1010080465,
    1010080459,
    1010080458,
    1010080462,
    1010080457,
    1010080456,
    1010080455,
    1010080454,
    1010080453,
    1010080452,
    0,
    1010080467,
    1010080466,
    1010080468,
    1010080469,
    1010080473,
    1010080472,
    0,
    1010080475,
    0
  },
  [1101008061] = {
    1010080563,
    1010080564,
    1010080565,
    1010080559,
    1010080558,
    1010080562,
    1010080557,
    1010080556,
    1010080555,
    1010080554,
    1010080553,
    0,
    0,
    1010080567,
    1010080566,
    0,
    0,
    0,
    1010080572,
    0,
    0,
    0
  },
  [1101008070] = {
    1010080609,
    1010080612,
    1010080613,
    1010080608,
    1010080607,
    1010080617,
    1010080606,
    1010080605,
    1010080604,
    1010080603,
    1010080602,
    0,
    0,
    1010080615,
    1010080614,
    0,
    0,
    0,
    1010080616,
    0,
    0,
    0
  },
  [1101008081] = {
    1010080740,
    1010080743,
    1010080745,
    1010080738,
    1010080737,
    1010080739,
    1010080736,
    1010080735,
    1010080734,
    1010080733,
    1010080732,
    1010080748,
    0,
    1010080747,
    1010080746,
    1010080750,
    1010080752,
    1010080749,
    1010080744,
    0,
    1010080753,
    0
  },
  [1101008104] = {
    1010080980,
    1010080982,
    1010080984,
    1010080978,
    1010080977,
    1010080979,
    1010080976,
    1010080975,
    1010080974,
    1010080973,
    1010080972,
    1010080992,
    0,
    1010080986,
    1010080985,
    1010080989,
    1010080987,
    1010080993,
    1010080983,
    0,
    1010080988,
    0
  },
  [1101008116] = {
    1010081110,
    1010081112,
    1010081114,
    1010081108,
    1010081107,
    1010081109,
    1010081106,
    1010081105,
    1010081104,
    1010081103,
    1010081102,
    0,
    0,
    1010081116,
    1010081115,
    0,
    0,
    0,
    1010081113,
    0,
    0,
    0
  },
  [1101008126] = {
    1010081210,
    1010081225,
    1010081226,
    1010081208,
    1010081207,
    1010081209,
    1010081206,
    1010081205,
    1010081204,
    1010081203,
    1010081202,
    1010081218,
    0,
    1010081217,
    1010081216,
    1010081219,
    1010081220,
    1010081222,
    1010081214,
    1010081228,
    1010081227,
    1010081229
  },
  [1101008136] = {
    1010081314,
    1010081315,
    1010081316,
    1010081312,
    1010081308,
    1010081313,
    1010081307,
    1010081306,
    1010081305,
    1010081304,
    1010081303,
    1010081302,
    0,
    1010081318,
    1010081317,
    1010081322,
    1010081323,
    1010081325,
    1010081324,
    0,
    1010081326,
    0
  },
  [1101008146] = {
    1010081401,
    1010081402,
    1010081403,
    1010081398,
    1010081397,
    1010081399,
    1010081396,
    1010081395,
    1010081394,
    1010081393,
    1010081392,
    1010081391,
    0,
    1010081405,
    1010081404,
    1010081406,
    1010081407,
    1010081409,
    1010081408,
    0,
    1010081411,
    0
  },
  [1101008154] = {
    1010081531,
    1010081532,
    1010081533,
    1010081528,
    1010081527,
    1010081529,
    1010081526,
    1010081525,
    1010081524,
    1010081523,
    1010081522,
    1010081521,
    0,
    1010081541,
    1010081534,
    1010081542,
    1010081543,
    1010081545,
    1010081544,
    0,
    1010081546,
    0
  },
  [1101008163] = {
    1010081582,
    1010081583,
    1010081584,
    1010081579,
    1010081578,
    1010081580,
    1010081577,
    1010081576,
    1010081575,
    1010081574,
    1010081573,
    1010081572,
    0,
    1010081586,
    1010081585,
    1010081587,
    1010081588,
    1010081590,
    1010081589,
    0,
    1010081592,
    0
  },
  [1101012033] = {
    1010120284,
    1010120285,
    1010120286,
    1010120280,
    1010120279,
    1010120283,
    1010120278,
    1010120277,
    1010120276,
    1010120275,
    1010120274,
    1010120273,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1010120287,
    0
  },
  [1101100012] = {
    1011000066,
    1011000067,
    1011000068,
    0,
    0,
    0,
    1011000058,
    1011000057,
    1011000056,
    1011000055,
    1011000054,
    1011000053,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1011000073,
    0
  },
  [1101102007] = {
    1011010025,
    1011010024,
    1011010026,
    1011010020,
    1011010019,
    1011010023,
    1011010018,
    1011010017,
    1011010016,
    1011010015,
    1011010014,
    1011010013,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1011010027,
    0
  },
  [1101102017] = {
    1011020027,
    1011020028,
    1011020029,
    1011020025,
    1011020024,
    1011020026,
    1011020019,
    1011020018,
    1011020017,
    1011020016,
    1011020015,
    1011020014,
    0,
    1011020036,
    1011020034,
    1011020038,
    1011020039,
    1011020044,
    1011020035,
    1011020037,
    1011020045,
    1011020047
  },
  [1101102025] = {
    1011020127,
    1011020128,
    1011020129,
    1011020125,
    1011020124,
    1011020126,
    1011020119,
    1011020118,
    1011020117,
    1011020116,
    1011020115,
    1011020114,
    0,
    1011020136,
    1011020134,
    1011020138,
    1011020139,
    1011020144,
    1011020135,
    1011020137,
    1011020145,
    0
  },
  [1101102041] = {
    1011020214,
    1011020215,
    1011020216,
    1011020212,
    1011020211,
    1011020213,
    1011020209,
    1011020208,
    1011020207,
    1011020206,
    1011020205,
    1011020204,
    0,
    1011020219,
    1011020217,
    1011020222,
    1011020223,
    1011020224,
    1011020218,
    1011020221,
    1011020225,
    1011020229
  },
  [1101102049] = {
    1011020356,
    1011020357,
    1011020358,
    1011020354,
    1011020350,
    1011020355,
    1011020349,
    1011020348,
    1011020347,
    1011020346,
    1011020345,
    1011020344,
    0,
    1011020364,
    1011020359,
    1011020366,
    1011020367,
    1011020368,
    1011020360,
    1011020365,
    1011020369,
    1011020370
  },
  [1101101007] = {
    1011020436,
    1011020437,
    1011020438,
    1011020434,
    1011020430,
    1011020435,
    1011020429,
    1011020428,
    1011020427,
    1011020426,
    1011020425,
    1011020424,
    0,
    1011020444,
    1011020439,
    1011020446,
    1011020447,
    1011020448,
    1011020440,
    1011020445,
    1011020449,
    1011020450
  },
  [1102001120] = {
    1020011137,
    1020011138,
    1020011139,
    1020011135,
    1020011134,
    1020011136,
    1020011133,
    1020011132,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1020011142,
    0,
    0
  },
  [1102001130] = {
    1020011247,
    1020011248,
    1020011249,
    1020011245,
    1020011244,
    1020011246,
    1020011243,
    1020011242,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1020011250,
    0,
    0
  },
  [1102002043] = {
    1020020372,
    1020020374,
    1020020373,
    1020020383,
    1020020380,
    1020020384,
    1020020379,
    1020020378,
    1020020377,
    1020020376,
    1020020375,
    1020020388,
    0,
    1020020385,
    1020020387,
    0,
    0,
    0,
    1020020386,
    0,
    0,
    0
  },
  [1102002061] = {
    1020020552,
    1020020554,
    1020020553,
    1020020563,
    1020020562,
    1020020564,
    1020020559,
    1020020558,
    1020020557,
    1020020556,
    1020020555,
    1020020578,
    0,
    1020020565,
    1020020567,
    1020020573,
    1020020574,
    1020020572,
    1020020566,
    0,
    1020020569,
    0
  },
  [1102002136] = {
    1020021314,
    1020021313,
    1020021315,
    1020021309,
    1020021308,
    1020021312,
    1020021307,
    1020021306,
    1020021305,
    1020021304,
    1020021303,
    1020021302,
    0,
    1020021318,
    1020021316,
    1020021323,
    1020021324,
    1020021322,
    1020021317,
    0,
    1020021325,
    0
  },
  [1102002424] = {
    1020024193,
    1020024192,
    1020024194,
    1020024189,
    1020024188,
    1020024190,
    1020024187,
    1020024186,
    1020024185,
    1020024184,
    1020024183,
    1020024182,
    0,
    1020024197,
    1020024195,
    1020024199,
    1020024200,
    1020024198,
    1020024196,
    0,
    1020024202,
    0
  },
  [1102003080] = {
    1020030755,
    1020030756,
    1020030758,
    0,
    1020030749,
    1020030754,
    1020030748,
    1020030747,
    1020030746,
    1020030745,
    1020030744,
    1020030764,
    0,
    1020030760,
    0,
    1020030759,
    1020030757,
    0,
    0,
    1020030765,
    0,
    0
  },
  [1102003100] = {
    1020030956,
    1020030957,
    1020030958,
    1020030954,
    1020030950,
    1020030955,
    1020030949,
    1020030948,
    1020030947,
    1020030946,
    1020030945,
    1020030944,
    0,
    1020030964,
    0,
    1020030960,
    1020030959,
    1020030965,
    0,
    1020030967,
    1020030966,
    1020030968
  },
  [1102005064] = {
    1020050588,
    1020050589,
    1020050590,
    0,
    0,
    0,
    1020050587,
    1020050586,
    1020050585,
    1020050584,
    1020050583,
    1020050582,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1020050592,
    0
  },
  [1103001101] = {
    1030010954,
    1030010955,
    1030010956,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1030010953,
    1030010952,
    1030010951,
    0,
    0,
    0,
    0,
    0,
    0,
    1030010957,
    0,
    1030010958
  },
  [1103001146] = {
    1030011344,
    1030011345,
    1030011346,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1030011343,
    1030011342,
    1030011341,
    0,
    0,
    0,
    0,
    0,
    0,
    1030011347,
    0,
    1030011348
  },
  [1103001154] = {
    1030011484,
    1030011485,
    1030011486,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1030011483,
    1030011482,
    1030011481,
    0,
    0,
    0,
    0,
    0,
    0,
    1030011487,
    0,
    1030011488
  },
  [1103001179] = {
    1030011738,
    1030011739,
    1030011741,
    0,
    0,
    0,
    1030011737,
    1030011736,
    1030011735,
    1030011734,
    1030011733,
    1030011732,
    1030011731,
    0,
    0,
    0,
    0,
    0,
    0,
    1030011742,
    1030011743,
    1030011744
  },
  [1103001191] = {
    1030011858,
    1030011859,
    1030011861,
    0,
    0,
    0,
    1030011857,
    1030011856,
    1030011855,
    1030011854,
    1030011853,
    1030011852,
    1030011851,
    0,
    0,
    0,
    0,
    0,
    0,
    1030011862,
    1030011863,
    1030011864
  },
  [1103001202] = {
    1030011948,
    1030011949,
    1030011950,
    0,
    0,
    0,
    1030011947,
    1030011946,
    1030011945,
    1030011944,
    1030011943,
    1030011942,
    1030011941,
    0,
    0,
    0,
    0,
    0,
    0,
    1030011951,
    1030011952,
    1030011953
  },
  [1103002030] = {
    1030020245,
    1030020246,
    1030020247,
    1030020252,
    1030020249,
    1030020253,
    1030020258,
    1030020257,
    1030020256,
    1030020255,
    1030020244,
    1030020243,
    1030020242,
    0,
    0,
    0,
    0,
    0,
    0,
    1030020248,
    0,
    0
  },
  [1103002059] = {
    1030020544,
    1030020545,
    1030020546,
    1030020542,
    1030020539,
    1030020543,
    1030020538,
    1030020537,
    1030020536,
    1030020535,
    1030020534,
    1030020533,
    1030020532,
    0,
    0,
    0,
    0,
    0,
    0,
    1030020547,
    1030020548,
    0
  },
  [1103002087] = {
    1030020824,
    1030020825,
    1030020826,
    0,
    0,
    0,
    1030020818,
    1030020817,
    1030020816,
    1030020815,
    1030020814,
    1030020813,
    1030020812,
    0,
    0,
    0,
    0,
    0,
    0,
    1030020827,
    1030020828,
    0
  },
  [1103002106] = {
    1030021009,
    1030021010,
    1030021012,
    1030021015,
    1030021014,
    1030021016,
    1030021008,
    1030021007,
    1030021006,
    1030021005,
    1030021004,
    1030021003,
    1030021002,
    0,
    0,
    0,
    0,
    0,
    0,
    1030021013,
    1030021017,
    0
  },
  [1103002113] = {
    1030021079,
    1030021080,
    1030021082,
    1030021085,
    1030021084,
    1030021086,
    1030021078,
    1030021077,
    1030021076,
    1030021075,
    1030021074,
    1030021073,
    1030021072,
    0,
    0,
    0,
    0,
    0,
    0,
    1030021083,
    1030021087,
    0
  },
  [1103003022] = {
    1030030165,
    1030030166,
    1030030167,
    1030030172,
    1030030169,
    1030030173,
    0,
    0,
    0,
    0,
    1030030164,
    1030030163,
    1030030162,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1103003030] = {
    1030030256,
    1030030257,
    1030030258,
    1030030254,
    1030030253,
    1030030255,
    1030030248,
    1030030247,
    1030030246,
    1030030245,
    1030030244,
    1030030243,
    1030030242,
    0,
    0,
    0,
    0,
    0,
    0,
    1030030259,
    1030030249,
    0
  },
  [1103003042] = {
    1030030374,
    1030030375,
    1030030376,
    1030030372,
    1030030369,
    1030030373,
    0,
    0,
    0,
    0,
    1030030364,
    1030030363,
    1030030362,
    0,
    0,
    0,
    0,
    0,
    0,
    1030030377,
    0,
    0
  },
  [1103003051] = {
    1030030458,
    1030030459,
    1030030460,
    1030030456,
    1030030455,
    1030030457,
    0,
    0,
    0,
    0,
    1030030454,
    1030030453,
    1030030452,
    0,
    0,
    0,
    0,
    0,
    0,
    1030030463,
    0,
    0
  },
  [1103003062] = {
    1030030568,
    1030030569,
    1030030570,
    1030030566,
    1030030565,
    1030030567,
    0,
    0,
    0,
    0,
    1030030564,
    1030030563,
    1030030562,
    0,
    0,
    0,
    0,
    0,
    0,
    1030030572,
    0,
    0
  },
  [1103003079] = {
    1030030744,
    1030030745,
    1030030746,
    1030030742,
    1030030740,
    1030030743,
    1030030738,
    1030030737,
    1030030736,
    1030030735,
    1030030734,
    1030030733,
    1030030732,
    0,
    0,
    0,
    0,
    0,
    0,
    1030030747,
    1030030739,
    0
  },
  [1103003087] = {
    1030030825,
    1030030826,
    1030030827,
    1030030823,
    1030030824,
    1030030824,
    1030030818,
    1030030817,
    1030030816,
    1030030815,
    1030030814,
    1030030813,
    1030030812,
    0,
    0,
    0,
    0,
    0,
    0,
    1030030828,
    1030030819,
    0
  },
  [1103004037] = {
    1030040315,
    1030040316,
    1030040317,
    1030040325,
    1030040324,
    1030040323,
    0,
    0,
    0,
    0,
    1030040314,
    1030040313,
    1030040312,
    1030040327,
    1030040326,
    0,
    0,
    0,
    1030040328,
    1030040329,
    0,
    0
  },
  [1103006030] = {
    1030060245,
    1030060246,
    1030060247,
    0,
    1030060253,
    1030060252,
    0,
    0,
    0,
    0,
    1030060244,
    1030060243,
    1030060242,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1103007028] = {
    1030070233,
    1030070234,
    1030070235,
    1030070226,
    1030070225,
    1030070227,
    1030070218,
    1030070217,
    1030070216,
    1030070215,
    1030070214,
    1030070213,
    1030070212,
    0,
    0,
    0,
    0,
    0,
    0,
    1030070236,
    1030070219,
    0
  },
  [1103012010] = {
    0,
    0,
    0,
    0,
    0,
    0,
    1030120038,
    1030120037,
    1030120036,
    1030120035,
    1030120034,
    1030120033,
    1030120032,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1103012019] = {
    0,
    0,
    0,
    0,
    0,
    0,
    1030120138,
    1030120137,
    1030120136,
    1030120135,
    1030120134,
    1030120133,
    1030120132,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1103012031] = {
    0,
    0,
    0,
    0,
    0,
    0,
    1030120258,
    1030120257,
    1030120256,
    1030120255,
    1030120254,
    1030120253,
    1030120252,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1103012039] = {
    0,
    0,
    0,
    0,
    0,
    0,
    1030120339,
    1030120338,
    1030120337,
    1030120336,
    1030120335,
    1030120334,
    1030120333,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  },
  [1103102007] = {
    1031020026,
    1031020027,
    1031020028,
    1031020024,
    1031020023,
    1031020025,
    1031020019,
    1031020018,
    1031020017,
    1031020016,
    1031020015,
    1031020014,
    1031020013,
    0,
    0,
    0,
    0,
    0,
    0,
    1031020029,
    0,
    0
  },
  [1105001034] = {
    0,
    0,
    0,
    0,
    1050010287,
    1050010289,
    1050010286,
    1050010285,
    1050010284,
    1050010283,
    1050010282,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1050010292,
    0,
    0
  },
  [1105001048] = {
    0,
    0,
    0,
    1050010429,
    1050010428,
    1050010434,
    1050010427,
    1050010426,
    1050010425,
    1050010424,
    1050010423,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1050010435,
    0,
    1050010436
  },
  [1105001069] = {
    0,
    0,
    0,
    1050010639,
    1050010638,
    1050010640,
    1050010637,
    1050010636,
    1050010635,
    1050010634,
    1050010633,
    1050010645,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1050010643,
    1050010646,
    1050010644
  },
  [1105002091] = {
    0,
    0,
    0,
    0,
    0,
    0,
    1050020847,
    1050020846,
    1050020845,
    1050020844,
    1050020843,
    1050020842,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1050020848
  },
  [1105010019] = {
    0,
    0,
    0,
    0,
    0,
    0,
    1050100144,
    1050100143,
    1050100142,
    1050100141,
    1050100139,
    1050100138,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  }
}
_G.BaseAttachToIndex = {
  [201010] = 1,
  [201005] = 1,
  [201004] = 1,
  [201009] = 2,
  [201003] = 2,
  [201002] = 2,
  [201011] = 3,
  [201007] = 3,
  [201006] = 3,
  [204012] = 4,
  [204005] = 4,
  [204008] = 4,
  [204011] = 5,
  [204004] = 5,
  [204007] = 5,
  [204013] = 6,
  [204006] = 6,
  [204009] = 6,
  [203001] = 7,
  [203002] = 8,
  [203003] = 9,
  [203014] = 10,
  [203004] = 11,
  [203015] = 12,
  [203005] = 13,
  [202002] = 14,
  [202001] = 15,
  [202004] = 16,
  [202005] = 17,
  [202007] = 18,
  [202006] = 19,
  [205002] = 20,
  [205003] = 20,
  [205001] = 20,
  [203018] = 21,
  [204014] = 22
}
_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
  for index, attachId in ipairs(attachList) do
    if attachId > 0 then
      _G.VipAttachToIndex[attachId] = index
    end
  end
end
_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}
_G.OutfitSkins = {
  Suit = {
    403003,
    1407906,
    1407921,
    1406388,
    1406387,
    1406386,
    1407142,
    1407550,
    1406638,
    1406872,
    1406971,
    1407103,
    1407512,
    1407391,
    1407285,
    1407330,
    1407329,
    1407286,
    1407285,
    1407277,
    1407276,
    1407275,
    1407225,
    1407224,
    1407259,
    1407161,
    1407160,
    1407107,
    1407106,
    1407079,
    1407048,
    1406977,
    1406976,
    1406898,
    1400569,
    1404000,
    1404049,
    1400119,
    1400117,
    1406060,
    1406891,
    1400687,
    1405160,
    1405145,
    1405436,
    1405435,
    1405434,
    1405064,
    1405207,
    1406398,
    1407812,
    1405132,
    1407856,
    1405121,
    1406889,
    1407278,
    1407279,
    1407381,
    1407380,
    1407916,
    1406469,
    1405870,
    1407140,
    1407141,
    1406385,
    1406140,
    1400782,
    1407392,
    1407318,
    1407317,
    1407404,
    1407402,
    1407401,
    1407387,
    1404434,
    1404437,
    1404440,
    1404448,
    1400324,
    1400708,
    1404043,
    1404048,
    1405953,
    1400101,
    1404153,
    1407440,
    1407441,
    1407522
  },
  Bag = {
    {
      501001,
      501002,
      501003
    },
    {
      1501001174,
      1501002174,
      1501003174
    },
    {
      1501001220,
      1501002220,
      1501003220
    },
    {
      1501001051,
      1501002051,
      1501003051
    },
    {
      1501001443,
      1501002443,
      1501003443
    },
    {
      1501001265,
      1501002265,
      1501003265
    },
    {
      1501001321,
      1501002321,
      1501003321
    },
    {
      1501001277,
      1501002277,
      1501003277
    },
    {
      1501001550,
      1501002550,
      1501003550
    },
    {
      1501001592,
      1501002592,
      1501003592
    },
    {
      1501001608,
      1501002608,
      1501003608
    },
    {
      1501001024,
      1501002024,
      1501003024
    },
    {
      1501001019,
      1501002019,
      1501003019
    },
    {
      1501001179,
      1501002179,
      1501003179
    },
    {
      1501001194,
      1501002194,
      1501003194
    },
    {
      1501001346,
      1501002346,
      1501003346
    },
    {
      1501001057,
      1501002057,
      1501003057
    }
  },
  Helmet = {
    {
      502001,
      502002,
      502003
    },
    {
      1502001014,
      1502002014,
      1502003014
    },
    {
      1502001349,
      1502002349,
      1502003349
    },
    {
      1502001012,
      1502002012,
      1502003012
    },
    {
      1502001009,
      1502002009,
      1502003009
    },
    {
      1502001397,
      1502002397,
      1502003397
    },
    {
      1502001390,
      1502002390,
      1502003390
    },
    {
      1502001381,
      1502002381,
      1502003381
    },
    {
      1502001358,
      1502002358,
      1502003358
    },
    {
      1502001350,
      1502002350,
      1502003350
    },
    {
      1502001342,
      1502002342,
      1502003342
    },
    {
      1502001058,
      1502002058,
      1502003058
    }
  },
  Pet = {
    50000,
    50001,
    50002,
    50003,
    50004,
    50005,
    50006,
    50021,
    50022,
    50038,
    50039,
    50040
  }
}
_G.skinIdMappings = {
  [101004] = {
    101004,
    1101004246,
    1101004226,
    1101004236,
    1101004062,
    1101004078,
    1101004086,
    1101004201,
    1101004218,
    1101004046
  },
  [101001] = {
    101001,
    1101001276,
    1101001265,
    1101001213,
    1101001172,
    1101001127,
    1101001230,
    1101001241
  },
  [101003] = {
    101003,
    1101003227,
    1103003208,
    1101003195,
    1101003187,
    1101003098,
    1101003166,
    1101003218
  },
  [101008] = {
    101008,
    1101008146,
    1101008154,
    1101008079,
    1101008126,
    1101008104,
    1101008146,
    1101008061,
    1101008116
  },
  [101006] = {
    101006,
    1101006085,
    1101006061,
    1101006074,
    1101006043,
    1101006032,
    1101006084
  },
  [101012] = {101012, 1101012033},
  [101007] = {
    101007,
    1101007062,
    1101007071
  },
  [102002] = {
    102002,
    1102002136,
    1102002043,
    1102002061,
    1102002424,
    1102002438
  },
  [101101] = {101101, 1101101007},
  [101102] = {101102, 1101102041},
  [102001] = {102001, 1102001120},
  [102003] = {102003, 1102003100},
  [101005] = {101005, 1101005098},
  [103001] = {
    103001,
    1103001202,
    1103001191
  },
  [103002] = {103002, 1103002106},
  [103003] = {
    103003,
    1103003042,
    1103003062,
    1103003099
  },
  [103012] = {
    103012,
    1103012039,
    1103012010
  },
  [104003] = {104003, 1104003037},
  [104004] = {
    104004,
    1104004035,
    1104004041
  }
}
_G.VehicleSkins = {
  [1961001] = {
    1961007,
    1961149,
    1961069,
    1961013,
    1961014,
    1961015,
    1961016,
    1961017,
    1961018,
    1961020,
    1961021,
    1961024,
    1961025,
    1961029,
    1961030,
    1961031,
    1961032,
    1961033,
    1961034,
    1961035,
    1961036,
    1961037,
    1961038,
    1961039,
    1961040,
    1961041,
    1961042,
    1961043,
    1961044,
    1961045,
    1961046,
    1961047,
    1961048,
    1961049,
    1961050,
    1961051,
    1961052,
    1961053,
    1961054,
    1961055,
    1961056,
    1961057,
    1961058,
    1961059,
    1961060,
    1961061,
    1961062,
    1961063,
    1961064,
    1961065,
    1961066,
    1961067,
    1961068,
    1961136,
    1961137,
    1961138,
    1961139,
    1961140,
    1961141,
    1961142,
    1961143,
    1961144,
    1961145,
    1961147,
    1961148,
    1961010,
    1961150,
    1961151,
    1961152,
    1961153
  },
  [1903001] = {
    1903005,
    1903006,
    1903007,
    1903008,
    1903011,
    1903012,
    1903013,
    1903014,
    1903015,
    1903016,
    1903017,
    1903018,
    1903019,
    1903020,
    1903021,
    1903022,
    1903023,
    1903024,
    1903029,
    1903030,
    1903031,
    1903032,
    1903033,
    1903034,
    1903035,
    1903036,
    1903037,
    1903039,
    1903040,
    1903041,
    1903042,
    1903043,
    1903044,
    1903045,
    1903046,
    1903051,
    1903052,
    1903053,
    1903054,
    1903055,
    1903056,
    1903057,
    1903058,
    1903059,
    1903060,
    1903061,
    1903062,
    1903063,
    1903066,
    1903067,
    1903068,
    1903069,
    1903070,
    1903071,
    1903072,
    1903073,
    1903074,
    1903075,
    1903076,
    1903079,
    1903080,
    1903081,
    1903082,
    1903084,
    1903085,
    1903086,
    1903087,
    1903088,
    1903089,
    1903090,
    1903189,
    1903190,
    1903191,
    1903192,
    1903193,
    1903194,
    1903195,
    1903196,
    1903197,
    1903198,
    1903199,
    1903200,
    1903201,
    1903202,
    1903203,
    1903204,
    1903205,
    1903206,
    1903207,
    1903208,
    1903209,
    1903210,
    1903211,
    1903212,
    1903213,
    1903214,
    1903215,
    1903216,
    1903217,
    1903218,
    1903219,
    1903220,
    1903221,
    1903222,
    1903223,
    1903225,
    1903226,
    1903227,
    1903228
  },
  [1915001] = {
    1915002,
    1915003,
    1915007,
    1915005,
    1915006,
    1915008,
    1915009,
    1915010,
    1915011,
    1915012,
    1915013,
    1915014,
    1915015,
    1915016,
    1915017,
    1915018,
    1915019,
    1915020,
    1915021,
    1915022,
    1915023,
    1915024,
    1915025,
    1915026,
    1915027,
    1915099
  },
  [1908001] = {
    1908002,
    1908003,
    1908094,
    1908006,
    1908007,
    1908008,
    1908009,
    1908010,
    1908011,
    1908012,
    1908013,
    1908015,
    1908016,
    1908017,
    1908018,
    1908019,
    1908021,
    1908023,
    1908030,
    1908031,
    1908032,
    1908033,
    1908034,
    1908035,
    1908036,
    1908037,
    1908039,
    1908040,
    1908041,
    1908043,
    1908047,
    1908049,
    1908050,
    1908051,
    1908052,
    1908053,
    1908054,
    1908055,
    1908056,
    1908057,
    1908059,
    1908060,
    1908061,
    1908062,
    1908063,
    1908064,
    1908066,
    1908067,
    1908068,
    1908069,
    1908070,
    1908075,
    1908076,
    1908077,
    1908078,
    1908080,
    1908081,
    1908082,
    1908083,
    1908084,
    1908085,
    1908086,
    1908087,
    1908088,
    1908089,
    1908091,
    1908095,
    1908096,
    1908097,
    1908098,
    1908099,
    1908100,
    1908101,
    1908102,
    1908104,
    1908105,
    1908106,
    1908107,
    1908108,
    1908109,
    1908110,
    1908111,
    1908112,
    1908188,
    1908189
  },
  [1907001] = {
    1907007,
    1907008,
    1907010,
    1907011,
    1907012,
    1907013,
    1907014,
    1907016,
    1907018,
    1907019,
    1907021,
    1907022,
    1907023,
    1907025,
    1907026,
    1907027,
    1907028,
    1907029,
    1907030,
    1907032,
    1907033,
    1907034,
    1907035,
    1907036,
    1907037,
    1907038,
    1907040,
    1907041,
    1907043,
    1907044,
    1907045,
    1907046,
    1907047,
    1907048,
    1907049,
    1907050,
    1907051,
    1907052,
    1907053,
    1907054,
    1907055,
    1907056,
    1907058,
    1907059,
    1907060,
    1907061,
    1907062,
    1907063,
    1907064,
    1907065,
    1907066,
    1907067,
    1907068,
    1907069,
    1907070,
    1907071,
    1907072,
    1907073,
    1907074
  }
}
_G.CustSlotType = {
  ClothesEquipemtSlot = 5,
  BackpackEquipemtSlot = 8,
  HelmetEquipemtSlot = 9,
  ParachuteEquipemtSlot = 11,
  GlideEquipemtSlot = 15
}

local function DownloadGameItem(id)
  local puffer_manager = require("client.slua.logic.download.puffer.puffer_manager")
  local puffer_const = require("client.slua.logic.download.puffer_const")
  if puffer_manager and puffer_const and puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id}) ~= puffer_const.ENUM_DownloadState.Done then
    puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
  end
end

_G.download_item = DownloadGameItem

function _G.get_skin_id(weaponID)
  if not weaponID then
    return nil
  end
  local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
  if targetSkinId and 0 < targetSkinId then
    if not _G.skinIdCache2[targetSkinId] then
      if _G.download_item then
        pcall(_G.download_item, targetSkinId)
      end
      _G.skinIdCache2[targetSkinId] = true
    end
    return targetSkinId
  end
  return weaponID
end

function _G.equip_character_avatar(Character)
  if not (Character and slua.isValid(Character)) or not Character.AvatarComponent2 then
    return
  end
  local BackpackUtils = import("BackpackUtils")
  local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
  if not (SlotSyncData and slua.isValid(SlotSyncData)) or not BackpackUtils then
    return
  end
  
  local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
    if not mappedSkin or mappedSkin == 0 then
      return
    end
    local slotData = SlotSyncData:Get(ApplyDataIdx)
    if slotData and slotData.SlotID == ApplyEquipSlot then
      local applyItemId = mappedSkin
      if isLevelDependent and type(mappedSkin) == "table" then
        local level = levelFunc(slotData.AdditionalItemID) or 1
        if level < 1 then
          level = 1
        end
        if 3 < level then
          level = 3
        end
        applyItemId = mappedSkin[level] or mappedSkin[1]
      end
      if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then
        return
      end
      if not _G.skinIdCache[applyItemId] then
        if _G.download_item then
          pcall(_G.download_item, applyItemId)
        end
        _G.skinIdCache[applyItemId] = true
      end
      slotData.ItemId = applyItemId
      SlotSyncData:Set(ApplyDataIdx, slotData)
      Character.AvatarComponent2:OnRep_BodySlotStateChanged()
    end
  end
  
  local hasGliderSlot = false
  for i = 0, SlotSyncData:Num() - 1 do
    local slotData = SlotSyncData:Get(i)
    if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then
      hasGliderSlot = true
      break
    end
  end
  if not hasGliderSlot then
    SlotSyncData:Add({
      SlotID = _G.CustSlotType.GlideEquipemtSlot,
      ItemId = 0
    })
  end
  for i = 0, SlotSyncData:Num() - 1 do
    EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
    EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
    EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
    EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
  end
end

function _G.ApplyWeaponSkins(PlayerCharacter)
  pcall(function()
    local WeaponManager = PlayerCharacter:GetWeaponManager()
    if not slua.isValid(WeaponManager) then
      return
    end
    for slot = 1, 3 do
      local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
      if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
        do
          local WeaponID = Weapon:GetWeaponID()
          local SkinID = _G.get_skin_id(WeaponID) or WeaponID
          local isModified = false
          local SkinData = Weapon.synData:Get(7)
          if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
            SkinData.defineID.TypeSpecificID = SkinID
            Weapon.synData:Set(7, SkinData)
            if Weapon.SetWeaponAvatarID then
              pcall(function()
                Weapon:SetWeaponAvatarID(SkinID)
              end)
            end
            if not _G.skinIdCache[SkinID] then
              _G.download_item(SkinID)
              _G.skinIdCache[SkinID] = true
            end
            isModified = true
          end
          if 10000000 <= SkinID and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
            for AttachIdx = 0, 5 do
              local attachData = Weapon.synData:Get(AttachIdx)
              if attachData then
                local defineIDRef = slua.IndexReference(attachData, "defineID")
                if defineIDRef then
                  local attachmentId = defineIDRef.TypeSpecificID
                  if attachmentId and 0 < attachmentId then
                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                      local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                      if targetAttachId ~= attachmentId then
                        attachData.defineID.TypeSpecificID = targetAttachId
                        Weapon.synData:Set(AttachIdx, attachData)
                        if not _G.skinIdCache2[targetAttachId] then
                          if _G.download_item then
                            pcall(_G.download_item, targetAttachId)
                          end
                          _G.skinIdCache2[targetAttachId] = true
                        end
                        isModified = true
                      end
                    end
                  end
                end
              end
            end
          end
          if isModified then
            if Weapon.DelayHandleAvatarMeshChanged then
              pcall(function()
                Weapon:DelayHandleAvatarMeshChanged()
              end)
            end
            if Weapon.OnRep_synData then
              pcall(function()
                Weapon:OnRep_synData()
              end)
            end
          end
        end
      end
    end
  end)
end

function _G.ApplyVehicleSkins(PlayerCharacter)
  pcall(function()
    local Vehicle = PlayerCharacter:GetCurrentVehicle()
    if not slua.isValid(Vehicle) then
      _G.LastVehicleEntity = nil
      return
    end
    if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
      return
    end
    local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
    if not slua.isValid(VehicleAvatar) then
      return
    end
    local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
    local currentId = tostring(Vehicle:GetAvatarId() or "")
    local applySkinId = 0
    for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
      if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then
        applySkinId = targetSkin
        break
      end
    end
    if applySkinId and 0 < applySkinId then
      _G.skinIdCache = _G.skinIdCache or {}
      if not _G.skinIdCache[applySkinId] then
        if _G.download_item then
          pcall(_G.download_item, applySkinId)
        end
        _G.skinIdCache[applySkinId] = true
      end
      VehicleAvatar.curSwitchEffectId = 7303001
      if VehicleAvatar.ChangeItemAvatar then
        VehicleAvatar:ChangeItemAvatar(applySkinId, true)
      end
      _G.CurrentEquipVehicleID = applySkinId
      _G.LastVehicleEntity = Vehicle
    end
  end)
end

function _G.HandlePetLogic()
  pcall(function()
    local petSkin = _G.OutfitMap.Pet
    if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then
      return
    end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[petSkin] then
      if _G.download_item then
        pcall(_G.download_item, petSkin)
      end
      _G.skinIdCache[petSkin] = true
    end
    local ModuleManager = require("client.module_framework.ModuleManager")
    if ModuleManager then
      local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
      if logic_pet then
        if logic_pet.SetCurPetID then
          logic_pet:SetCurPetID(petSkin)
        end
        if logic_pet.EquipPet then
          logic_pet:EquipPet(petSkin)
        end
      end
    end
    _G.LastAppliedPet = petSkin
  end)
end

function _G.ForceRefreshSkinMaps()
  pcall(function()
    if not _G.LexusState or not _G.LexusState.CustomTextData then
      return
    end
    local cData = _G.LexusState.CustomTextData
    if _G.OutfitSkins then
      if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then
        _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit]
      end
      if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then
        _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag]
      end
      if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then
        _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet]
      end
    end
    if _G.skinIdMappings then
      if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then
        _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416]
      end
      if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then
        _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM]
      end
      if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then
        _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR]
      end
      if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then
        _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762]
      end
      if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then
        _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG]
      end
      if cData.SkinHoney and _G.skinIdMappings[101012] and _G.skinIdMappings[101012][cData.SkinHoney] then
        _G.WeaponSkinMap[101012] = _G.skinIdMappings[101012][cData.SkinHoney]
      end
      if cData.SkinQBZ and _G.skinIdMappings[101007] and _G.skinIdMappings[101007][cData.SkinQBZ] then
        _G.WeaponSkinMap[101007] = _G.skinIdMappings[101007][cData.SkinQBZ]
      end
      if cData.SkinASM and _G.skinIdMappings[101101] and _G.skinIdMappings[101101][cData.SkinASM] then
        _G.WeaponSkinMap[101101] = _G.skinIdMappings[101101][cData.SkinASM]
      end
      if cData.SkinACE32 and _G.skinIdMappings[101102] and _G.skinIdMappings[101102][cData.SkinACE32] then
        _G.WeaponSkinMap[101102] = _G.skinIdMappings[101102][cData.SkinACE32]
      end
      if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then
        _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP]
      end
      if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then
        _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI]
      end
      if cData.SkinVector and _G.skinIdMappings[102003] and _G.skinIdMappings[102003][cData.SkinVector] then
        _G.WeaponSkinMap[102003] = _G.skinIdMappings[102003][cData.SkinVector]
      end
      if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then
        _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza]
      end
      if cData.SkinKar98K and _G.skinIdMappings[103001] and _G.skinIdMappings[103001][cData.SkinKar98K] then
        _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][cData.SkinKar98K]
      end
      if cData.SkinM24 and _G.skinIdMappings[103002] and _G.skinIdMappings[103002][cData.SkinM24] then
        _G.WeaponSkinMap[103002] = _G.skinIdMappings[103002][cData.SkinM24]
      end
      if cData.SkinAWM and _G.skinIdMappings[103003] and _G.skinIdMappings[103003][cData.SkinAWM] then
        _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][cData.SkinAWM]
      end
      if cData.SkinAMR and _G.skinIdMappings[103012] and _G.skinIdMappings[103012][cData.SkinAMR] then
        _G.WeaponSkinMap[103012] = _G.skinIdMappings[103012][cData.SkinAMR]
      end
      if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then
        _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K]
      end
      if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then
        _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS]
      end
    end
    if _G.VehicleSkins then
      if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then
        _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia]
      end
      if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then
        _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ]
      end
      if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then
        _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe]
      end
      if cData.SkinBuggy and _G.VehicleSkins[1907001] and _G.VehicleSkins[1907001][cData.SkinBuggy] then
        _G.VehicleSkinMap[1907001] = _G.VehicleSkins[1907001][cData.SkinBuggy]
      end
      if cData.SkinMirado and _G.VehicleSkins[1915001] and _G.VehicleSkins[1915001][cData.SkinMirado] then
        _G.VehicleSkinMap[1915001] = _G.VehicleSkins[1915001][cData.SkinMirado]
      end
    end
  end)
end

function _G.InitializeSkinModSystem()
  pcall(function()
    local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
    if LobbyAvatar and not _G.LobbyBypassHacked then
      local originalPutonEquipment = LobbyAvatar.PutonEquipment
      
      function LobbyAvatar:PutonEquipment(itemID, tAvatarCustom, tExtraData)
        local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
        if attachIndex then
          local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
          if holdingWeaponSkinID and 10000000 <= holdingWeaponSkinID and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
            local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
            if vipAttachID and 0 < vipAttachID then
              if self.HandleDownload then
                self:HandleDownload(vipAttachID, nil, nil, false)
              end
              itemID = vipAttachID
            end
          end
        end
        if originalPutonEquipment then
          return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData)
        end
      end
      
      local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
      
      function LobbyAvatar:CharEquipWeaponByResId(resID, isUse, isAsync, SocketName)
        local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
        if isUse and self.GetEquipments then
          local equipments = self:GetEquipments()
          for _, equip in ipairs(equipments) do
            if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
              self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
            end
          end
        end
        return retValue
      end
      
      _G.LobbyBypassHacked = true
    end
  end)
  pcall(function()
    local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
    if Common_Items_UIBP and not _G.IconBaloHacked then
      local originalInitView = Common_Items_UIBP.InitView
      
      function Common_Items_UIBP:InitView(nItemId, nCount, nValidTime, tExtraData)
        tExtraData = tExtraData or {}
        local displayResId
        if _G.get_skin_id then
          local skinID = _G.get_skin_id(nItemId)
          if skinID and skinID ~= nItemId then
            displayResId = skinID
          end
        end
        local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
        if not displayResId and attachIndex then
          local GameplayData = require("GameLua.GameCore.Data.GameplayData")
          local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
          if slua.isValid(LocalPlayer) then
            local currentWeapon = LocalPlayer:GetCurrentWeapon()
            if slua.isValid(currentWeapon) then
              local weaponID = currentWeapon:GetWeaponID()
              local finalSkinID = _G.get_skin_id(weaponID) or weaponID
              if 10000000 <= finalSkinID and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                if vipAttachID and 0 < vipAttachID then
                  displayResId = vipAttachID
                end
              end
            end
          end
        end
        if displayResId then
          tExtraData.displayResId = displayResId
          if not _G.skinIdCache2[displayResId] then
            if _G.download_item then
              pcall(_G.download_item, displayResId)
            end
            _G.skinIdCache2[displayResId] = true
          end
        end
        if originalInitView then
          return originalInitView(self, nItemId, nCount, nValidTime, tExtraData)
        end
      end
      
      _G.IconBaloHacked = true
    end
  end)
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager
_G.NeedCheckDeadBoxTimer = 0
_G.LastCheckDeadBoxTime = 0

function _G.ForceEnableKillCounterUI()
  pcall(function()
    local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
      local kcImpl = KillCounterUISubsystem.__inner_impl
      
      function kcImpl.CheckSupportKCUI()
        return true
      end
      
      function kcImpl:CheckNeedMainKillCounterUI(PlayerWeapon, PlayerID)
        if slua.isValid(PlayerWeapon) then
          local WeaponID = PlayerWeapon:GetWeaponID()
          self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
        else
          self:UpdateMainKillCounterUI(false)
        end
      end
      
      local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
      
      function kcImpl:UpdateMainKillCounterUI(bShow, WeaponID, AvatarID)
        AvatarID = bShow and _G.get_skin_id(WeaponID) or AvatarID
        if originalUpdateMainKillCounterUI then
          originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID)
        end
      end
      
      _G.KCUISystemHacked2 = true
    end
    local ModuleManager = require("client.module_framework.ModuleManager")
    if ModuleManager and not _G.KCLogicHacked2 then
      local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
      if LogicKillCounter then
        function LogicKillCounter.CheckSupportKC()
          return true
        end
        
        function LogicKillCounter.CheckSupportKillCounterAvatar()
          return true
        end
        
        function LogicKillCounter.CheckHasWeaponKillCounter()
          return true
        end
        
        function LogicKillCounter.GetBaseKillCounterIdByWeaponId()
          return 2100004
        end
        
        function LogicKillCounter.GetEquipedKillCounterId()
          return 2100004
        end
        
        function LogicKillCounter.GetMyEquipedKillCounterId()
          return 2100004
        end
        
        function LogicKillCounter:GetOneWeaponKillCountInBattle(uid, weaponId)
          return _G.TDFTDeKillCounts[weaponId] or 0
        end
        
        function LogicKillCounter:GetWeaponKillCountByUid(uid, weaponId)
          return _G.TDFTDeKillCounts[weaponId] or 0
        end
        
        _G.KCLogicHacked2 = true
      end
    end
    local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
    local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
    if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
      local originalFileItem = KillInfo.__inner_impl.FileItem
      
      function KillInfo.__inner_impl:FileItem(DamageRecordData)
        pcall(function()
          local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
          if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then
            local currentWeapon = LocalPlayer:GetCurrentWeapon()
            if slua.isValid(currentWeapon) then
              local weaponID = currentWeapon:GetWeaponID()
              local skinID = _G.get_skin_id(weaponID)
              if skinID then
                DamageRecordData.CauserWeaponAvatarID = skinID
              end
              if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then
                DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit
              end
              if CACHED_GoldColor then
                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
              end
              if DamageRecordData.ResultHealthStatus == 2 then
                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                _G.NeedCheckDeadBoxTimer = 50
                if not CACHED_UI_Manager then
                  CACHED_UI_Manager = require("client.slua_ui_framework.manager")
                end
                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                  local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                  uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                  local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                  local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                  uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                end
              end
            end
          end
        end)
        if originalFileItem then
          return originalFileItem(self, DamageRecordData)
        end
      end
      
      _G.KillInfoCounterHacked = true
    end
    local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
    if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
      function SwitchWeaponSlotMode2.__inner_impl:CheckShowKCIcon()
        if slua.isValid(self.KillCounterImg) then
          self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible)
        end
      end
      
      _G.SlotBaseHacked = true
    end
  end)
end

local cached_GameplayStatics, cached_PlayerTombBox, cached_ActorClass

function _G.DeadBox_TemperRequest(PlayerController)
  if _G.NeedCheckDeadBoxTimer <= 0 then
    return
  end
  local curTime = os.clock()
  if _G.LastCheckDeadBoxTime and curTime - _G.LastCheckDeadBoxTime < 2.0 then
    return
  end
  _G.LastCheckDeadBoxTime = curTime
  _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1
  local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
  if not slua.isValid(PlayerCharacter) then
    return
  end
  if not cached_GameplayStatics then
    cached_GameplayStatics = import("GameplayStatics")
    cached_ActorClass = import("Actor")
    cached_PlayerTombBox = import("PlayerTombBox")
  end
  if not _G.CachedActorArray then
    _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
  end
  local UI_Util = require("client.common.ui_util")
  local GameInstance = UI_Util and UI_Util.GetGameInstance()
  if not GameInstance or not cached_GameplayStatics then
    return
  end
  local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray)
  for _, deadBoxActor in pairs(deadBoxes) do
    if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
      local damageCauser = deadBoxActor.DamageCauser
      if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
        local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
        if slua.isValid(DeadBoxAvatarComponent) then
          do
            local currentBoxSkinId = 0
            if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
              currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
            else
              local currentWeapon = PlayerCharacter:GetCurrentWeapon()
              if slua.isValid(currentWeapon) and currentWeapon.synData then
                local weaponSkinData = currentWeapon.synData:Get(7)
                if weaponSkinData and weaponSkinData.defineID then
                  currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                end
              end
            end
            if currentBoxSkinId ~= 0 then
              pcall(function()
                DeadBoxAvatarComponent:ResetItemAvatar()
                DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
              end)
            end
            deadBoxActor.bIsTDSkinApplied = true
          end
        end
      end
    end
  end
end

function _G.GetEnemyTargetsFromActors(radius)
  local result = {}
  local player = GameplayData.GetPlayerCharacter()
  if not slua.isValid(player) then
    return result
  end
  local allCharacters = {}
  if GameplayData.GetAllPlayerCharacters then
    allCharacters = GameplayData.GetAllPlayerCharacters()
  elseif GameplayData.GameCharacters then
    for _, char in pairs(GameplayData.GameCharacters) do
      table.insert(allCharacters, char)
    end
  end
  local myTeam = player:GetTeamID()
  for _, actor in pairs(allCharacters) do
    if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() and actor:GetTeamID() ~= myTeam then
      local dist = player:GetDistanceTo(actor)
      if radius >= dist then
        table.insert(result, actor)
      end
    end
  end
  return result
end

function _G.AimTouch()
  pcall(function()
    if not _G.LexusConfig.AimTouchEnable then
      return
    end
    local player = GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then
      return
    end
    local pc = player:GetPlayerControllerSafety()
    if not slua.isValid(pc) then
      return
    end
    local mode = _G.LexusConfig.AimbotMode or 1
    local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
    if not weapon and type(player.GetCurrentShootWeapon) == "function" then
      weapon = player:GetCurrentShootWeapon()
    end
    local isADS = player.bIsGunADS or false
    local isFiring = player.bIsWeaponFiring or false
    local hasWeapon = slua.isValid(weapon)
    if mode == 4 and not isFiring then
      return
    end
    if mode == 3 and not hasWeapon then
      return
    end
    if mode == 2 and not isADS then
      return
    end
    local isShotgun = false
    local isSniper = false
    local currentAmmo = 1
    if hasWeapon then
      local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
      local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
      if 1030000 <= wID and wID < 1040000 or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then
        isShotgun = true
      end
      if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
        isSniper = true
      end
      if type(weapon.GetCurrentAmmo) == "function" then
        currentAmmo = weapon:GetCurrentAmmo()
      elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
        currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
      elseif weapon.CurrentAmmo ~= nil then
        currentAmmo = weapon.CurrentAmmo
      end
    end
    if _G.LexusState.IsAutoFiring then
      pcall(function()
        player.bIsWeaponFiring = false
        if type(player.SetIsWeaponFiring) == "function" then
          player:SetIsWeaponFiring(false)
        end
        if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then
          pc:SetIsWeaponFiring(false)
        end
        local wepMgr = player.WeaponManagerComponent
        if slua.isValid(wepMgr) then
          wepMgr.bIsWeaponFiring = false
        end
      end)
      _G.LexusState.IsAutoFiring = false
    end
    if isShotgun and currentAmmo <= 0 then
      return
    end
    local cond = 2
    local prioMode = 1
    local boneIdx = 1
    local speedVal = 50
    local fovVal = 30
    local maxDistMeters = 50
    local useVisCheck = false
    local igKnock = false
    local igBot = false
    useVisCheck = _G.LexusConfig.AimTouchVisCheck
    igKnock = _G.LexusConfig.AimTouchIgKnock
    igBot = _G.LexusConfig.AimTouchIgBot
    if isShotgun then
      cond = 2
      prioMode = 1
      boneIdx = 2
      speedVal = 90
      fovVal = 32
      maxDistMeters = 30
    elseif isADS then
      if isSniper then
        cond = 2
        prioMode = 1
        boneIdx = 1
        speedVal = 85
        fovVal = 28
        maxDistMeters = 400
      else
        cond = 1
        prioMode = 1
        boneIdx = 2
        speedVal = 85
        fovVal = 28
        maxDistMeters = 300
      end
    else
      cond = 1
      prioMode = 1
      boneIdx = 1
      speedVal = 85
      fovVal = 28
      maxDistMeters = 250
    end
    local currentMaxDist = maxDistMeters * 100
    local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
    if not enemies or {} == 0 then
      return
    end
    local FVector2D = import("Vector2D")
    local UGameplayStatics = import("GameplayStatics")
    local KismetMathLibrary = import("KismetMathLibrary")
    local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
    if not slua.isValid(camManager) then
      return
    end
    local camLoc = camManager:GetCameraLocation()
    if not camLoc then
      return
    end
    local ui_util = require("client.common.ui_util")
    if not ui_util then
      return
    end
    local viewportSize = ui_util.GetViewportSize()
    if not viewportSize then
      return
    end
    local centerX = viewportSize.X * 0.5
    local centerY = viewportSize.Y * 0.5
    local FOV_RADIUS = fovVal / 100.0 * (viewportSize.X / 2.0)
    local bestTarget
    local bestScore = 99999999
    local selBoneName = "head"
    if boneIdx == 1 then
      selBoneName = "head"
    elseif boneIdx == 2 then
      selBoneName = "spine_03"
    elseif boneIdx == 3 then
      selBoneName = "spine_01"
    elseif boneIdx == 4 then
      selBoneName = "pelvis"
    end
    for i, target in ipairs(enemies) do
      if slua.isValid(target) and (not igKnock or target.HealthStatus ~= 1) then
        if igBot then
          local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
          _G.BotStatusCache = _G.BotStatusCache or {}
          local cachedBot = _G.BotStatusCache[tId]
          if cachedBot == nil then
            cachedBot = false
            if target.bIsAI == true or target.IsAI == true or target.bIsAi == true then
              cachedBot = true
            end
            if not cachedBot then
              if target.AIData ~= nil or target.AIController ~= nil or target.bIsAIActor == true then
                cachedBot = true
              end
              if not cachedBot and target.PlayerAIType ~= nil and target.PlayerAIType ~= 0 then
                cachedBot = true
              end
              if not cachedBot and type(target.IsAICharacter) == "function" then
                local ok, r = pcall(function()
                  return target:IsAICharacter()
                end)
                if ok and r then
                  cachedBot = true
                end
              end
              if not cachedBot and type(target.GetIsAI) == "function" then
                local ok, r = pcall(function()
                  return target:GetIsAI()
                end)
                if ok and r then
                  cachedBot = true
                end
              end
            end
            if not cachedBot then
              local pState = target.PlayerState
              if slua.isValid(pState) then
                if pState.bIsABot or pState.bIsBot or pState.IsBot or pState.bIsAI or pState.bIsRobot or pState.bIsAiPlayer then
                  cachedBot = true
                end
                if not cachedBot and pState.PlayerAIType ~= nil and pState.PlayerAIType ~= 0 then
                  cachedBot = true
                end
                if not cachedBot and type(pState.IsABot) == "function" then
                  local ok, r = pcall(function()
                    return pState:IsABot()
                  end)
                  if ok and r then
                    cachedBot = true
                  end
                end
                if not cachedBot then
                  do
                    local uid = pState.Uid or pState.UID or pState.PlayerId or pState.PlayerID
                    if uid ~= nil and (uid == 0 or uid == "0") then
                      cachedBot = true
                    end
                  end
                end
              end
            end
            if not cachedBot and type(target.IsBot) == "function" then
              local ok, r = pcall(function()
                return target:IsBot()
              end)
              if ok and r then
                cachedBot = true
              end
            end
            if not cachedBot and type(target.GetController) == "function" then
              local ok, ctrl = pcall(function()
                return target:GetController()
              end)
              if ok and slua.isValid(ctrl) and (ctrl.bIsAI == true or ctrl.IsAI == true or ctrl.AIData ~= nil) then
                cachedBot = true
              end
            end
            _G.BotStatusCache[tId] = cachedBot
          end
          if cachedBot then
            goto lbl_774
          end
        end
        if useVisCheck then
          local curTime = os.clock()
          local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
          _G.AimTouchVisCache = _G.AimTouchVisCache or {}
          if not _G.AimTouchVisCache[tId] or curTime - _G.AimTouchVisCache[tId].time > 0.2 then
            local isHidden = true
            pcall(function()
              if pc:LineOfSightTo(target) then
                isHidden = false
              end
            end)
            _G.AimTouchVisCache[tId] = {hidden = isHidden, time = curTime}
          end
          if _G.AimTouchVisCache[tId].hidden then
            goto lbl_774
          end
        end
        local tPos = target:GetBonePos(selBoneName, {
          X = 0,
          Y = 0,
          Z = 0
        })
        if (not tPos or tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) and type(target.GetSocketLocation) == "function" then
          tPos = target:GetSocketLocation(selBoneName)
        end
        if (not tPos or tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) and type(target.K2_GetActorLocation) == "function" then
          tPos = target:K2_GetActorLocation()
          if tPos then
            if boneIdx == 1 then
              tPos.Z = tPos.Z + 70
            elseif boneIdx == 2 then
              tPos.Z = tPos.Z + 40
            elseif boneIdx == 3 then
              tPos.Z = tPos.Z + 20
            end
          end
        end
        if tPos and (tPos.X ~= 0 or tPos.Y ~= 0 or tPos.Z ~= 0) then
          local screen = FVector2D()
          local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
          if success and not (0 >= screen.X) and not (0 >= screen.Y) then
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx * dx + dy * dy)
            if not (FOV_RADIUS < distScreen) then
              local currentScore = distScreen
              if prioMode == 2 then
                currentScore = player:GetDistanceTo(target)
              elseif prioMode == 3 then
                currentScore = target.Health or 100
              elseif prioMode == 4 then
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then
                  maxhp = 100
                end
                currentScore = hp / maxhp
              end
              if bestScore > currentScore then
                bestScore = currentScore
                bestTarget = target
              end
            end
          end
        end
      end
      ::lbl_774::
    end
    if not slua.isValid(bestTarget) then
      return
    end
    local finalBonePos = bestTarget:GetBonePos(selBoneName, {
      X = 0,
      Y = 0,
      Z = 0
    })
    if (not finalBonePos or finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) and type(bestTarget.GetSocketLocation) == "function" then
      finalBonePos = bestTarget:GetSocketLocation(selBoneName)
    end
    if (not finalBonePos or finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) and type(bestTarget.K2_GetActorLocation) == "function" then
      finalBonePos = bestTarget:K2_GetActorLocation()
      if finalBonePos then
        if boneIdx == 1 then
          finalBonePos.Z = finalBonePos.Z + 70
        elseif boneIdx == 2 then
          finalBonePos.Z = finalBonePos.Z + 40
        elseif boneIdx == 3 then
          finalBonePos.Z = finalBonePos.Z + 20
        end
      end
    end
    if not finalBonePos or finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0 then
      return
    end
    local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
    if not rot then
      return
    end
    local currentRot = pc:GetControlRotation()
    if not currentRot then
      return
    end
    local deltaYaw = rot.Yaw - currentRot.Yaw
    local deltaPitch = rot.Pitch - currentRot.Pitch
    if isADS then
      local camRot
      if type(camManager.GetCameraRotation) == "function" then
        camRot = camManager:GetCameraRotation()
      end
      if camRot then
        deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
        deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
      end
    end
    if 180 < deltaYaw then
      deltaYaw = deltaYaw - 360
    end
    if deltaYaw < -180 then
      deltaYaw = deltaYaw + 360
    end
    if 180 < deltaPitch then
      deltaPitch = deltaPitch - 360
    end
    if deltaPitch < -180 then
      deltaPitch = deltaPitch + 360
    end
    local smoothFactor = 0.0
    if 100 <= speedVal then
      smoothFactor = 1.0
    else
      smoothFactor = speedVal / 100.0 * 0.3
      if smoothFactor < 0.01 then
        smoothFactor = 0.01
      end
    end
    local finalPitch = currentRot.Pitch + deltaPitch * smoothFactor
    local finalYaw = currentRot.Yaw + deltaYaw * smoothFactor
    local finalRot = {
      Pitch = finalPitch,
      Yaw = finalYaw,
      Roll = 0
    }
    pc:SetControlRotation(finalRot, "AimTouch")
  end)
end

local function InitializeGraphicsUnlock()
  if isExpired then
    return
  end
  if _G.LexusState.GraphicsUnlocked or currentTime > limitTime then
    return
  end
  pcall(function()
    local SettingCfg = require("client.logic.setting.setting_config")
    local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
    if SettingCfg then
      if SettingCfg.TpViewValue then
        SettingCfg.TpViewValue.max = 160
      end
      if SettingCfg.FpViewValue then
        SettingCfg.FpViewValue.max = 160
      end
    end
    if GraphicSettingDB and GraphicSettingDB.TpViewValue then
      GraphicSettingDB.TpViewValue.max = 160
    end
  end)
  pcall(function()
    local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
    local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
    local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
    local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
    local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
    local FLinearColor = import("LinearColor") or _G.FLinearColor
    if logic_setting_graphics then
      local old_SetFPS = logic_setting_graphics.SetFPS
      
      function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
        if old_SetFPS then
          old_SetFPS(gameInstance, FPSLevel)
        end
        if FPSLevel == 8 then
          gameInstance:ExecuteCMD("t.MaxFPS", "165")
          gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
        end
      end
    end
    if GSC_FPS and GSC_FPS.__inner_impl then
      local fps_impl = GSC_FPS.__inner_impl
      
      function fps_impl:GetMaxFPSLevel()
        return 8, 8
      end
      
      function fps_impl:InitRealSupportFPS()
        local RealSupportFPS = {}
        for i = 1, 8 do
          RealSupportFPS[i] = {true, true}
        end
        if GraphicSettingDB then
          GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false)
        end
        return RealSupportFPS
      end
      
      function fps_impl:UpdateSelectedFPSState(selectedLevel)
        if not slua.isValid(self.UIRoot) then
          return
        end
        for level = 2, 8 do
          local name = "NodeFps" .. (({
            [2] = 20,
            [3] = 25,
            [4] = 30,
            [5] = 40,
            [6] = 60,
            [7] = 90,
            [8] = 120
          })[level] or 120)
          local widget = self.UIRoot[name]
          if slua.isValid(widget) then
            widget:SetIsEnabled(true)
            pcall(function()
              widget:SetRenderOpacity(1.0)
            end)
            do
              local switcher = self.UIRoot["WidgetSwitcher_" .. level]
              if slua.isValid(switcher) then
                switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1)
              end
            end
          end
        end
      end
    end
    if GSC_FPSFT and GSC_FPSFT.__inner_impl then
      local ft_impl = GSC_FPSFT.__inner_impl
      local NMinFPS, NStep = 90, 5
      
      local function clamp(value, min, max)
        if value < min then
          return min
        end
        if max < value then
          return max
        end
        return value
      end
      
      local function lerp(a, b, t)
        return a + (b - a) * t
      end
      
      local function _getColorByPercent(start, finish, percent)
        if not FLinearColor then
          return nil
        end
        return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
      end
      
      function ft_impl:ShowOrHide()
        self:SelfHitTestInvisible()
        if self.InitFPSFTSwitch then
          self:InitFPSFTSwitch()
        end
      end
      
      function ft_impl:InitFPSFTSwitch()
        local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
        if self.UIRoot.Setting_Switch then
          self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true)
        end
        if self.UIRoot.CanvasPanel_8 then
          self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch)
        end
        if self.UIRoot.WidgetSwitcher_0 then
          self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2)
        end
        if self.InitFPSFTValue165 then
          self:InitFPSFTValue165()
        end
      end
      
      function ft_impl:InitFPSFTValue165()
        local itemRoot = self.UIRoot
        local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
        local FPSFineTuneNum = 165
        if FPSFineTuneSwitch then
          FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
          itemRoot.Slider_screen3:SetLocked(false)
          if FLinearColor then
            itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
            itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
          end
        else
          itemRoot.Slider_screen3:SetLocked(true)
          if FLinearColor then
            itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
            itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
          end
        end
        local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
        itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
        itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
        itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
        if FLinearColor then
          local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
          local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
          local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
          local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
          itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
        end
      end
      
      function ft_impl:OnFPSFTValueChange3(FPSFineTuneNum)
        GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
        if self.InitFPSFTValue165 then
          self:InitFPSFTValue165()
        end
        if self:GetParentUI() then
          self:GetParentUI():SetDirty(true)
        end
        local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
        if gameInstance then
          gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
          gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
        end
      end
      
      function ft_impl:OnFPSFTSliderValueChange3(value)
        if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
          local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
          self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
        end
      end
      
      ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
      ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
      ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
      ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
      ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
      ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
    end
  end)
  _G.LexusState.GraphicsUnlocked = true
  Notify("Graphics & FPS 165Hz Unlocked")
end

function _G.InitModMenuTab()
  if _G.ModMenuInitialized then
    return
  end
  _G.ModMenuInitialized = true
  
  local function T(vnText, enText)
    return _G.LexusLang == "EN" and enText or vnText
  end
  
  _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
  local LocUtil = _G.LocUtil
  if not LocUtil and package.loaded["client.common.LocUtil"] then
    LocUtil = require("client.common.LocUtil")
  end
  local FakeTextMap = {
    [999000] = T("OfficialOwner10x\240\159\148\165  ESP"),
    [999006] = T("ESP ", "ESP "),
    [999007] = T("AIMBOT"),
    [999008] = T("MAGIC BULLET"),
    [999009] = T("GRAPHICS & WALLHACK"),
    [999010] = T("COLOR MOD"),
    [999011] = T("SKIN MOD")
  }
  if LocUtil and not LocUtil._IsModMenuHooked_V2 then
    local hookFuncs = {
      "GetLocalizeResStr",
      "GetText",
      "GetTextByID",
      "GetLocalText",
      "GetLocalizeStr"
    }
    for _, funcName in ipairs(hookFuncs) do
      if LocUtil[funcName] then
        local old_func = LocUtil[funcName]
        LocUtil[funcName] = function(id)
          if FakeTextMap[id] then
            return FakeTextMap[id]
          end
          if type(id) == "string" and not tonumber(id) then
            return id
          end
          if old_func then
            return old_func(id)
          end
          return ""
        end
      end
    end
    LocUtil._IsModMenuHooked_V2 = true
  end
  local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
  local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
  if not SettingPageDefine.ModMenu then
    local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
    local StackESPV2 = {
      {
        Key = "ModMenu_ESP9_Ex",
        UI = AliasMap.TitleSwitcher,
        Text = "\226\150\182 ESP",
        ExpandIndex = 0,
        GetFunc = function()
          return _G.LexusConfig.EspLoai9
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.EspLoai9 = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_Count",
        UI = AliasMap.Switcher,
        Text = "   Enemy Counter",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_Count
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_Count = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_Name",
        UI = AliasMap.Switcher,
        Text = "   Player Name",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_Name
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_Name = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_Dist",
        UI = AliasMap.Switcher,
        Text = "   Show Distance",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_Distance
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_Distance = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_HP",
        UI = AliasMap.Switcher,
        Text = "   Health Bar",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_HP
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_HP = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_Team",
        UI = AliasMap.Switcher,
        Text = "   TEAM ID",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_Team
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_Team = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_Weapon",
        UI = AliasMap.Switcher,
        Text = "   WEAPON ICON",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_Weapon
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_Weapon = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_Line",
        UI = AliasMap.Switcher,
        Text = "   ESP LINE",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_Line
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_Line = v
          return true
        end
      },
      {
        Key = "ModMenu_ESP9_Skeleton",
        UI = AliasMap.Switcher,
        Text = "   ESP SKELETON (may cause lag)",
        ExpandHandle = "ModMenu_ESP9_Ex",
        GetFunc = function()
          return _G.LexusConfig.Esp9_Skeleton
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Esp9_Skeleton = v
          return true
        end
      }
    }
    local StackAimbot = {
      {
        Key = "ModMenu_AimTouch_Enable",
        UI = AliasMap.Switcher,
        Text = "AIMBOT (MASTER ON/OFF)",
        GetFunc = function()
          return _G.LexusConfig.AimTouchEnable
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.AimTouchEnable = v
          return true
        end
      },
      {
        Key = "ModMenu_AimTouch_Master",
        UI = AliasMap.Switcher,
        Text = "   Master Mode (Always On)",
        GetFunc = function()
          return _G.LexusConfig.AimbotMode == 1
        end,
        SetFunc = function(c, v)
          if v then
            _G.LexusConfig.AimbotMode = 1
          end
          return true
        end
      },
      {
        Key = "ModMenu_AimTouch_Scope",
        UI = AliasMap.Switcher,
        Text = "   Scope Only",
        GetFunc = function()
          return _G.LexusConfig.AimbotMode == 2
        end,
        SetFunc = function(c, v)
          if v then
            _G.LexusConfig.AimbotMode = 2
          end
          return true
        end
      },
      {
        Key = "ModMenu_AimTouch_ADS",
        UI = AliasMap.Switcher,
        Text = "   ADS Only",
        GetFunc = function()
          return _G.LexusConfig.AimbotMode == 3
        end,
        SetFunc = function(c, v)
          if v then
            _G.LexusConfig.AimbotMode = 3
          end
          return true
        end
      },
      {
        Key = "ModMenu_AimTouch_Fire",
        UI = AliasMap.Switcher,
        Text = "   Fire Only",
        GetFunc = function()
          return _G.LexusConfig.AimbotMode == 4
        end,
        SetFunc = function(c, v)
          if v then
            _G.LexusConfig.AimbotMode = 4
          end
          return true
        end
      },
      {
        Key = "ModMenu_IgKnock",
        UI = AliasMap.Switcher,
        Text = "   Ignore Knocked",
        GetFunc = function()
          return _G.LexusConfig.AimTouchIgKnock
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.AimTouchIgKnock = v
          return true
        end
      },
      {
        Key = "ModMenu_IgBot",
        UI = AliasMap.Switcher,
        Text = "   Ignore Bots",
        GetFunc = function()
          return _G.LexusConfig.AimTouchIgBot
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.AimTouchIgBot = v
          return true
        end
      },
      {
        Key = "ModMenu_VisCheck",
        UI = AliasMap.Switcher,
        Text = "   Visibility Check",
        GetFunc = function()
          return _G.LexusConfig.AimTouchVisCheck
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.AimTouchVisCheck = v
          return true
        end
      }
    }
    local StackGraphics = {
      {
        Key = "ModMenu_UnlockFPS",
        UI = AliasMap.Switcher,
        Text = T("Unlock 165 FPS", "Unlock 165 FPS"),
        GetFunc = function()
          return _G.LexusConfig.UnlockFPS
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.UnlockFPS = v
          if v then
            _G.LexusState.GraphicsUnlocked = false
          end
          return true
        end
      },
      {
        Key = "ModMenu_IpadView",
        UI = AliasMap.Switcher,
        Text = T("iPad View", "iPad View"),
        GetFunc = function()
          return _G.LexusConfig.IpadView
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.IpadView = v
          return true
        end
      },
      {
        Key = "ModMenu_Ipad_FOV",
        UI = AliasMap.Slider,
        Text = T("   FOV Angle", "   FOV Angle"),
        Min = 1,
        Max = 100,
        GetFunc = function()
          return (_G.LexusState.CustomTextData.IpadViewFOV or 120) - 80
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.IpadViewFOV = 80 + v
          return true
        end
      },
      {
        Key = "ModMenu_Crosshair",
        UI = AliasMap.Switcher,
        Text = T("Zero Spread (Crosshair)", "Zero Spread"),
        GetFunc = function()
          return _G.LexusConfig.Crosshair
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.Crosshair = v
          return true
        end
      },
      {
        Key = "ModMenu_WallhackNew",
        UI = AliasMap.Switcher,
        Text = T("Wallhack NEW (DrawDyeing)", "Wallhack NEW"),
        GetFunc = function()
          return _G.LexusConfig.WallhackNew
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.WallhackNew = v
          if v then
            if _G.StartNewWallhack then
              _G.StartNewWallhack()
            end
          elseif _G.StopNewWallhack then
            _G.StopNewWallhack()
          end
          return true
        end
      },
      {
        Key = "ModMenu_RemoveFog",
        UI = AliasMap.Switcher,
        Text = T("Remove Fog", "Remove Fog"),
        GetFunc = function()
          return _G.LexusConfig.RemoveFog
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.RemoveFog = v
          return true
        end
      },
      {
        Key = "ModMenu_BlackSky",
        UI = AliasMap.Switcher,
        Text = T("Black Sky", "Black Sky"),
        GetFunc = function()
          return _G.LexusConfig.BlackSky
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.BlackSky = v
          return true
        end
      }
    }
    local StackSkin = {
      {
        Key = "ModMenu_Skin_Ex",
        UI = AliasMap.TitleSwitcher,
        Text = T("\226\150\182 SKIN MOD", "\226\150\182 SKIN MOD"),
        ExpandIndex = 0,
        GetFunc = function()
          return _G.LexusConfig.ModSkin
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.ModSkin = v
          return true
        end
      },
      {
        Key = "ModMenu_Skin_Suit",
        UI = AliasMap.Slider,
        Text = T("   Suit (0-99)", "   Suit (0-99)"),
        ExpandHandle = "ModMenu_Skin_Ex",
        Min = 0,
        Max = {},
        GetFunc = function()
          return _G.LexusState.CustomTextData.SkinSuit or 0
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.SkinSuit = v
          _G.ForceRefreshSkinMaps()
          return true
        end
      },
      {
        Key = "ModMenu_Skin_Bag",
        UI = AliasMap.Slider,
        Text = T("   Bag (0-17)", "   Bag (0-17)"),
        ExpandHandle = "ModMenu_Skin_Ex",
        Min = 0,
        Max = {},
        GetFunc = function()
          return _G.LexusState.CustomTextData.SkinBag or 0
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.SkinBag = v
          _G.ForceRefreshSkinMaps()
          return true
        end
      },
      {
        Key = "ModMenu_Skin_Helmet",
        UI = AliasMap.Slider,
        Text = T("   Helmet (0-17)", "   Helmet (0-17)"),
        ExpandHandle = "ModMenu_Skin_Ex",
        Min = 0,
        Max = {},
        GetFunc = function()
          return _G.LexusState.CustomTextData.SkinHelmet or 0
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.SkinHelmet = v
          _G.ForceRefreshSkinMaps()
          return true
        end
      },
      {
        Key = "ModMenu_Skin_M416",
        UI = AliasMap.Slider,
        Text = T("   M416 (0-9)", "   M416 (0-9)"),
        ExpandHandle = "ModMenu_Skin_Ex",
        Min = 0,
        Max = {},
        GetFunc = function()
          return _G.LexusState.CustomTextData.SkinM416 or 0
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.SkinM416 = v
          _G.ForceRefreshSkinMaps()
          return true
        end
      },
      {
        Key = "ModMenu_Skin_AKM",
        UI = AliasMap.Slider,
        Text = T("   AKM (0-7)", "   AKM (0-7)"),
        ExpandHandle = "ModMenu_Skin_Ex",
        Min = 0,
        Max = {},
        GetFunc = function()
          return _G.LexusState.CustomTextData.SkinAKM or 0
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.SkinAKM = v
          _G.ForceRefreshSkinMaps()
          return true
        end
      },
      {
        Key = "ModMenu_Skin_Coupe",
        UI = AliasMap.Slider,
        Text = T("   Coupe (0-50)", "   Coupe (0-50)"),
        ExpandHandle = "ModMenu_Skin_Ex",
        Min = 0,
        Max = {},
        GetFunc = function()
          return _G.LexusState.CustomTextData.SkinCoupe or 0
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.SkinCoupe = v
          _G.ForceRefreshSkinMaps()
          return true
        end
      },
      {
        Key = "ModMenu_Skin_Dacia",
        UI = AliasMap.Slider,
        Text = T("   Dacia (0-70)", "   Dacia (0-70)"),
        ExpandHandle = "ModMenu_Skin_Ex",
        Min = 0,
        Max = {},
        GetFunc = function()
          return _G.LexusState.CustomTextData.SkinDacia or 0
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.SkinDacia = v
          _G.ForceRefreshSkinMaps()
          return true
        end
      }
    }
    local StackKillCounter = {
      {
        Key = "ModMenu_KillCounter",
        UI = AliasMap.Switcher,
        Text = T("Kill Counter & Effect", "Kill Counter & Effect"),
        GetFunc = function()
          return _G.LexusConfig.KillCounter
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.KillCounter = v
          return true
        end
      },
      {
        Key = "ModMenu_DeadBoxSkin",
        UI = AliasMap.Switcher,
        Text = T("DeadBox Skin", "DeadBox Skin"),
        GetFunc = function()
          return _G.LexusConfig.DeadBoxSkin
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.DeadBoxSkin = v
          return true
        end
      }
    }
    local StackMagicBullet = {
      {
        Key = "ModMenu_Magic_Ex",
        UI = AliasMap.TitleSwitcher,
        Text = T("\226\150\182 Custom Magic Bullet (RISK BAN)", "\226\150\182 Custom Magic Bullet (RISK BAN)"),
        ExpandIndex = 0,
        GetFunc = function()
          return _G.LexusConfig.CustomMagicBullet
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.CustomMagicBullet = v
          return true
        end
      },
      {
        Key = "ModMenu_Magic_Head",
        UI = AliasMap.Slider,
        Text = T("   Head Damage (0.0-5.0)", "   Head Damage (0.0-5.0)"),
        ExpandHandle = "ModMenu_Magic_Ex",
        MinValue = 0,
        MaxValue = 100,
        min = 0,
        max = 100,
        GetFunc = function()
          return math.floor((_G.LexusState.CustomTextData.MagicHead or 1.0) / 5.0 * 100 + 0.5)
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.MagicHead = v / 100.0 * 5.0
          return true
        end
      },
      {
        Key = "ModMenu_Magic_Body",
        UI = AliasMap.Slider,
        Text = T("   Body Damage (0.0-5.0)", "   Body Damage (0.0-5.0)"),
        ExpandHandle = "ModMenu_Magic_Ex",
        MinValue = 0,
        MaxValue = 100,
        min = 0,
        max = 100,
        GetFunc = function()
          return math.floor((_G.LexusState.CustomTextData.MagicBody or 1.0) / 5.0 * 100 + 0.5)
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.MagicBody = v / 100.0 * 5.0
          return true
        end
      },
      {
        Key = "ModMenu_Magic_Legs",
        UI = AliasMap.Slider,
        Text = T("   Legs Damage (0.0-5.0)", "   Legs Damage (0.0-5.0)"),
        ExpandHandle = "ModMenu_Magic_Ex",
        MinValue = 0,
        MaxValue = 100,
        min = 0,
        max = 100,
        GetFunc = function()
          return math.floor((_G.LexusState.CustomTextData.MagicLegs or 1.0) / 5.0 * 100 + 0.5)
        end,
        SetFunc = function(c, v)
          _G.LexusState.CustomTextData.MagicLegs = v / 100.0 * 5.0
          return true
        end
      },
      {
        Key = "ModMenu_MagicBullet",
        UI = AliasMap.Switcher,
        Text = T("Magic Bullet (auto head)", "Magic Bullet (auto head)"),
        GetFunc = function()
          return _G.LexusConfig.MagicBullet
        end,
        SetFunc = function(c, v)
          _G.LexusConfig.MagicBullet = v
          return true
        end
      }
    }
    SettingPageDefine.ModMenu = {
      Key = "ModMenu",
      Text = 999000,
      UIKey = "Setting_Page_Privacy",
      Category = {
        {
          Key = "Cat_ESP",
          Text = 999006,
          Stack = StackESPV2
        },
        {
          Key = "Cat_Aimbot",
          Text = 999007,
          Stack = StackAimbot
        },
        {
          Key = "Cat_MagicBullet",
          Text = "MAGIC BULLET",
          Stack = StackMagicBullet
        },
        {
          Key = "Cat_Graphics",
          Text = 999009,
          Stack = StackGraphics
        },
        {
          Key = "Cat_Skin",
          Text = 999011,
          Stack = StackSkin
        },
        {
          Key = "Cat_KillCounter",
          Text = 999012,
          Stack = StackKillCounter
        }
      }
    }
    table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
  end
  local UIManager = _G.UIManager
  if UIManager and not UIManager._IsModMenuHooked then
    local old_ShowUI = UIManager.ShowUI
    
    function UIManager.ShowUI(config, ...)
      local args = {
        ...
      }
      local n = select("#", ...)
      if config and config.keyName then
        local lowerKeyName = string.lower(config.keyName)
        if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
          local catalog = args[1]
          if type(catalog) == "table" and catalog[1] and type(catalog[1]) == "table" and catalog[1].Key then
            local hasModMenu = false
            for _, page in ipairs(catalog) do
              if type(page) == "table" and page.Key == "ModMenu" then
                hasModMenu = true
                break
              end
            end
            if not hasModMenu then
              table.insert(catalog, 1, SettingPageDefine.ModMenu)
            end
          end
        end
      end
      local table_unpack = table.unpack or unpack
      return old_ShowUI(config, table_unpack(args, 1, n))
    end
    
    UIManager._IsModMenuHooked = true
  end
end

local EXPIRY_TIMESTAMP = limitTime

local function FormatTimeRemaining(sec)
  if sec <= 0 then
    return "0d 0h 0m 0s"
  end
  local days = math.floor(sec / 86400)
  sec = sec % 86400
  local hours = math.floor(sec / 3600)
  sec = sec % 3600
  local minutes = math.floor(sec / 60)
  local seconds = sec % 60
  return string.format("%dd %dh %dm %ds", days, hours, minutes, seconds)
end

function CheckExpiration()
  local now = os.time()
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
    local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
    
    local function onClick()
    end
    
    if expired then
      local expiresAt = os.date("!%Y-%m-%d %H:%M:%S UTC", EXPIRY_TIMESTAMP)
      Msg.Show(4, "MOD EXPIRED", [[
THIS MOD HAS EXPIRED.

EXPIRED ON: ]] .. expiresAt .. "\n\nContact @OfficialOwner10x \240\159\148\165for renewal", onClick)
    else
      local remaining = _G._MOD_REMAINING_SECONDS or EXPIRY_TIMESTAMP - os.time()
      local formatted = FormatTimeRemaining(remaining)
      local expiresAt = os.date("!%Y-%m-%d %H:%M:%S UTC", EXPIRY_TIMESTAMP)
      Msg.Show(4, "NOTIFICATION", "MOD VALIDITY: " .. formatted .. [[

EXPIRES AT: ]] .. expiresAt .. [[


For support DM @OfficialOwner10x]], onClick)
    end
  end)
end

function _G.TryShowWelcome()
  if _G.WelcomeShown then
    return
  end
  if not CheckExpiration() then
    ShowExpiryPopup(true)
    return
  end
  ShowExpiryPopup(false)
  _G.WelcomeShown = true
end

function ShowLexusVIPMenu()
  if _G.LexusMenuAlreadyShown then
    return
  end
  if _G.LexusState.MenuStep ~= 0 then
    return
  end
  pcall(function()
    local Msg = require("client.slua.logic.common.logic_common_msg_box")
    if not Msg or not Msg.Show then
      return
    end
    
    local function Step_ScamAlert()
      Msg.Show(1, "OfficialOwner10x\240\159\148\1654.5 PAK", [[
DON'T PLAY LIKE A ANIMAL 
AVOID REPORTS PLAY SAFE!!

NO FEEDBACK - NO MORE UPDATES]], function()
        local Web = require("client.slua.logic.url.logic_webview_sdk")
        if Web and Web.OpenURL then
          Web:OpenURL("https://t.me/+V54kKmHbh6o0NmQ1")
        end
      end, function()
      end, "JOIN", "CLOSE")
      _G.LexusState.MenuStep = 99
      _G.LexusMenuAlreadyShown = true
    end
    
    local function Step_Welcome()
      Msg.Show(1, "4.5 @OfficialOwner10x\240\159\148\165PAID MOD", [[
ACTIVATION SUCCESSFUL!

IF YOU WANT TO PLAY SAFE DM THE OWNER TO GET YOUR FILE.
AVOID THE SCAMMERS AND COPY PASTERS, THE REAL OWNER IS @OfficialOwner10x]], function()
        _G.InitModMenuTab()
        Notify("VIP MOD MENU BY @10XGAMING \240\159\148\165to toggle features!")
        Step_ScamAlert()
      end, function()
      end, "OK", "CLOSE")
    end
    
    _G.LexusState.MenuStep = 1
    Step_Welcome()
  end)
end

pcall(function()
  local ok, tk = pcall(require, "common.time_ticker")
  if ok and tk and tk.AddTimerOnce then
    tk.AddTimerOnce(3, function()
      pcall(CheckExpiration)
    end)
    tk.AddTimerOnce(4, function()
      if not CheckExpiration() then
        pcall(ShowExpiryPopup, true)
      else
        pcall(_G.TryShowWelcome)
      end
    end)
  else
    pcall(_G.TryShowWelcome)
  end
end)

local function InitializeNativeESP()
  if _G.LexusState.NativeESPReady then
    return
  end
  pcall(function()
    local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
    local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
    
    local function ApplyCfg(cfg)
      if not cfg then
        return
      end
      if cfg[1006] then
        cfg[1006].bBindBlocked = true
        cfg[1006].bBindOutScreen = true
        cfg[1006].MaxWidgetNum = 99
        cfg[1006].MaxShowDistance = 6000000
        cfg[1006].bScaleByDistance = false
        cfg[1006].BindSocketName = "root"
        cfg[1006].bUseLuaWorldSocketName = true
        cfg[1006].WorldPositionOffset = FVector(0, 0, -30)
      end
      cfg[8888] = {
        UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
        MaxWidgetNum = 99,
        MaxShowDistance = 6000000,
        bBindOutScreen = true,
        bBindBlocked = true,
        bIsBindingActor = true,
        BindSocketName = "head",
        bUseLuaWorldSocketName = true,
        WorldPositionOffset = FVector(0, 0, 30),
        bNeedPreLoad = true,
        Priority = 2
      }
      cfg[9999] = {
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
    end
    
    ApplyCfg(currentMarkCfg)
    for k, cfg in pairs(package.loaded) do
      if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then
        ApplyCfg(cfg)
      end
    end
  end)
  _G.LexusState.NativeESPReady = true
  Notify("Native ESP System Initialized")
end

local function GetAllSkeletalMeshes(enemy, markData)
  local curTime = os.clock()
  if markData and markData.CachedMeshes and markData.CachedMeshTime and curTime - markData.CachedMeshTime < 3.0 then
    local validMeshes = {}
    for _, cachedMesh in ipairs(markData.CachedMeshes) do
      if Valid(cachedMesh) then
        table.insert(validMeshes, cachedMesh)
      end
    end
    markData.CachedMeshes = validMeshes
    return validMeshes
  end
  local meshes = {}
  if Valid(enemy.Mesh) then
    table.insert(meshes, enemy.Mesh)
  end
  pcall(function()
    local SkeletalMeshClass = import("SkeletalMeshComponent")
    if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
      local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
      if childs then
        local count = type(childs.Num) == "function" and childs:Num() or {}
        for i = 1, count do
          local comp = type(childs.Get) == "function" and childs:Get(i - 1) or childs[i]
          if Valid(comp) and comp ~= enemy.Mesh then
            table.insert(meshes, comp)
          end
        end
      end
    end
  end)
  if markData then
    markData.CachedMeshes = meshes
    markData.CachedMeshTime = curTime
  end
  return meshes
end

local LinearColor = import("LinearColor")
local CONSOLE_READY = false
local PROCESSED_PAWNS = {}
local TICK_COUNT = 0
local WH_TIMER
local TICK_INTERVAL = 0.3
local MAX_PAWNS_PER_TICK = 20
local RESET_PROCESSED_EVERY = 6
local AVATAR_SLOTS = {
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7
}
local colors = {
  vis = LinearColor(0, 255, 0, 255),
  occ = LinearColor(255, 0, 0, 255),
  bVis = LinearColor(0, 180, 0, 200),
  bOcc = LinearColor(180, 0, 0, 200)
}

local function SetupConsole()
  if CONSOLE_READY then
    return
  end
  pcall(function()
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local world = slua.getWorld()
    if not KismetSystemLibrary or not world then
      return
    end
    KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
    KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
    KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
    KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
    CONSOLE_READY = true
    print("[PBC] Console ready")
  end)
end

local function ApplyToMesh(mesh, visColor, occColor)
  if not mesh or not slua.isValid(mesh) then
    return
  end
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

local function IsPawnAlive(pawn)
  if not slua.isValid(pawn) then
    return false
  end
  if pawn.Health and pawn.Health > 0 then
    return true
  end
  return false
end

local function PBCtick()
  pcall(function()
    local localPawn = GameplayData.GetPlayerCharacter()
    if not slua.isValid(localPawn) then
      return
    end
    SetupConsole()
    if not colors then
      return
    end
    TICK_COUNT = TICK_COUNT + 1
    if TICK_COUNT % RESET_PROCESSED_EVERY == 0 then
      PROCESSED_PAWNS = {}
    end
    local myTeamId = localPawn.TeamID or 0
    local allPawns = Game:GetAllPlayerPawns() or {}
    local processedCount = 0
    for _, pawn in pairs(allPawns) do
      if processedCount >= MAX_PAWNS_PER_TICK then
        break
      end
      if slua.isValid(pawn) and pawn ~= localPawn and (not pawn.PlayerKey or not PROCESSED_PAWNS[pawn.PlayerKey]) and IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
        local isAI = pcall(Game.IsAI, pawn) and true or false
        local vis = isAI and colors.bVis or colors.vis
        local occ = isAI and colors.bOcc or colors.occ
        pcall(function()
          if slua.isValid(pawn.Mesh) then
            ApplyToMesh(pawn.Mesh, vis, occ)
          end
          local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
          if avatarComp and avatarComp.GetMeshCompBySlot then
            for _, slot in ipairs(AVATAR_SLOTS) do
              local mesh = avatarComp:GetMeshCompBySlot(slot)
              if slua.isValid(mesh) then
                ApplyToMesh(mesh, vis, occ)
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
                    ApplyToMesh(comp, vis, occ)
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
                    ApplyToMesh(comp, vis, occ)
                  end
                end
              end
            end
          end)
          local weapon = pawn:GetCurrentWeapon()
          if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            ApplyToMesh(weapon.Mesh, vis, occ)
          end
        end)
        if pawn.PlayerKey then
          PROCESSED_PAWNS[pawn.PlayerKey] = true
        end
        processedCount = processedCount + 1
      end
    end
  end)
end

local function StartPBC()
  SetupConsole()
  if not colors then
    print("[PBC] Colors not initialized, aborting")
    return false
  end
  if WH_TIMER then
    pcall(function()
      if _G.Game then
        _G.Game:RemoveGameTimer(WH_TIMER)
      end
    end)
    WH_TIMER = nil
  end
  if _G.Game and _G.Game.AddGameTimer then
    WH_TIMER = _G.Game:AddGameTimer(TICK_INTERVAL, true, PBCtick)
    print("[PBC] \226\156\133 Active (Game timer)")
    return true
  end
  local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
  if slua.isValid(pc) and pc.AddGameTimer then
    WH_TIMER = pc:AddGameTimer(TICK_INTERVAL, true, PBCtick)
    print("[PBC] \226\156\133 Active (PC timer)")
    return true
  end
  print("[PBC] \226\157\140 Could not start timer")
  return false
end

local retryCount = 0

local function RetryStart()
  if 30 <= retryCount then
    print("[PBC] \226\157\140 Failed to start after 30 retries")
    return
  end
  retryCount = retryCount + 1
  if StartPBC() then
    print("[PBC] \226\156\133 Module ready!")
  elseif _G.Game and _G.Game.AddGameTimer then
    _G.Game:AddGameTimer(1.0, false, RetryStart)
  end
end

function _pbc_Cleanup()
  if WH_TIMER then
    pcall(function()
      if _G.Game then
        _G.Game:RemoveGameTimer(WH_TIMER)
      end
    end)
    WH_TIMER = nil
  end
  PROCESSED_PAWNS = {}
  CONSOLE_READY = false
  print("[PBC] \240\159\167\185 Cleanup done")
end

function _G.StartNewWallhack()
  if WH_TIMER then
    return
  end
  RetryStart()
end

function _G.StopNewWallhack()
  if WH_TIMER then
    pcall(function()
      if _G.Game then
        _G.Game:RemoveGameTimer(WH_TIMER)
      end
    end)
    WH_TIMER = nil
  end
  PROCESSED_PAWNS = {}
  CONSOLE_READY = false
  print("[PBC] Stopped")
end

local _EC_Widget
local _EC_BTN = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"

local function IsInMatch()
  local gd = GameplayData
  if not gd then
    return false
  end
  local gs = gd.GetGameState and gd.GetGameState()
  if not slua.isValid(gs) then
    return false
  end
  if gs.GameModeType and gs.GameModeType ~= 0 then
    return true
  end
  if gs.bIsMatchStarted ~= nil then
    return gs.bIsMatchStarted
  end
  return false
end

local function _EC_Destroy()
  if _EC_Widget and slua.isValid(_EC_Widget) then
    pcall(function()
      _EC_Widget:RemoveFromParent()
    end)
  end
  _EC_Widget = nil
end

local function _EC_Create()
  if _EC_Widget and slua.isValid(_EC_Widget) then
    local parent = _EC_Widget:GetParent()
    if parent and slua.isValid(parent) then
      return _EC_Widget
    else
      _EC_Destroy()
    end
  end
  _EC_Widget = nil
  pcall(function()
    local btn = slua.loadUI(_EC_BTN)
    if not btn or not slua.isValid(btn) then
      return
    end
    pcall(function()
      require("game_frontend_hud").AddToContainer(UIContainers.Top, btn, 10500)
    end)
    if btn.RichText_Content then
      btn.RichText_Content:SetText("Enemies: 0  |  Bots: 0")
      local fi = btn.RichText_Content.Font
      if fi then
        fi.Size = 16
        btn.RichText_Content:SetFont(fi)
      end
    end
    pcall(function()
      local WLL = import("WidgetLayoutLibrary")
      if WLL then
        local slot = WLL.SlotAsCanvasSlot(btn)
        if slot then
          slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
          slot:SetAlignment(FVector2D(0.5, 0))
          slot:SetPosition(FVector2D(0, 12))
          slot:SetSize(FVector2D(260, 36))
        end
      end
    end)
    btn:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    _EC_Widget = btn
  end)
  return _EC_Widget
end

local function _M_DrawCounter()
  if not _G.LexusConfig.Esp9_Count then
    if _EC_Widget and slua.isValid(_EC_Widget) then
      _EC_Destroy()
    end
    return
  end
  if not IsInMatch() then
    if _EC_Widget and slua.isValid(_EC_Widget) then
      _EC_Destroy()
    end
    return
  end
  pcall(function()
    local gd = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
    local player = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
    if not Valid(player) then
      return
    end
    local w = _EC_Create()
    if not w or not slua.isValid(w) then
      return
    end
    local myTeam = player.TeamID or 0
    local myLoc = player:K2_GetActorLocation()
    local enemyCount = 0
    local botNearby = 0
    local seenEnemies = {}
    local pawns = {}
    if gd.GetAllPlayerCharacters then
      pawns = gd.GetAllPlayerCharacters() or {}
    elseif gd.GameCharacters then
      for _, c in pairs(gd.GameCharacters) do
        table.insert(pawns, c)
      end
    end
    for _, p in pairs(pawns) do
      if Valid(p) and p ~= player and (p.TeamID or 0) ~= myTeam and 0 < (p.Health or 0) then
        local pKey = p.PlayerKey or type(p.GetPlayerKey) == "function" and p:GetPlayerKey() or tostring(p)
        if not seenEnemies[pKey] then
          seenEnemies[pKey] = true
          local isBot = false
          pcall(function()
            if p.bEnsure == true then
              isBot = true
              return
            end
            if p.PlayerAIType ~= nil and p.PlayerAIType ~= 0 then
              isBot = true
              return
            end
            if _G.Game and type(_G.Game.IsAI) == "function" then
              local ok, r = pcall(function()
                return _G.Game:IsAI(p)
              end)
              if ok and r then
                isBot = true
              end
            end
          end)
          if isBot then
            pcall(function()
              local d = math.floor(FVector.Dist(myLoc, p:K2_GetActorLocation()) / 100)
              if d <= 500 then
                botNearby = botNearby + 1
              end
            end)
          else
            enemyCount = enemyCount + 1
          end
        end
      end
    end
    local txt = string.format("Enemies: %d  |  Bots: %d", enemyCount, botNearby)
    if w.RichText_Content then
      w.RichText_Content:SetText(txt)
    end
  end)
end

pcall(function()
  local EventSystem = _G.EventSystem
  if EventSystem then
    EventSystem:addEvent(EVENTTYPE_INGAME, EVENTID_INGAME_LEAVE_MATCH, function()
      _EC_Destroy()
    end)
    EventSystem:addEvent(EVENTTYPE_INGAME, EVENTID_GAME_MODE_STATE_CHANGE, function(_, _, state)
      if state == "FinishedState" then
        _EC_Destroy()
      elseif state == "EnterFighting" then
        _EC_Destroy()
        _G.TDFTDeKillCounts = {}
      end
    end)
  end
end)
local PlayerMapMarker = {}
local RedBoxOverlay = {
  bActive = false,
  MainContainer = nil,
  WidgetSlot = nil,
  TextBlockPlayer = nil,
  TextBlockBot = nil,
  Width = 260,
  Height = 25,
  OffsetY = 10,
  PlayerCount = 0,
  BotCount = 0,
  FontSize = 14,
  TextScaleValue = 1.0,
  NumLayers = 50,
  Red = 0.7,
  Green = 0.3,
  Blue = 1.0,
  LayerAlpha = 0.06,
  _CachedTextPlayer = "",
  _CachedTextBot = "",
  _CachedPosVec = nil
}

function RedBoxOverlay.Create()
  if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
    return true
  end
  local ParentCanvas = PlayerMapMarker.ESPCanvas
  if not ParentCanvas or not slua.isValid(ParentCanvas) then
    if not PlayerMapMarker.InitESPCanvas() then
      return false
    end
    ParentCanvas = PlayerMapMarker.ESPCanvas
  end
  if not ParentCanvas or not slua.isValid(ParentCanvas) then
    return false
  end
  local Container
  pcall(function()
    Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas)
  end)
  if not Container or not slua.isValid(Container) then
    return false
  end
  local FLinearColor = import("LinearColor") or _ENV.FLinearColor
  local FVector2D = import("Vector2D") or _ENV.FVector2D
  local color = FLinearColor(RedBoxOverlay.Red, RedBoxOverlay.Green, RedBoxOverlay.Blue, RedBoxOverlay.LayerAlpha)
  local numLayers = RedBoxOverlay.NumLayers
  local totalWidth = RedBoxOverlay.Width
  for i = 1, numLayers do
    local progress = (i / numLayers) ^ 1.15
    local layerWidth = progress * totalWidth
    local layerX = (totalWidth - layerWidth) / 2.0
    local border
    pcall(function()
      border = CGame:NewObjectFromPath("/Script/UMG.Border", Container)
    end)
    if border and slua.isValid(border) then
      pcall(function()
        border:SetBrushColor(color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
      do
        local slot = Container:AddChildToCanvas(border)
        if slot then
          slot:SetPosition(FVector2D(layerX, 0))
          slot:SetSize(FVector2D(layerWidth, RedBoxOverlay.Height))
        end
      end
    end
  end
  local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
  local txtPlayer
  pcall(function()
    txtPlayer = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container)
  end)
  if txtPlayer and slua.isValid(txtPlayer) then
    pcall(function()
      local strText = string.format("Player: %d", RedBoxOverlay.PlayerCount)
      txtPlayer:SetText(strText)
      RedBoxOverlay._CachedTextPlayer = strText
      local redLinear = FLinearColor(1.0, 0.0, 0.0, 1.0)
      if FSlateColor then
        txtPlayer:SetColorAndOpacity(FSlateColor(redLinear))
      else
        txtPlayer:SetColorAndOpacity(redLinear)
      end
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
  local txtBot
  pcall(function()
    txtBot = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container)
  end)
  if txtBot and slua.isValid(txtBot) then
    pcall(function()
      local strText = string.format("Bot: %d", RedBoxOverlay.BotCount)
      txtBot:SetText(strText)
      RedBoxOverlay._CachedTextBot = strText
      local greenLinear = FLinearColor(0.0, 1.0, 0.0, 1.0)
      if FSlateColor then
        txtBot:SetColorAndOpacity(FSlateColor(greenLinear))
      else
        txtBot:SetColorAndOpacity(greenLinear)
      end
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
  local MainSlot
  pcall(function()
    MainSlot = ParentCanvas:AddChildToCanvas(Container)
  end)
  if not MainSlot then
    return false
  end
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
  if RedBoxOverlay.PlayerCount == players and RedBoxOverlay.BotCount == bots then
    return
  end
  RedBoxOverlay.PlayerCount = players or 0
  RedBoxOverlay.BotCount = bots or 0
  if RedBoxOverlay.TextBlockPlayer and slua.isValid(RedBoxOverlay.TextBlockPlayer) then
    pcall(function()
      local strP = string.format("Player: %d", RedBoxOverlay.PlayerCount)
      if RedBoxOverlay._CachedTextPlayer ~= strP then
        RedBoxOverlay.TextBlockPlayer:SetText(strP)
        RedBoxOverlay._CachedTextPlayer = strP
      end
    end)
  end
  if RedBoxOverlay.TextBlockBot and slua.isValid(RedBoxOverlay.TextBlockBot) then
    pcall(function()
      local strB = string.format("Bot: %d", RedBoxOverlay.BotCount)
      if RedBoxOverlay._CachedTextBot ~= strB then
        RedBoxOverlay.TextBlockBot:SetText(strB)
        RedBoxOverlay._CachedTextBot = strB
      end
    end)
  end
end

function RedBoxOverlay.UpdatePosition()
  local Slot = RedBoxOverlay.WidgetSlot
  if not Slot or not slua.isValid(Slot) then
    return
  end
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not slua.isValid(PC) then
    return
  end
  local fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
  local FVector2D = import("Vector2D") or _ENV.FVector2D
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
  if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
    return
  end
  if RedBoxOverlay.Create() then
    RedBoxOverlay.bActive = true
    pcall(function()
      RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
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
  RedBoxOverlay._CachedPosVec = nil
end

_G.RedBoxOverlay = RedBoxOverlay
local InGameMarkTools
pcall(function()
  InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
end)
local SlateBlueprintLibrary, WidgetLayoutLibrary, KismetMathLibrary, KismetSystemLibrary
pcall(function()
  SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary")
end)
pcall(function()
  WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary")
end)
pcall(function()
  KismetMathLibrary = import("KismetMathLibrary")
end)
pcall(function()
  KismetSystemLibrary = import("KismetSystemLibrary")
end)
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
PlayerMapMarker.WidgetCompOffset = FVector and FVector(0, 0, 80) or {
  X = 0,
  Y = 0,
  Z = 80
}
PlayerMapMarker.WidgetCompDrawSize = FVector2D and FVector2D(210, 35) or {X = 210, Y = 35}
PlayerMapMarker.ESPBoneName = "head"
PlayerMapMarker.ESPWorldOffsetZ = 0
PlayerMapMarker.ESPScreenOffsetY = 0
PlayerMapMarker.ESPAnchorOffsetX = 35
PlayerMapMarker.ESPAnchorOffsetY = 0
PlayerMapMarker.ESPTextOffsetX = 0
PlayerMapMarker.ESPTextOffsetY = 0
PlayerMapMarker.ESPWidgetAlignment = FVector2D and FVector2D(0.5, 1.0) or {X = 0.5, Y = 1.0}
PlayerMapMarker.ESPWidgetSize = FVector2D and FVector2D(70, 21) or {X = 70, Y = 21}
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
PlayerMapMarker.SnapLineColor = FLinearColor and FLinearColor(0.6, 0.0, 0.0, 1.0) or {
  R = 150,
  G = 0,
  B = 0,
  A = 255
}
PlayerMapMarker.SnapLineOpacity = 0.7
PlayerMapMarker.bUseSkeleton = true
PlayerMapMarker.SkeletonThickness = 0.8
PlayerMapMarker.SkeletonColor = nil
PlayerMapMarker.SkeletonOpacity = 0.8
PlayerMapMarker.SkeletonMaxDistance = 100000
PlayerMapMarker.bUseVisibilityColor = true
PlayerMapMarker.SkeletonVisibleColor = FLinearColor and FLinearColor(0.0, 1.0, 0.0, 0.8) or {
  R = 0,
  G = 255,
  B = 0,
  A = 200
}
PlayerMapMarker.SkeletonCoverColor = FLinearColor and FLinearColor(0.9, 0.0, 0.0, 0.6) or {
  R = 230,
  G = 0,
  B = 0,
  A = 150
}
PlayerMapMarker.SkeletonWidgets = {}
PlayerMapMarker._StaticBoneLocCache = {}
PlayerMapMarker.SkeletonChains = {
  {
    "neck_01",
    "lowerarm_r",
    "hand_r"
  },
  {
    "neck_01",
    "lowerarm_l",
    "hand_l"
  },
  {
    "head",
    "neck_01",
    "pelvis"
  },
  {
    "pelvis",
    "calf_r",
    "foot_r"
  },
  {
    "pelvis",
    "calf_l",
    "foot_l"
  }
}
PlayerMapMarker.BoneNameFallbacks = {
  head = {
    "head",
    "Head",
    "head_socket"
  },
  neck_01 = {
    "neck_01",
    "Neck_01",
    "neck",
    "Neck"
  },
  clavicle_r = {
    "clavicle_r",
    "Clavicle_R",
    "clavicle_R"
  },
  upperarm_r = {
    "upperarm_r",
    "UpperArm_R",
    "arm_r",
    "arm_r_01"
  },
  lowerarm_r = {
    "lowerarm_r",
    "LowerArm_R",
    "forearm_r"
  },
  hand_r = {
    "hand_r",
    "Hand_R",
    "hand_r_socket"
  },
  clavicle_l = {
    "clavicle_l",
    "Clavicle_L",
    "clavicle_L"
  },
  upperarm_l = {
    "upperarm_l",
    "UpperArm_L",
    "arm_l",
    "arm_l_01"
  },
  lowerarm_l = {
    "lowerarm_l",
    "LowerArm_L",
    "forearm_l"
  },
  hand_l = {
    "hand_l",
    "Hand_L",
    "hand_l_socket"
  },
  spine_03 = {
    "spine_03",
    "Spine_03",
    "spine_02",
    "spine"
  },
  spine_02 = {
    "spine_02",
    "Spine_02",
    "spine_01"
  },
  pelvis = {
    "pelvis",
    "pelvis",
    "hip"
  },
  thigh_r = {
    "thigh_r",
    "Thigh_R",
    "leg_r"
  },
  calf_r = {
    "calf_r",
    "Calf_R",
    "shin_r"
  },
  foot_r = {
    "foot_r",
    "Foot_R",
    "foot_r_socket"
  },
  thigh_l = {
    "thigh_l",
    "Thigh_L",
    "leg_l"
  },
  calf_l = {
    "calf_l",
    "Calf_L",
    "shin_l"
  },
  foot_l = {
    "foot_l",
    "Foot_L",
    "foot_l_socket"
  }
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
  if obj == nil then
    return false
  end
  if slua and slua.isValid then
    return slua.isValid(obj)
  end
  return obj ~= nil
end

function PlayerMapMarker.SetupScreenMarkConfig()
  if PlayerMapMarker._bScreenMarkConfigSetup then
    return true
  end
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
        WorldPositionOffset = FVector and FVector(0, 0, 80) or {
          X = 0,
          Y = 0,
          Z = 80
        }
      }
      PlayerMapMarker._bScreenMarkConfigSetup = true
      bOK = true
    end
  end)
  return bOK
end

function PlayerMapMarker.GetGameplayData()
  if PlayerMapMarker._CachedGameplayData then
    return PlayerMapMarker._CachedGameplayData
  end
  local ok, GDP = pcall(function()
    return require("GameLua.GameCore.Data.GameplayData")
  end)
  if ok and GDP then
    PlayerMapMarker._CachedGameplayData = GDP
    return GDP
  end
  return nil
end

function PlayerMapMarker.GetMyPlayerController()
  local PC = PlayerMapMarker._CachedPC
  if PC and IsValid(PC) then
    return PC
  end
  local GDP = PlayerMapMarker.GetGameplayData()
  if not GDP then
    return nil
  end
  pcall(function()
    PC = GDP.GetPlayerController and GDP.GetPlayerController()
  end)
  if PC and IsValid(PC) then
    PlayerMapMarker._CachedPC = PC
    return PC
  end
  return nil
end

function PlayerMapMarker.GetCGameState()
  if CGameState and IsValid(CGameState) then
    return CGameState
  end
  if PlayerMapMarker._CachedCGameState and IsValid(PlayerMapMarker._CachedCGameState) then
    return PlayerMapMarker._CachedCGameState
  end
  local ok, GS = pcall(function()
    return require("GameLua.GameCore.Data.CGameState")
  end)
  if ok and GS then
    PlayerMapMarker._CachedCGameState = GS
    return GS
  end
  return nil
end

function PlayerMapMarker.GetAllCharacters()
  local AllChars = {}
  pcall(function()
    local Pawns = Game:GetAllPlayerPawns()
    if Pawns then
      for _, Pawn in pairs(Pawns) do
        if Pawn and slua.isValid(Pawn) then
          local pKey
          if Pawn.GetPlayerKey then
            pKey = Pawn:GetPlayerKey()
          end
          if not pKey and Pawn.PlayerKey then
            pKey = Pawn.PlayerKey
          end
          if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then
            pKey = Pawn.PlayerState.PlayerKey
          end
          if pKey then
            AllChars[pKey] = Pawn
          end
        end
      end
    end
  end)
  if not next(AllChars) then
    local GS = PlayerMapMarker.GetCGameState()
    if GS and GS.GetAllCharacters then
      pcall(function()
        AllChars = GS:GetAllCharacters()
      end)
    end
  end
  return AllChars
end

function PlayerMapMarker.GetMyPlayerKey()
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not IsValid(PC) then
    return nil
  end
  local MyKey
  pcall(function()
    if PC.GetPlayerKey then
      MyKey = PC:GetPlayerKey()
    elseif PC.PlayerState and PC.PlayerState.PlayerKey then
      MyKey = PC.PlayerState.PlayerKey
    end
  end)
  return MyKey
end

function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
  local bIsMe = false
  pcall(function()
    local GDP = PlayerMapMarker.GetGameplayData()
    if GDP and GDP.GetLocalCharacter then
      local MyChar = GDP.GetLocalCharacter()
      if MyChar and Character == MyChar then
        bIsMe = true
        return
      end
    end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if PC and PC.GetPawn then
      local Pawn = PC:GetPawn()
      if Pawn and Character == Pawn then
        bIsMe = true
        return
      end
    end
  end)
  if MyKey ~= nil and PlayerKey ~= nil then
    bIsMe = bIsMe or false
  end
  return bIsMe
end

function PlayerMapMarker.GetCharacterLocation(Character)
  if not IsValid(Character) then
    return nil
  end
  local Loc
  pcall(function()
    if Character.K2_GetActorLocation then
      Loc = Character:K2_GetActorLocation()
    end
  end)
  if not Loc then
    pcall(function()
      if Game and Game.GetActorLocation then
        Loc = Game:GetActorLocation(Character)
      end
    end)
  end
  return Loc
end

function PlayerMapMarker.CalcDistance(Loc1, Loc2)
  if not Loc1 or not Loc2 then
    return nil
  end
  local Dist
  pcall(function()
    if FVector and FVector.Dist2D then
      Dist = FVector.Dist2D(Loc1, Loc2)
    end
  end)
  if not Dist then
    pcall(function()
      local DX = (Loc1.X or 0) - (Loc2.X or 0)
      local DY = (Loc1.Y or 0) - (Loc2.Y or 0)
      Dist = math.sqrt(DX * DX + DY * DY)
    end)
  end
  return Dist
end

function PlayerMapMarker.GetDistanceString(MyLoc, TargetLoc)
  if not PlayerMapMarker.bShowDistance then
    return ""
  end
  if not MyLoc or not TargetLoc then
    return ""
  end
  local Dist = PlayerMapMarker.CalcDistance(MyLoc, TargetLoc)
  if not Dist then
    return ""
  end
  local Meters = Dist / 100
  if Meters < 1000 then
    return string.format("%dm", math.floor(Meters))
  else
    return string.format("%.1fkm", Meters / 1000)
  end
end

function PlayerMapMarker.GetMyLocation()
  local GDP = PlayerMapMarker.GetGameplayData()
  if not GDP then
    return nil
  end
  local MyChar
  pcall(function()
    MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter()
  end)
  if not IsValid(MyChar) then
    local PC = PlayerMapMarker.GetMyPlayerController()
    if IsValid(PC) then
      pcall(function()
        if PC.GetPawn then
          local Pawn = PC:GetPawn()
          if IsValid(Pawn) and Pawn.K2_GetActorLocation then
            return Pawn:K2_GetActorLocation()
          end
        end
      end)
    end
    return nil
  end
  return PlayerMapMarker.GetCharacterLocation(MyChar)
end

function PlayerMapMarker.GetPlayerName(Character)
  if not IsValid(Character) then
    return "Unknown"
  end
  local Name
  pcall(function()
    if Character.GetPlayerNameSafety then
      Name = Character:GetPlayerNameSafety()
    end
  end)
  if not Name then
    pcall(function()
      local PS
      if Character.GetPlayerStateSafety then
        PS = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then
        PS = Character:GetPlayerState()
      end
      if IsValid(PS) and PS.GetPlayerName then
        Name = PS:GetPlayerName()
      end
    end)
  end
  return Name or "Unknown"
end

function PlayerMapMarker.IsAI(Character)
  local bAI = false
  pcall(function()
    if Game and Game.IsAI then
      bAI = Game:IsAI(Character)
    end
  end)
  return bAI
end

function PlayerMapMarker.IsAlive(Character)
  local bAlive = true
  pcall(function()
    if Character.IsAlive then
      bAlive = Character:IsAlive()
    end
  end)
  return bAlive
end

function PlayerMapMarker.IsOurESPWidget(w)
  if not w or not slua.isValid(w) then
    return false
  end
  local bIsOurs = false
  pcall(function()
    local wstr = tostring(w)
    for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
      if ESPData and ESPData.Widget and ESPData.Widget.Container then
        local cstr = tostring(ESPData.Widget.Container)
        if cstr == wstr then
          bIsOurs = true
          return
        end
      end
    end
  end)
  if bIsOurs then
    return true
  end
  pcall(function()
    if w.GetChildrenCount then
      local n = w:GetChildrenCount()
      for i = 0, n - 1 do
        local child = w:GetChildAt(i)
        if child and slua.isValid(child) then
          local cstr = tostring(child)
          if string.find(cstr, "Border") then
            bIsOurs = true
            break
          end
        end
      end
    end
  end)
  if not bIsOurs then
    pcall(function()
      local slot = w.Slot
      if slot and slot.GetPosition then
        local pos = slot:GetPosition()
        if pos and (math.abs(pos.X or 0) > 1 or 1 < math.abs(pos.Y or 0)) then
          bIsOurs = true
        end
      end
    end)
  end
  return bIsOurs
end

function PlayerMapMarker.ApplyAnchorBasedPosition(Slot, ScreenPos, Canvas)
  if not Slot or not ScreenPos then
    return false
  end
  local sx = ScreenPos.X or 0
  local sy = ScreenPos.Y or 0
  local sz = PlayerMapMarker.ESPWidgetSize or FVector2D and FVector2D(100, 30) or {X = 100, Y = 30}
  local align = PlayerMapMarker.ESPWidgetAlignment or FVector2D and FVector2D(0.5, 1.0) or {X = 0.5, Y = 1.0}
  local canvasW, canvasH = 0, 0
  if PlayerMapMarker._cachedViewportW and PlayerMapMarker._cachedViewportW > 200 then
    canvasW = PlayerMapMarker._cachedViewportW
    canvasH = PlayerMapMarker._cachedViewportH
  end
  if canvasW < 200 then
    pcall(function()
      local PC = PlayerMapMarker.GetMyPlayerController()
      if IsValid(PC) and PC.GetViewportSize then
        local VS = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
        PC:GetViewportSize(VS)
        if VS and VS.X and VS.X > 200 then
          canvasW = VS.X
          canvasH = VS.Y
          PlayerMapMarker._cachedViewportW = canvasW
          PlayerMapMarker._cachedViewportH = canvasH
        end
      end
    end)
  end
  if 200 < canvasW and 200 < canvasH then
    local anchorX = (sx + (PlayerMapMarker.ESPAnchorOffsetX or 0)) / canvasW
    local anchorY = (sy + (PlayerMapMarker.ESPAnchorOffsetY or 0)) / canvasH
    anchorX = math.max(0, math.min(1, anchorX))
    anchorY = math.max(0, math.min(1, anchorY))
    local bSuccess = false
    pcall(function()
      local FAnchors = import("Anchors") or import("/Script/SlateCore.Anchors")
      if Slot.SetAnchors and FAnchors then
        local anchors = FAnchors(anchorX, anchorY, anchorX, anchorY)
        if anchors then
          Slot:SetAnchors(anchors)
          Slot:SetPosition(FVector2D and FVector2D(0, 0) or {X = 0, Y = 0})
          bSuccess = true
        end
      end
    end)
    if not bSuccess then
      pcall(function()
        if Slot.SetAnchors then
          Slot:SetAnchors(anchorX, anchorY, anchorX, anchorY)
          Slot:SetPosition(FVector2D and FVector2D(0, 0) or {X = 0, Y = 0})
          bSuccess = true
        end
      end)
    end
    if bSuccess then
      pcall(function()
        if Slot.SetOffsets and import("Margin") then
          Slot:SetOffsets(import("Margin")(0, 0, sz.X, sz.Y))
        end
      end)
      pcall(function()
        Slot:SetSize(sz)
      end)
      pcall(function()
        Slot:SetAlignment(align)
      end)
      pcall(function()
        if Slot.SetAutoSize then
          Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true)
        end
      end)
      pcall(function()
        if Slot.SetZOrder then
          Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2)
        end
      end)
      return true
    end
  end
  pcall(function()
    Slot:SetPosition(FVector2D and FVector2D(sx, sy) or {X = sx, Y = sy})
    pcall(function()
      Slot:SetSize(sz)
    end)
    pcall(function()
      Slot:SetAlignment(align)
    end)
    pcall(function()
      if Slot.SetAutoSize then
        Slot:SetAutoSize(PlayerMapMarker.ESPWidgetAutoSize or true)
      end
    end)
    pcall(function()
      if Slot.SetZOrder then
        Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 2)
      end
    end)
  end)
  return false
end

function PlayerMapMarker.InitESPCanvas()
  if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return true
  end
  local InGameUITools
  pcall(function()
    InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
  end)
  if not InGameUITools then
    return false
  end
  local MainControlBaseUI
  pcall(function()
    MainControlBaseUI = InGameUITools.GetMainControlBaseUI()
  end)
  if not MainControlBaseUI or not Game:IsValid(MainControlBaseUI) then
    return false
  end
  local ParentCanvas
  pcall(function()
    if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then
      ParentCanvas = MainControlBaseUI.CanvasPanel_0
    elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then
      ParentCanvas = MainControlBaseUI.CanvasPanel_42
    end
  end)
  if not ParentCanvas then
    return false
  end
  PlayerMapMarker.ESPCanvas = ParentCanvas
  pcall(function()
    local nChildren = ParentCanvas:GetChildrenCount()
    for i = nChildren - 1, 0, -1 do
      local child = ParentCanvas:GetChildAt(i)
      if child and slua.isValid(child) and PlayerMapMarker.IsOurESPWidget(child) then
        pcall(function()
          ParentCanvas:RemoveChild(child)
        end)
      end
    end
  end)
  return true
end

function PlayerMapMarker.FindProgressBarInWidget(WidgetObj, Depth, MaxDepth)
  if not WidgetObj or not slua.isValid(WidgetObj) then
    return nil
  end
  Depth = Depth or 0
  MaxDepth = MaxDepth or 5
  if Depth > MaxDepth then
    return nil
  end
  local bIsPB = false
  pcall(function()
    if WidgetObj.SetPercent and WidgetObj.SetFillColorAndOpacity then
      bIsPB = true
    end
  end)
  if bIsPB then
    return WidgetObj
  end
  local nChildren = 0
  pcall(function()
    if WidgetObj.GetChildrenCount then
      nChildren = WidgetObj:GetChildrenCount()
    end
  end)
  for i = 0, math.max(nChildren - 1, 0) do
    local child
    pcall(function()
      child = WidgetObj:GetChildAt(i)
    end)
    if child and slua.isValid(child) then
      do
        local result = PlayerMapMarker.FindProgressBarInWidget(child, Depth + 1, MaxDepth)
        if result then
          return result
        end
      end
    end
  end
  return nil
end

function PlayerMapMarker.GetTeamID(Character)
  if not IsValid(Character) then
    return nil
  end
  local TeamID
  pcall(function()
    if Character.GetTeamID then
      TeamID = Character:GetTeamID()
    end
  end)
  if not TeamID then
    pcall(function()
      local PS
      if Character.GetPlayerStateSafety then
        PS = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then
        PS = Character:GetPlayerState()
      end
      if IsValid(PS) and PS.GetTeamID then
        TeamID = PS:GetTeamID()
      elseif IsValid(PS) and PS.TeamID then
        TeamID = PS.TeamID
      end
    end)
  end
  if not TeamID then
    pcall(function()
      if Character.TeamID then
        TeamID = Character.TeamID
      end
    end)
  end
  return TeamID
end

function PlayerMapMarker.GetTeamColor(TeamID)
  if TeamID == nil or TeamID == 0 then
    return FLinearColor and FLinearColor(0.2, 0.4, 1.0, 1.0) or {
      R = 50,
      G = 100,
      B = 255,
      A = 255
    }
  end
  local TeamColors = {
    [1] = {
      R = 255,
      G = 50,
      B = 50,
      A = 255,
      fR = 1.0,
      fG = 0.2,
      fB = 0.2
    },
    [2] = {
      R = 50,
      G = 255,
      B = 50,
      A = 255,
      fR = 0.2,
      fG = 1.0,
      fB = 0.2
    },
    [3] = {
      R = 50,
      G = 100,
      B = 255,
      A = 255,
      fR = 0.2,
      fG = 0.4,
      fB = 1.0
    },
    [4] = {
      R = 255,
      G = 255,
      B = 50,
      A = 255,
      fR = 1.0,
      fG = 1.0,
      fB = 0.2
    },
    [5] = {
      R = 255,
      G = 50,
      B = 255,
      A = 255,
      fR = 1.0,
      fG = 0.2,
      fB = 1.0
    },
    [6] = {
      R = 50,
      G = 255,
      B = 255,
      A = 255,
      fR = 0.2,
      fG = 1.0,
      fB = 1.0
    },
    [7] = {
      R = 255,
      G = 150,
      B = 50,
      A = 255,
      fR = 1.0,
      fG = 0.6,
      fB = 0.2
    },
    [8] = {
      R = 150,
      G = 50,
      B = 255,
      A = 255,
      fR = 0.6,
      fG = 0.2,
      fB = 1.0
    },
    [9] = {
      R = 200,
      G = 255,
      B = 50,
      A = 255,
      fR = 0.8,
      fG = 1.0,
      fB = 0.2
    },
    [10] = {
      R = 50,
      G = 150,
      B = 255,
      A = 255,
      fR = 0.2,
      fG = 0.6,
      fB = 1.0
    },
    [11] = {
      R = 255,
      G = 100,
      B = 150,
      A = 255,
      fR = 1.0,
      fG = 0.4,
      fB = 0.6
    },
    [12] = {
      R = 100,
      G = 255,
      B = 150,
      A = 255,
      fR = 0.4,
      fG = 1.0,
      fB = 0.6
    },
    [13] = {
      R = 150,
      G = 150,
      B = 50,
      A = 255,
      fR = 0.6,
      fG = 0.6,
      fB = 0.2
    },
    [14] = {
      R = 50,
      G = 200,
      B = 150,
      A = 255,
      fR = 0.2,
      fG = 0.8,
      fB = 0.6
    },
    [15] = {
      R = 255,
      G = 200,
      B = 50,
      A = 255,
      fR = 1.0,
      fG = 0.8,
      fB = 0.2
    }
  }
  local colorIndex = TeamID % 15
  if colorIndex == 0 then
    colorIndex = 15
  end
  local c = TeamColors[colorIndex]
  return FLinearColor and FLinearColor(c.fR, c.fG, c.fB, 1.0) or {
    R = c.R,
    G = c.G,
    B = c.B,
    A = c.A
  }
end

local _WhiteTexture
local _bWhiteTextureFailed = false

local function GetWhiteTexture()
  if _WhiteTexture then
    return _WhiteTexture
  end
  if _bWhiteTextureFailed then
    return nil
  end
  pcall(function()
    local paths = {
      "/Game/BluePrints/UI/Textures/White.White",
      "/Game/BluePrints/UI/Textures/Common/White.White",
      "/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture"
    }
    for _, path in ipairs(paths) do
      pcall(function()
        local tex = import(path)
        if tex and slua.isValid(tex) then
          _WhiteTexture = tex
          return
        end
      end)
      if _WhiteTexture then
        break
      end
    end
  end)
  if not _WhiteTexture then
    _bWhiteTextureFailed = true
  end
  return _WhiteTexture
end

local function SetImageColor(Image, color)
  if not Image or not slua.isValid(Image) then
    return false
  end
  local bOK = false
  pcall(function()
    if Image.SetBrushTintColor then
      Image:SetBrushTintColor(color)
      bOK = true
    end
  end)
  pcall(function()
    if Image.SetColorAndOpacity then
      Image:SetColorAndOpacity(color)
      bOK = true
    end
  end)
  pcall(function()
    if Image.SetBrushFromTexture then
      local whiteTex = GetWhiteTexture()
      if whiteTex then
        Image:SetBrushFromTexture(whiteTex, false)
        if Image.SetColorAndOpacity then
          Image:SetColorAndOpacity(color)
        end
        bOK = true
      end
    end
  end)
  pcall(function()
    Image:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    Image:SetRenderOpacity(1.0)
  end)
  return bOK
end

function PlayerMapMarker._GetWidgetRoot(WidgetObj)
  if not WidgetObj or not slua.isValid(WidgetObj) then
    return nil
  end
  local Root
  pcall(function()
    if WidgetObj.GetRootWidget then
      Root = WidgetObj:GetRootWidget()
    end
  end)
  if Root and slua.isValid(Root) then
    return Root
  end
  pcall(function()
    if WidgetObj.WidgetTree and WidgetObj.WidgetTree.RootWidget then
      Root = WidgetObj.WidgetTree.RootWidget
    end
  end)
  if Root and slua.isValid(Root) then
    return Root
  end
  pcall(function()
    if WidgetObj.RootWidget and slua.isValid(WidgetObj.RootWidget) then
      Root = WidgetObj.RootWidget
    end
  end)
  return Root
end

function PlayerMapMarker._FindNamedWidgetInTree(WidgetObj, TargetName, MaxDepth)
  if not WidgetObj or not slua.isValid(WidgetObj) then
    return nil
  end
  MaxDepth = MaxDepth or 8
  local wname
  pcall(function()
    if WidgetObj.GetName then
      wname = WidgetObj:GetName()
    end
  end)
  if wname and wname == TargetName then
    return WidgetObj
  end
  local wstr = tostring(WidgetObj)
  if wstr and string.find(wstr, TargetName, 1, true) then
    if wname and wname == TargetName then
      return WidgetObj
    elseif not wname or wname == "" then
      local _, endPos = string.find(wstr, TargetName, 1, true)
      if endPos then
        local nextChar = string.sub(wstr, endPos + 1, endPos + 1)
        if nextChar ~= "_" and nextChar ~= "" then
          return WidgetObj
        end
      end
    end
  end
  local nChildren = 0
  pcall(function()
    if WidgetObj.GetChildrenCount then
      nChildren = WidgetObj:GetChildrenCount()
    end
  end)
  if 0 < nChildren then
    for i = 0, nChildren - 1 do
      local child
      pcall(function()
        child = WidgetObj:GetChildAt(i)
      end)
      if child and slua.isValid(child) then
        do
          local found = PlayerMapMarker._FindNamedWidgetInTree(child, TargetName, MaxDepth - 1)
          if found then
            return found
          end
        end
      end
    end
  else
    local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
    if Root and slua.isValid(Root) and Root ~= WidgetObj then
      local found = PlayerMapMarker._FindNamedWidgetInTree(Root, TargetName, MaxDepth - 1)
      if found then
        return found
      end
    end
  end
  return nil
end

function PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
  if not Widget or not Widget.Container then
    return
  end
  if not _G.LexusConfig.Esp9_Team then
    pcall(function()
      local W = Widget.Container
      if W and slua.isValid(W) then
        local img1 = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamBG", 8)
        if img1 and slua.isValid(img1) then
          img1:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
        local img2 = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamLogoBG", 8)
        if img2 and slua.isValid(img2) then
          img2:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
        if Widget.TeamBgBorder and slua.isValid(Widget.TeamBgBorder) then
          Widget.TeamBgBorder:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
      end
    end)
    return
  end
  local color = PlayerMapMarker.GetTeamColor(TeamID)
  if not color then
    return
  end
  pcall(function()
    local W = Widget.Container
    if not W or not slua.isValid(W) then
      return
    end
    local bBG = false
    local Image_TeamBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamBG", 8)
    if Image_TeamBG and slua.isValid(Image_TeamBG) then
      bBG = SetImageColor(Image_TeamBG, color)
    end
    local Image_TeamLogoBG = PlayerMapMarker._FindNamedWidgetInTree(W, "Image_TeamLogoBG", 8)
    if Image_TeamLogoBG and slua.isValid(Image_TeamLogoBG) then
      SetImageColor(Image_TeamLogoBG, color)
    end
    if W.SetTeamColor then
      pcall(function()
        W:SetTeamColor(TeamID)
      end)
    end
    if not Widget.TeamBgBorder or not slua.isValid(Widget.TeamBgBorder) then
      pcall(function()
        local Border = CGame:NewObjectFromPath("/Script/UMG.Border", W)
        if Border and slua.isValid(Border) then
          pcall(function()
            Border:SetBrushColor(color)
          end)
          pcall(function()
            Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
          end)
          pcall(function()
            Border:SetRenderOpacity(0.7)
          end)
          pcall(function()
            Border:SetDesiredSizeOverride(FVector2D and FVector2D(120, 20) or {X = 120, Y = 20})
          end)
          pcall(function()
            if W.AddChild then
              W:AddChild(Border)
            end
          end)
          pcall(function()
            if Border.SetZOrder then
              Border:SetZOrder(-1)
            end
          end)
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
  if not IsValid(Character) then
    return nil
  end
  local Mesh
  pcall(function()
    if Character.Mesh and Game:IsValid(Character.Mesh) then
      Mesh = Character.Mesh
    end
  end)
  if not Mesh then
    pcall(function()
      local SkeletalMeshCompClass = import("/Script/Engine.SkeletalMeshComponent")
      Mesh = Character:GetComponentByClass(SkeletalMeshCompClass)
    end)
  end
  return Mesh
end

function PlayerMapMarker.GetESPLocation(Character)
  if not IsValid(Character) then
    return nil
  end
  local BoneLoc = PlayerMapMarker.GetCharacterLocation(Character)
  if BoneLoc then
    local heightOffset = 85
    pcall(function()
      if Character.bIsCrouched then
        heightOffset = 60
      end
      if Character.IsProne and Character:IsProne() then
        heightOffset = 30
      end
    end)
    pcall(function()
      BoneLoc.Z = BoneLoc.Z + heightOffset + (PlayerMapMarker.ESPWorldOffsetZ or 0)
    end)
  end
  return BoneLoc
end

function PlayerMapMarker.GetCharacterWeaponInfo(Character)
  if not IsValid(Character) then
    return nil
  end
  local WeaponID, WeaponName, WeaponIconPath, WeaponIconTexture, CurrentWeapon
  pcall(function()
    if Character.GetCurrentWeapon then
      CurrentWeapon = Character:GetCurrentWeapon()
    end
  end)
  if not CurrentWeapon then
    pcall(function()
      CurrentWeapon = Character.CurrentWeapon
    end)
  end
  if not CurrentWeapon then
    pcall(function()
      if Character.GetWeaponManager then
        local WM = Character:GetWeaponManager()
        if WM and WM.GetCurrentWeapon then
          CurrentWeapon = WM:GetCurrentWeapon()
        end
      end
    end)
  end
  if CurrentWeapon and IsValid(CurrentWeapon) then
    pcall(function()
      if CurrentWeapon.GetWeaponID then
        WeaponID = CurrentWeapon:GetWeaponID()
      end
    end)
    if not WeaponID then
      pcall(function()
        WeaponID = CurrentWeapon.WeaponID
      end)
    end
    if not WeaponID then
      pcall(function()
        if CurrentWeapon.GetItemID then
          WeaponID = CurrentWeapon:GetItemID()
        end
      end)
    end
    pcall(function()
      if CurrentWeapon.GetWeaponName then
        WeaponName = CurrentWeapon:GetWeaponName()
      end
    end)
    pcall(function()
      if CurrentWeapon.GetWeaponIconPath then
        WeaponIconPath = CurrentWeapon:GetWeaponIconPath()
      end
    end)
    pcall(function()
      if CurrentWeapon.GetWeaponIcon then
        WeaponIconTexture = CurrentWeapon:GetWeaponIcon()
      end
    end)
  end
  if not WeaponID then
    pcall(function()
      local PS
      if Character.GetPlayerStateSafety then
        PS = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then
        PS = Character:GetPlayerState()
      end
      if PS and IsValid(PS) then
        if PS.GetCurrentWeaponID then
          WeaponID = PS:GetCurrentWeaponID()
        end
        if not WeaponID and PS.CurWeaponID then
          WeaponID = PS.CurWeaponID
        end
      end
    end)
  end
  return {
    WeaponID = WeaponID,
    WeaponName = WeaponName,
    WeaponIconPath = WeaponIconPath,
    WeaponIconTexture = WeaponIconTexture,
    CurrentWeapon = CurrentWeapon
  }
end

function PlayerMapMarker.FindWeaponIconInWidget(WidgetObj, Depth, MaxDepth)
  if not WidgetObj or not slua.isValid(WidgetObj) then
    return nil
  end
  Depth = Depth or 0
  MaxDepth = MaxDepth or 8
  local propNames = {
    "Image_Weapon",
    "Image_WeaponIcon",
    "Image_Gun",
    "Image_Icon",
    "WeaponIcon",
    "WeaponImage",
    "Image_Equip"
  }
  for _, pname in ipairs(propNames) do
    pcall(function()
      local prop = WidgetObj[pname]
      if prop and slua.isValid(prop) then
        local hasBrush = false
        pcall(function()
          if prop.Brush then
            hasBrush = true
          end
        end)
        if hasBrush then
          return prop
        end
      end
    end)
  end
  if Depth >= MaxDepth then
    return nil
  end
  local nChildren = 0
  pcall(function()
    if WidgetObj.GetChildrenCount then
      nChildren = WidgetObj:GetChildrenCount()
    end
  end)
  for i = 0, math.max(nChildren - 1, 0) do
    local child
    pcall(function()
      child = WidgetObj:GetChildAt(i)
    end)
    if child and slua.isValid(child) then
      do
        local result = PlayerMapMarker.FindWeaponIconInWidget(child, Depth + 1, MaxDepth)
        if result then
          return result
        end
      end
    end
  end
  if nChildren == 0 then
    local Root = PlayerMapMarker._GetWidgetRoot(WidgetObj)
    if Root and slua.isValid(Root) and Root ~= WidgetObj then
      local result = PlayerMapMarker.FindWeaponIconInWidget(Root, Depth + 1, MaxDepth)
      if result then
        return result
      end
    end
  end
  return nil
end

function PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, DefaultW, DefaultH)
  if not ImageWidget or not slua.isValid(ImageWidget) then
    return
  end
  DefaultW = DefaultW or 138
  DefaultH = DefaultH or 69
  pcall(function()
    local brush = ImageWidget.Brush
    if brush then
      brush.ImageSize = FVector2D and FVector2D(DefaultW, DefaultH) or {X = DefaultW, Y = DefaultH}
      brush.DrawAs = 3
      brush.TintColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
        R = 1,
        G = 1,
        B = 1,
        A = 1
      }
      if ImageWidget.SetBrush then
        ImageWidget:SetBrush(brush)
      end
    end
    if ImageWidget.SetDesiredSizeOverride then
      ImageWidget:SetDesiredSizeOverride(FVector2D and FVector2D(DefaultW, DefaultH) or {X = DefaultW, Y = DefaultH})
    end
    local slot = ImageWidget.Slot
    if slot and slot.SetSize then
      slot:SetSize(FVector2D and FVector2D(DefaultW, DefaultH) or {X = DefaultW, Y = DefaultH})
    end
    ImageWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    ImageWidget:SetRenderOpacity(1.0)
    ImageWidget:SetColorAndOpacity(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
      R = 1,
      G = 1,
      B = 1,
      A = 1
    })
  end)
end

function PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
  local fullIcon = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
    R = 1,
    G = 1,
    B = 1,
    A = 1
  }
  if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
    return
  end
  pcall(function()
    if ourWeaponIcon.SetRenderOpacity then
      ourWeaponIcon:SetRenderOpacity(1.0)
    end
  end)
  pcall(function()
    if ourWeaponIcon.SetColorAndOpacity then
      ourWeaponIcon:SetColorAndOpacity(fullIcon)
    end
  end)
  pcall(function()
    local brush = ourWeaponIcon.Brush
    if brush then
      pcall(function()
        brush.TintColor = fullIcon
      end)
      if ourWeaponIcon.SetBrush then
        ourWeaponIcon:SetBrush(brush)
      end
    end
  end)
  local chainNames = {
    "Border_WeaponColor",
    "Border_Weapon",
    "Border_WeaponIcon",
    "SizeBox_Weapon",
    "ScaleBox_Weapon",
    "Switcher_WeaponIcon"
  }
  for _, pname in ipairs(chainNames) do
    pcall(function()
      local node = Container and Container[pname]
      if node and slua.isValid(node) and node.SetRenderOpacity then
        node:SetRenderOpacity(1.0)
      end
      if node and slua.isValid(node) and node.SetColorAndOpacity then
        node:SetColorAndOpacity(fullIcon)
      end
    end)
  end
end

function PlayerMapMarker.ApplyWeaponIconToImage(ImageWidget, winfo)
  if not ImageWidget or not slua.isValid(ImageWidget) then
    return false, "no_widget"
  end
  if not winfo or not winfo.WeaponID then
    return false, "no_weapon_id"
  end
  local iconPath
  local method = "none"
  local bHasAddKnownMissing = false
  local defaultW = 138
  local defaultH = 69
  pcall(function()
    local itemRecord = CDataTable.GetTableData("Item", winfo.WeaponID)
    if itemRecord and itemRecord.KillWhiteIcon and itemRecord.KillWhiteIcon ~= "" then
      iconPath = itemRecord.KillWhiteIcon
      method = "KillWhiteIcon"
    end
    if (not iconPath or iconPath == "") and winfo.WeaponIconPath and winfo.WeaponIconPath ~= "" then
      iconPath = winfo.WeaponIconPath
      method = "WeaponIconPath"
    end
    if (not iconPath or iconPath == "") and winfo.WeaponIconTexture and slua.isValid(winfo.WeaponIconTexture) and ImageWidget.SetBrushFromTexture then
      ImageWidget:SetBrushFromTexture(winfo.WeaponIconTexture, true)
      method = "WeaponIconTexture"
      return
    end
    if not iconPath or iconPath == "" then
      local UIUtil = require("client.common.ui_util")
      iconPath, bHasAddKnownMissing = UIUtil.GetItemBigIcon(winfo.WeaponID, ImageWidget)
      if iconPath and iconPath ~= "" then
        method = "GetItemBigIcon"
      end
    end
    if not iconPath or iconPath == "" then
      local UIUtil = require("client.common.ui_util")
      iconPath = UIUtil.GetItemSmallIcon(winfo.WeaponID, ImageWidget, bHasAddKnownMissing)
      if iconPath and iconPath ~= "" then
        method = "GetItemSmallIcon"
      end
    end
  end)
  if method == "WeaponIconTexture" then
    PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH)
    return true, method
  end
  if not iconPath or iconPath == "" then
    return false, "no_path"
  end
  local bOK = false
  pcall(function()
    if ImageWidget.SetBrushResourceFromPathSync then
      ImageWidget:SetBrushResourceFromPathSync(iconPath, true)
      bOK = true
    end
    if not bOK then
      local util = require("client.slua_ui_framework.util")
      local result = util.SetTexture(ImageWidget, iconPath, {
        sync = true,
        bMatchSize = true,
        bIsInCombatState = true,
        bHasAddKnownMissing = bHasAddKnownMissing
      })
      bOK = result ~= nil
    end
    if not bOK then
      local tex = import(iconPath)
      if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then
        ImageWidget:SetBrushFromTexture(tex, true)
        bOK = true
      end
    end
    if not bOK then
      local LoadObject = import("LoadObject")
      if LoadObject then
        local tex = LoadObject(iconPath)
        if tex and slua.isValid(tex) and ImageWidget.SetBrushFromTexture then
          ImageWidget:SetBrushFromTexture(tex, true)
          bOK = true
        end
      end
    end
  end)
  if bOK then
    PlayerMapMarker.FixWeaponIconBrushSize(ImageWidget, defaultW, defaultH)
  end
  return bOK, method .. ":" .. tostring(iconPath)
end

function PlayerMapMarker.CopyWeaponIconBrushFromNative(ourWeaponIcon, nativeWeaponIcon)
  if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
    return false
  end
  if not nativeWeaponIcon or not slua.isValid(nativeWeaponIcon) then
    return false
  end
  local bCopied = false
  pcall(function()
    local nBrush = nativeWeaponIcon.Brush
    if nBrush then
      local resObj
      pcall(function()
        resObj = nBrush.ResourceObject
      end)
      if resObj and slua.isValid(resObj) and ourWeaponIcon.SetBrushFromTexture then
        ourWeaponIcon:SetBrushFromTexture(resObj, true)
        bCopied = true
      end
      if bCopied then
        do
          local imgSize
          pcall(function()
            imgSize = nBrush.ImageSize
          end)
          if imgSize then
            do
              local oBrush = ourWeaponIcon.Brush
              if oBrush then
                oBrush.ImageSize = imgSize
                if ourWeaponIcon.SetBrush then
                  ourWeaponIcon:SetBrush(oBrush)
                end
              end
            end
          end
        end
      end
    end
  end)
  return bCopied
end

function PlayerMapMarker.AddWeaponIconToESP(WidgetData, Character)
  if not WidgetData or not WidgetData.Container then
    return
  end
  local Container = WidgetData.Container
  if not slua.isValid(Container) then
    return
  end
  if not _G.LexusConfig.Esp9_Weapon then
    pcall(function()
      local chainNames = {
        "Border_WeaponColor",
        "Border_Weapon",
        "Border_WeaponIcon",
        "SizeBox_Weapon",
        "ScaleBox_Weapon",
        "Switcher_WeaponIcon"
      }
      for _, pname in ipairs(chainNames) do
        local node = Container[pname]
        if node and slua.isValid(node) and node.SetWidgetVisibility then
          node:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
      end
      local ourWeaponIcon = Container.WeaponIcon or PlayerMapMarker.FindWeaponIconInWidget(Container, 0, 8)
      if ourWeaponIcon and slua.isValid(ourWeaponIcon) then
        ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      end
    end)
    WidgetData._LastWeaponID = 0
    WidgetData._WeaponIconApplied = false
    return
  end
  pcall(function()
    local ourWeaponIcon = Container.WeaponIcon
    if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
      ourWeaponIcon = PlayerMapMarker.FindWeaponIconInWidget(Container, 0, 8)
    end
    if not ourWeaponIcon or not slua.isValid(ourWeaponIcon) then
      return
    end
    local winfo = Character and PlayerMapMarker.GetCharacterWeaponInfo(Character) or nil
    if not (winfo and winfo.WeaponID) or winfo.WeaponID == 0 then
      pcall(function()
        ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      end)
      local chainNames = {
        "Border_WeaponColor",
        "Border_Weapon",
        "Border_WeaponIcon",
        "SizeBox_Weapon",
        "ScaleBox_Weapon",
        "Switcher_WeaponIcon"
      }
      for _, pname in ipairs(chainNames) do
        pcall(function()
          local node = Container and Container[pname]
          if node and slua.isValid(node) and node.SetWidgetVisibility then
            node:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
          end
        end)
      end
      WidgetData._LastWeaponID = 0
      WidgetData._WeaponIconApplied = false
      return
    end
    if WidgetData._LastWeaponID == winfo.WeaponID and WidgetData._WeaponIconApplied then
      pcall(function()
        ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
      pcall(function()
        ourWeaponIcon:SetRenderOpacity(1.0)
      end)
      local chainNames = {
        "Border_WeaponColor",
        "Border_Weapon",
        "Border_WeaponIcon",
        "SizeBox_Weapon",
        "ScaleBox_Weapon",
        "Switcher_WeaponIcon"
      }
      for _, pname in ipairs(chainNames) do
        pcall(function()
          local node = Container and Container[pname]
          if node and slua.isValid(node) and node.SetWidgetVisibility then
            node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            pcall(function()
              if node.SetRenderOpacity then
                node:SetRenderOpacity(1.0)
              end
            end)
          end
        end)
      end
      if WidgetData._CachedSwitcherIndexes then
        for sName, idx in pairs(WidgetData._CachedSwitcherIndexes) do
          pcall(function()
            local ws = Container[sName]
            if ws and slua.isValid(ws) and ws.SetActiveWidgetIndex then
              ws:SetActiveWidgetIndex(idx)
            end
          end)
        end
      end
      if WidgetData._CachedParentSwitchers then
        for _, data in pairs(WidgetData._CachedParentSwitchers) do
          pcall(function()
            if data.w and slua.isValid(data.w) and data.w.SetActiveWidgetIndex then
              data.w:SetActiveWidgetIndex(data.idx)
            end
          end)
        end
      end
      return
    end
    local chainNames = {
      "Border_WeaponColor",
      "Border_Weapon",
      "Border_WeaponIcon",
      "SizeBox_Weapon",
      "ScaleBox_Weapon",
      "Switcher_WeaponIcon"
    }
    for _, pname in ipairs(chainNames) do
      pcall(function()
        local node = Container and Container[pname]
        if node and slua.isValid(node) and node.SetWidgetVisibility then
          node:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
      end)
    end
    local bCopied = false
    if winfo and winfo.WeaponID then
      local ok, method = PlayerMapMarker.ApplyWeaponIconToImage(ourWeaponIcon, winfo)
      if ok then
        bCopied = true
      end
    end
    local bWeaponIconSet = false
    if Character and winfo and winfo and winfo.WeaponID then
      pcall(function()
        if Container.SetWeaponIcon then
          Container:SetWeaponIcon(winfo.WeaponID)
          bWeaponIconSet = true
        end
      end)
      if not bWeaponIconSet then
        pcall(function()
          if Container.SetWeaponIconByID then
            Container:SetWeaponIconByID(winfo.WeaponID)
            bWeaponIconSet = true
          end
        end)
      end
      if not bWeaponIconSet then
        pcall(function()
          if Container.UpdateWeaponIcon then
            Container:UpdateWeaponIcon(winfo.WeaponID)
            bWeaponIconSet = true
          end
        end)
      end
      if not bWeaponIconSet then
        pcall(function()
          if Container.SetWeaponID then
            Container:SetWeaponID(winfo.WeaponID)
            bWeaponIconSet = true
          end
        end)
      end
      pcall(function()
        if Container.SetData then
          Container:SetData(Character)
        end
      end)
      pcall(function()
        if Container.SetPlayerInfo then
          Container:SetPlayerInfo(Character)
        end
      end)
      if winfo.CurrentWeapon then
        pcall(function()
          if Container.SetCurrentWeapon then
            Container:SetCurrentWeapon(winfo.CurrentWeapon)
          end
        end)
      end
    end
    if bWeaponIconSet then
      pcall(function()
        local innerIcon = Container.Image_Icon
        if (not innerIcon or not slua.isValid(innerIcon)) and Container.CanvasPanel_Type1 then
          innerIcon = Container.CanvasPanel_Type1.Image_Icon
        end
        if not innerIcon or not slua.isValid(innerIcon) then
          local function findImageIcon(w, depth)
            if not (w and slua.isValid(w)) or 8 < depth then
              return nil
            end
            local prop = w.Image_Icon
            if prop and slua.isValid(prop) then
              return prop
            end
            local n = 0
            pcall(function()
              if w.GetChildrenCount then
                n = w:GetChildrenCount()
              end
            end)
            for i = 0, math.max(n - 1, 0) do
              local c
              pcall(function()
                c = w:GetChildAt(i)
              end)
              if c then
                do
                  local r = findImageIcon(c, depth + 1)
                  if r then
                    return r
                  end
                end
              end
            end
            return nil
          end
          
          innerIcon = findImageIcon(Container, 0)
        end
        if innerIcon and slua.isValid(innerIcon) and innerIcon ~= ourWeaponIcon then
          pcall(function()
            local ibrush = innerIcon.Brush
            if ibrush then
              local iresObj
              pcall(function()
                iresObj = ibrush.ResourceObject
              end)
              if iresObj and slua.isValid(iresObj) then
                if ourWeaponIcon.SetBrushFromAsset then
                  ourWeaponIcon:SetBrushFromAsset(iresObj)
                  bCopied = true
                end
                if not bCopied and ourWeaponIcon.SetBrushFromTexture then
                  ourWeaponIcon:SetBrushFromTexture(iresObj)
                  bCopied = true
                end
              end
            end
          end)
          if not bCopied then
            pcall(function()
              local brush = innerIcon.Brush
              if brush then
                local iresObj
                pcall(function()
                  iresObj = brush.ResourceObject
                end)
                if iresObj and slua.isValid(iresObj) and ourWeaponIcon.SetBrushFromTexture then
                  ourWeaponIcon:SetBrushFromTexture(iresObj, false)
                  PlayerMapMarker.FixWeaponIconBrushSize(ourWeaponIcon)
                  bCopied = true
                end
              end
            end)
          end
        end
      end)
    end
    if not bCopied then
      local nativeWeaponIcon
      if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
        local nChildren = 0
        pcall(function()
          nChildren = PlayerMapMarker.ESPCanvas:GetChildrenCount()
        end)
        for i = 0, math.max(nChildren - 1, 0) do
          local child
          pcall(function()
            child = PlayerMapMarker.ESPCanvas:GetChildAt(i)
          end)
          if child and slua.isValid(child) then
            do
              local cstr = tostring(child)
              if string.find(cstr, "OB_PlayerHeadHPItem") and not PlayerMapMarker.IsOurESPWidget(child) then
                local nativeIcon = child.WeaponIcon
                if nativeIcon and slua.isValid(nativeIcon) then
                  nativeWeaponIcon = nativeIcon
                  break
                end
              end
            end
          end
        end
      end
      if nativeWeaponIcon and slua.isValid(nativeWeaponIcon) then
        local okNative, nativeMethod = PlayerMapMarker.CopyWeaponIconBrushFromNative(ourWeaponIcon, nativeWeaponIcon)
        if okNative then
          bCopied = true
        end
      end
    end
    if not bCopied then
      pcall(function()
        local brush = ourWeaponIcon.Brush
        if brush then
          local resObj
          pcall(function()
            resObj = brush.ResourceObject
          end)
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
          local imgSize
          pcall(function()
            imgSize = brush.ImageSize
          end)
          local bZeroSize = false
          if imgSize then
            local sx, sy
            pcall(function()
              sx = imgSize.X
            end)
            pcall(function()
              sy = imgSize.Y
            end)
            if (not sx or sx == 0) and (not sy or sy == 0) then
              bZeroSize = true
            end
          end
          if bZeroSize then
            pcall(function()
              brush.ImageSize = FVector2D and FVector2D(PlayerMapMarker.WeaponIconBrushW or 138, PlayerMapMarker.WeaponIconBrushH or 69) or {X = 138, Y = 69}
            end)
          end
          pcall(function()
            brush.DrawAs = 3
          end)
          if ourWeaponIcon.SetBrush then
            ourWeaponIcon:SetBrush(brush)
          end
        end
      end)
    end
    pcall(function()
      ourWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    PlayerMapMarker.ApplyWeaponIconFullOpacity(Container, ourWeaponIcon)
    PlayerMapMarker.FixWeaponIconBrushSize(ourWeaponIcon)
    pcall(function()
      local function findWidgetInSwitcher(switcher, targetWidget)
        if not switcher or not slua.isValid(switcher) then
          return nil
        end
        if not switcher.GetChildrenCount or not switcher.GetChildAt then
          return nil
        end
        local nChildren = switcher:GetChildrenCount()
        for i = 0, math.max(nChildren - 1, 0) do
          local child = switcher:GetChildAt(i)
          if child and slua.isValid(child) then
            if child == targetWidget then
              return i
            end
            
            local function searchDescendant(w, target, depth)
              if 5 < depth then
                return false
              end
              if w == target then
                return true
              end
              if not w.GetChildrenCount or not w.GetChildAt then
                return false
              end
              local nc = w:GetChildrenCount()
              for j = 0, math.max(nc - 1, 0) do
                local c = w:GetChildAt(j)
                if c and slua.isValid(c) and searchDescendant(c, target, depth + 1) then
                  return true
                end
              end
              return false
            end
            
            if searchDescendant(child, targetWidget, 0) then
              return i
            end
          end
        end
        return nil
      end
      
      for _, switcherName in ipairs({
        "Switcher_WeaponIcon",
        "WidgetSwitcher_Type",
        "WidgetSwitcher_Type2"
      }) do
        local ws = Container[switcherName]
        if ws and slua.isValid(ws) and ws.GetChildrenCount and ws.GetChildAt then
          local foundIdx = findWidgetInSwitcher(ws, ourWeaponIcon)
          if foundIdx and ws.SetActiveWidgetIndex then
            ws:SetActiveWidgetIndex(foundIdx)
            WidgetData._CachedSwitcherIndexes = WidgetData._CachedSwitcherIndexes or {}
            WidgetData._CachedSwitcherIndexes[switcherName] = foundIdx
          end
        end
      end
    end)
    pcall(function()
      local parent = ourWeaponIcon
      for depth = 0, 8 do
        if parent and slua.isValid(parent) and parent.GetParent then
          local p = parent:GetParent()
          if p and slua.isValid(p) then
            local pStr = tostring(p)
            if string.find(pStr, "WidgetSwitcher") and p.GetChildrenCount and p.GetChildAt then
              local nCh = p:GetChildrenCount()
              for i = 0, math.max(nCh - 1, 0) do
                local child = p:GetChildAt(i)
                if child and slua.isValid(child) then
                  local function isDescendant(w, target, d)
                    if 5 < d then
                      return false
                    end
                    if w == target then
                      return true
                    end
                    if not w.GetChildrenCount or not w.GetChildAt then
                      return false
                    end
                    local nc = w:GetChildrenCount()
                    for j = 0, math.max(nc - 1, 0) do
                      local c = w:GetChildAt(j)
                      if c and slua.isValid(c) and isDescendant(c, target, d + 1) then
                        return true
                      end
                    end
                    return false
                  end
                  
                  if isDescendant(child, ourWeaponIcon, 0) then
                    if p.SetActiveWidgetIndex then
                      p:SetActiveWidgetIndex(i)
                      WidgetData._CachedParentSwitchers = WidgetData._CachedParentSwitchers or {}
                      WidgetData._CachedParentSwitchers[tostring(p)] = {w = p, idx = i}
                    end
                    break
                  end
                end
              end
            end
            parent = p
          else
            break
          end
        else
          break
        end
      end
    end)
    pcall(function()
      local parent = ourWeaponIcon
      for depth = 0, 8 do
        pcall(function()
          if parent.GetParent then
            local p = parent:GetParent()
            if p and slua.isValid(p) then
              if p.SetWidgetVisibility then
                p:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
              end
              pcall(function()
                if p.SetRenderOpacity then
                  p:SetRenderOpacity(1.0)
                end
              end)
              pcall(function()
                if p.SetContentColorAndOpacity then
                  p:SetContentColorAndOpacity(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
                    R = 1,
                    G = 1,
                    B = 1,
                    A = 1
                  })
                end
              end)
              pcall(function()
                if p.SetColorAndOpacity then
                  p:SetColorAndOpacity(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
                    R = 1,
                    G = 1,
                    B = 1,
                    A = 1
                  })
                end
              end)
              pcall(function()
                if p.SetBrushTintColor then
                  p:SetBrushTintColor(FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
                    R = 1,
                    G = 1,
                    B = 1,
                    A = 1
                  })
                end
              end)
              pcall(function()
                local pBrush = p.Brush
                if pBrush and pBrush.TintColor then
                  pBrush.TintColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
                    R = 1,
                    G = 1,
                    B = 1,
                    A = 1
                  }
                  if p.SetBrush then
                    p:SetBrush(pBrush)
                  end
                end
              end)
              pcall(function()
                if p.InvalidateLayout then
                  p:InvalidateLayout()
                end
              end)
              parent = p
            end
          end
        end)
      end
    end)
    pcall(function()
      if ourWeaponIcon.InvalidateLayout then
        ourWeaponIcon:InvalidateLayout()
      end
    end)
    pcall(function()
      if Container.UpdateWeapon then
        Container:UpdateWeapon()
      end
    end)
    pcall(function()
      if Container.RefreshWeapon then
        Container:RefreshWeapon()
      end
    end)
    WidgetData._LastWeaponID = winfo.WeaponID
    WidgetData._WeaponIconApplied = true
  end)
end

PlayerMapMarker._OBHeadWidgetClass = nil
PlayerMapMarker._OBHeadWidgetLoadFailed = false
PlayerMapMarker._bDumpedWidgetChildren = false

function PlayerMapMarker.CreateESPWidget()
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return nil
  end
  if PlayerMapMarker._OBHeadWidgetLoadFailed then
    return nil
  end
  if not PlayerMapMarker._OBHeadWidgetClass then
    pcall(function()
      local Path = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP"
      local uClass = slua.loadClass(Path)
      if uClass then
        PlayerMapMarker._OBHeadWidgetClass = uClass
      end
    end)
    if not PlayerMapMarker._OBHeadWidgetClass then
      PlayerMapMarker._OBHeadWidgetLoadFailed = true
      return nil
    end
  else
    local bValid = false
    pcall(function()
      bValid = slua.isValid(PlayerMapMarker._OBHeadWidgetClass)
    end)
    if not bValid then
      PlayerMapMarker._OBHeadWidgetLoadFailed = true
      PlayerMapMarker._OBHeadWidgetClass = nil
      return nil
    end
  end
  local Widget
  pcall(function()
    local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
    local PC = PlayerMapMarker.GetMyPlayerController()
    local OuterObj = IsValid(PC) and PC.Object or PlayerMapMarker.ESPCanvas
    Widget = STExtraBlueprintFunctionLibrary.CreateWidgetByClass(PlayerMapMarker._OBHeadWidgetClass, OuterObj)
  end)
  if not Widget then
    return nil
  end
  pcall(function()
    Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  pcall(function()
    Widget:SetRenderOpacity(1.0)
  end)
  local NameText, HealthFill
  local bIsOriginalProgressBar = false
  pcall(function()
    NameText = Widget.TextBlock_TeamName
    if NameText and slua.isValid(NameText) then
      pcall(function()
        NameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    end
    if Widget.TextBlock_PlayerName and slua.isValid(Widget.TextBlock_PlayerName) then
      pcall(function()
        Widget.TextBlock_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    end
    local WS_Type = Widget.WidgetSwitcher_Type
    local WS_Type2 = Widget.WidgetSwitcher_Type2
    if WS_Type and slua.isValid(WS_Type) then
      pcall(function()
        if WS_Type.SetActiveWidgetIndex then
          WS_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex)
        end
      end)
    end
    if WS_Type2 and slua.isValid(WS_Type2) then
      pcall(function()
        if WS_Type2.SetActiveWidgetIndex then
          WS_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index)
        end
      end)
    end
    local SizeBox_HP = Widget.SizeBox_HP
    if SizeBox_HP and slua.isValid(SizeBox_HP) then
      pcall(function()
        SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
      pcall(function()
        SizeBox_HP:SetHeightOverride(6)
      end)
      pcall(function()
        SizeBox_HP:SetWidthOverride(100)
      end)
      local ExistingChild
      pcall(function()
        if SizeBox_HP.GetContent then
          ExistingChild = SizeBox_HP:GetContent()
        end
      end)
      if not ExistingChild then
        pcall(function()
          if SizeBox_HP.GetChildAt then
            ExistingChild = SizeBox_HP:GetChildAt(0)
          end
        end)
      end
      if ExistingChild and slua.isValid(ExistingChild) then
        pcall(function()
          ExistingChild:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        pcall(function()
          ExistingChild:SetRenderOpacity(1.0)
        end)
        local FoundPB = PlayerMapMarker.FindProgressBarInWidget(ExistingChild, 0, 5)
        if FoundPB and slua.isValid(FoundPB) then
          HealthFill = FoundPB
          bIsOriginalProgressBar = true
          pcall(function()
            FoundPB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
          end)
          pcall(function()
            FoundPB:SetRenderOpacity(1.0)
          end)
        else
          do
            local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", ExistingChild)
            if PB then
              pcall(function()
                PB:SetFillColorAndOpacity(FLinearColor and FLinearColor(0, 1, 0, 1) or {
                  R = 0,
                  G = 1,
                  B = 0,
                  A = 1
                })
              end)
              pcall(function()
                PB:SetPercent(1.0)
              end)
              pcall(function()
                PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
              end)
              pcall(function()
                PB:SetRenderOpacity(1.0)
              end)
              pcall(function()
                PB:SetDesiredSizeOverride(FVector2D and FVector2D(100, 6) or {X = 100, Y = 6})
              end)
              pcall(function()
                ExistingChild:AddChild(PB)
              end)
              HealthFill = PB
            end
          end
        end
      else
        do
          local PB = CGame:NewObjectFromPath("/Script/UMG.ProgressBar", SizeBox_HP)
          if PB then
            pcall(function()
              PB:SetFillColorAndOpacity(FLinearColor and FLinearColor(0, 1, 0, 1) or {
                R = 0,
                G = 1,
                B = 0,
                A = 1
              })
            end)
            pcall(function()
              PB:SetPercent(1.0)
            end)
            pcall(function()
              PB:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            pcall(function()
              PB:SetRenderOpacity(1.0)
            end)
            pcall(function()
              PB:SetDesiredSizeOverride(FVector2D and FVector2D(100, 6) or {X = 100, Y = 6})
            end)
            do
              local bUsedSetContent = false
              pcall(function()
                if SizeBox_HP.SetContent then
                  SizeBox_HP:SetContent(PB)
                  bUsedSetContent = true
                end
              end)
              if not bUsedSetContent then
                pcall(function()
                  SizeBox_HP:AddChild(PB)
                end)
              end
              HealthFill = PB
            end
          end
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
    HasChildren = NameText ~= nil
  }
  return WidgetData
end

PlayerMapMarker._CanvasScaleX = 1.0
PlayerMapMarker._CanvasScaleY = 1.0
PlayerMapMarker._CanvasOffsetX = 0.0
PlayerMapMarker._CanvasOffsetY = 0.0

function PlayerMapMarker.UpdateCanvasTransform(PC)
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return
  end
  local success = false
  pcall(function()
    local SBL = SlateBlueprintLibrary
    if SBL and SBL.AbsoluteToLocal then
      local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
      if cg then
        local pt0 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(0, 0) or {X = 0, Y = 0})
        local pt1 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(100, 100) or {X = 100, Y = 100})
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
          local pt0 = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
          local pt1 = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
          WLL.ScreenToWidgetLocal(PC, cg, FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}, pt0)
          WLL.ScreenToWidgetLocal(PC, cg, FVector2D and FVector2D(100, 100) or {X = 100, Y = 100}, pt1)
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
    if WLL and WLL.GetViewportScale then
      scale = WLL.GetViewportScale(PC) or 1.0
    end
    PlayerMapMarker._CanvasScaleX = 1.0 / scale
    PlayerMapMarker._CanvasScaleY = 1.0 / scale
    PlayerMapMarker._CanvasOffsetX = 0
    PlayerMapMarker._CanvasOffsetY = 0
  end
end

function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
  if not ScreenPixelPos then
    return FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
  end
  local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
  local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
  local offsetX = PlayerMapMarker._CanvasOffsetX or 0
  local offsetY = PlayerMapMarker._CanvasOffsetY or 0
  return FVector2D and FVector2D(ScreenPixelPos.X * scaleX + offsetX, ScreenPixelPos.Y * scaleY + offsetY) or {
    X = ScreenPixelPos.X * scaleX + offsetX,
    Y = ScreenPixelPos.Y * scaleY + offsetY
  }
end

function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
  if not IsValid(PC) or not WorldLoc then
    return false, FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
  end
  local ScreenPixelPos = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
  local bOK = false
  pcall(function()
    local res = PC:ProjectWorldLocationToScreen(WorldLoc, ScreenPixelPos, true)
    if res == true or res == 1 or ScreenPixelPos and (ScreenPixelPos.X ~= 0 or ScreenPixelPos.Y ~= 0) then
      bOK = true
    end
  end)
  if not (bOK and ScreenPixelPos) or ScreenPixelPos.X == 0 and ScreenPixelPos.Y == 0 then
    return false, FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
  end
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
        if sz and sz.X and sz.X > 200 then
          width = sz.X
          height = sz.Y
        end
      end
    end)
  end
  if 200 < width then
    return width, height
  end
  pcall(function()
    local WLL = WidgetLayoutLibrary
    if WLL and WLL.GetViewportSize then
      local sz = WLL.GetViewportSize(PC or PlayerMapMarker.GetMyPlayerController())
      if sz and sz.X and sz.X > 200 then
        width = sz.X
        height = sz.Y
      end
    end
  end)
  if 200 < width then
    pcall(function()
      local WLL = WidgetLayoutLibrary
      if WLL and WLL.GetViewportScale then
        local scale = WLL.GetViewportScale(PC or PlayerMapMarker.GetMyPlayerController())
        if scale and type(scale) == "number" and 0 < scale and scale ~= 1.0 then
          width = width / scale
          height = height / scale
        end
      end
    end)
    return width, height
  end
  return PlayerMapMarker._cachedViewportW or 1920, PlayerMapMarker._cachedViewportH or 1080
end

function PlayerMapMarker.UpdateESPPositionWithPC(Widget, WorldLoc, PC, CanvasPos)
  if not Widget or not IsValid(PC) then
    return false
  end
  local Container = Widget.Container or Widget
  local bOnScreen = true
  if not CanvasPos then
    if not WorldLoc then
      return false
    end
    bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
  end
  if not bOnScreen then
    pcall(function()
      Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    end)
    return false
  end
  pcall(function()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
      local ptr = tostring(Container)
      local Slot = PlayerMapMarker.ESPWidgetPtrs[ptr]
      if not (Slot and slua.isValid(Slot)) or type(Slot) == "boolean" then
        local addedSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Container)
        if addedSlot and slua.isValid(addedSlot) then
          Slot = addedSlot
          PlayerMapMarker.ESPWidgetPtrs[ptr] = addedSlot
          if type(Widget) == "table" then
            Widget.Slot = addedSlot
          end
          pcall(function()
            Slot:SetAutoSize(true)
          end)
          pcall(function()
            Slot.bAutoSize = true
          end)
          local align = FVector2D and FVector2D(0.5, 1.0) or {X = 0.5, Y = 1.0}
          pcall(function()
            Slot.Alignment = align
          end)
          pcall(function()
            Slot:SetAlignment(align)
          end)
          pcall(function()
            Slot:SetAlignment(0.5, 1.0)
          end)
          pcall(function()
            Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 20)
          end)
        end
      end
      local bShowAnyUI = _G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP or _G.LexusConfig.Esp9_Team or _G.LexusConfig.Esp9_Weapon
      if bShowAnyUI then
        Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      else
        Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      end
      if not Widget._OffsetResetDone then
        pcall(function()
          Container:SetRenderTranslation(FVector2D and FVector2D(0.0, 0.0) or {X = 0, Y = 0})
        end)
        pcall(function()
          Container:SetRenderScale(FVector2D and FVector2D(0.9, 0.9) or {X = 0.9, Y = 0.9})
        end)
        if Widget and type(Widget) == "table" then
          if Widget.NameText and slua.isValid(Widget.NameText) then
            pcall(function()
              Widget.NameText:SetRenderTranslation(FVector2D and FVector2D(0.0, 0.0) or {X = 0, Y = 0})
            end)
          end
          if Widget.HealthFill and slua.isValid(Widget.HealthFill) then
            pcall(function()
              Widget.HealthFill:SetRenderTranslation(FVector2D and FVector2D(0.0, 0.0) or {X = 0, Y = 0})
            end)
          end
        end
        pcall(function()
          Container.RenderTransformPivot = FVector2D and FVector2D(0.5, 1.0) or {X = 0.5, Y = 1.0}
        end)
        pcall(function()
          Container:SetRenderTransformPivot(FVector2D and FVector2D(0.5, 1.0) or {X = 0.5, Y = 1.0})
        end)
        Widget._OffsetResetDone = true
      end
      if not (Slot and slua.isValid(Slot)) or Slot == PlayerMapMarker.ESPCanvas then
        if Widget and type(Widget) == "table" and Widget.Slot and slua.isValid(Widget.Slot) then
          Slot = Widget.Slot
        elseif Container.Slot and slua.isValid(Container.Slot) then
          Slot = Container.Slot
        end
      end
      if Slot and slua.isValid(Slot) and Slot ~= PlayerMapMarker.ESPCanvas then
        do
          local finalX = CanvasPos.X + (PlayerMapMarker.ESPAnchorOffsetX or 0)
          local finalY = CanvasPos.Y + (PlayerMapMarker.ESPAnchorOffsetY or 0)
          if Widget and type(Widget) == "table" then
            if not Widget._CachedPosVec then
              Widget._CachedPosVec = FVector2D and FVector2D(finalX, finalY) or {X = finalX, Y = finalY}
            else
              Widget._CachedPosVec.X = finalX
              Widget._CachedPosVec.Y = finalY
            end
            pcall(function()
              Slot:SetPosition(Widget._CachedPosVec)
            end)
          else
            pcall(function()
              Slot:SetPosition(FVector2D and FVector2D(finalX, finalY) or {X = finalX, Y = finalY})
            end)
          end
        end
      end
    end
  end)
  return true
end

function PlayerMapMarker.UpdateESPText(Widget, Text)
  if not Widget then
    return
  end
  if Widget._LastESPText == Text then
    return
  end
  Widget._LastESPText = Text
  
  local function applyTextAndCenter(w, txt)
    if not w or not slua.isValid(w) then
      return
    end
    if txt == "" then
      pcall(function()
        w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      end)
      return
    else
      pcall(function()
        w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    end
    pcall(function()
      w:SetText(txt)
    end)
    pcall(function()
      local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
      local orangeColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or {
        R = 255,
        G = 255,
        B = 255,
        A = 255
      }
      if w.SetColorAndOpacity then
        if FSlateColor then
          w:SetColorAndOpacity(FSlateColor(orangeColor))
        else
          w:SetColorAndOpacity(orangeColor)
        end
      end
    end)
    pcall(function()
      if w.SetJustification then
        w:SetJustification(1)
      end
    end)
    pcall(function()
      local slot = w.Slot
      if slot and slot.SetHorizontalAlignment then
        slot:SetHorizontalAlignment(1)
      end
    end)
    pcall(function()
      w:SetRenderTranslation(FVector2D and FVector2D(PlayerMapMarker.ESPTextOffsetX or 0, PlayerMapMarker.ESPTextOffsetY or 0) or {
        X = PlayerMapMarker.ESPTextOffsetX or 0,
        Y = PlayerMapMarker.ESPTextOffsetY or 0
      })
    end)
  end
  
  if Widget.NameText and slua.isValid(Widget.NameText) then
    applyTextAndCenter(Widget.NameText, Text)
  end
  if Widget.IsGameWidget and Widget.Container then
    pcall(function()
      local W = Widget.Container
      if W and slua.isValid(W) then
        if W.SetPlayerName then
          local Name = Text
          local idx = string.find(Text, " %[")
          if idx then
            Name = string.sub(Text, 1, idx - 1)
          end
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
                if child and slua.isValid(child) and child.SetText then
                  table.insert(list, child)
                end
              end
            end
            Widget._CachedVBChildren = list
          end
          for _, child in ipairs(Widget._CachedVBChildren) do
            applyTextAndCenter(child, Text)
          end
        end)
        pcall(function()
          if not Widget._CachedHBChildren then
            local list = {}
            local HB = PlayerMapMarker._FindNamedWidgetInTree(W, "HorizontalBox_TeamName", 8)
            if HB and slua.isValid(HB) and HB.GetChildrenCount then
              local nChildren = HB:GetChildrenCount()
              for i = 0, nChildren - 1 do
                local child = HB:GetChildAt(i)
                if child and slua.isValid(child) and child.SetText then
                  table.insert(list, child)
                end
              end
            end
            Widget._CachedHBChildren = list
          end
          for _, child in ipairs(Widget._CachedHBChildren) do
            applyTextAndCenter(child, Text)
          end
        end)
      end
    end)
  end
end

function PlayerMapMarker.UpdateESPHealth(Widget, pct)
  if not Widget then
    return
  end
  Widget.LastPct = pct
  local bShowHP = _G.LexusConfig.Esp9_HP
  if PlayerMapMarker.bForceSwitcherIndexEveryUpdate and Widget.Container then
    pcall(function()
      local W = Widget.Container
      if W and slua.isValid(W) then
        if W.WidgetSwitcher_Type and slua.isValid(W.WidgetSwitcher_Type) then
          pcall(function()
            if W.WidgetSwitcher_Type.SetActiveWidgetIndex then
              W.WidgetSwitcher_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex)
            end
          end)
        end
        if W.WidgetSwitcher_Type2 and slua.isValid(W.WidgetSwitcher_Type2) then
          pcall(function()
            if W.WidgetSwitcher_Type2.SetActiveWidgetIndex then
              W.WidgetSwitcher_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index)
            end
          end)
        end
        if W.SizeBox_HP and slua.isValid(W.SizeBox_HP) then
          if bShowHP then
            W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
          else
            W.SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
          end
        end
      end
    end)
  end
  if not bShowHP then
    return
  end
  if Widget.HealthFill then
    local bValid = false
    pcall(function()
      bValid = slua.isValid(Widget.HealthFill)
    end)
    if bValid then
      local bHasSetPercent = false
      pcall(function()
        bHasSetPercent = Widget.HealthFill.SetPercent ~= nil
      end)
      if not bHasSetPercent then
        local PB = PlayerMapMarker.FindProgressBarInWidget(Widget.HealthFill, 0, 5)
        if PB and slua.isValid(PB) then
          Widget.HealthFill = PB
        else
          return
        end
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
          local color
          if 0.5 < pct then
            color = FLinearColor and FLinearColor(0.0, 1.0, 0.0, 1.0) or {
              R = 0,
              G = 255,
              B = 0,
              A = 255
            }
          elseif 0.25 < pct then
            color = FLinearColor and FLinearColor(1.0, 0.5, 0.0, 1.0) or {
              R = 255,
              G = 128,
              B = 0,
              A = 255
            }
          else
            color = FLinearColor and FLinearColor(1.0, 0.0, 0.0, 1.0) or {
              R = 255,
              G = 0,
              B = 0,
              A = 255
            }
          end
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
    return
  end
end

function PlayerMapMarker.RemoveESPWidget(Widget, KeyStr)
  if not Widget then
    return
  end
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
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return nil
  end
  local Border
  pcall(function()
    Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas)
  end)
  if not Border or not slua.isValid(Border) then
    return nil
  end
  local color = PlayerMapMarker.SnapLineColor or FLinearColor and FLinearColor(1.0, 1.0, 1.0, PlayerMapMarker.SnapLineOpacity or 0.7) or {
    R = 1,
    G = 1,
    B = 1,
    A = PlayerMapMarker.SnapLineOpacity or 0.7
  }
  pcall(function()
    Border:SetBrushColor(color)
  end)
  pcall(function()
    Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  pcall(function()
    Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X = 0, Y = 0.5}
  end)
  pcall(function()
    Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X = 0, Y = 0.5})
  end)
  local Slot
  pcall(function()
    Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
    if Slot then
      Slot:SetAutoSize(false)
      Slot:SetZOrder(1)
    end
  end)
  return {Widget = Border, Slot = Slot}
end

function PlayerMapMarker.GetSnapLineStartPos(PC)
  local screenPixelW, screenPixelH = 0, 0
  local scale = 1.0
  pcall(function()
    if PC and PC.GetViewportSize then
      local vs = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
      PC:GetViewportSize(vs)
      if vs and vs.X and vs.X > 200 then
        screenPixelW = vs.X
        screenPixelH = vs.Y
      end
    end
  end)
  if screenPixelW <= 200 then
    pcall(function()
      local WLL = WidgetLayoutLibrary
      if WLL and WLL.GetViewportSize then
        local vs = WLL.GetViewportSize(PC)
        if vs and vs.X and vs.X > 200 then
          screenPixelW = vs.X
          screenPixelH = vs.Y
        end
      end
    end)
  end
  pcall(function()
    local WLL = WidgetLayoutLibrary
    if WLL and WLL.GetViewportScale then
      local s = WLL.GetViewportScale(PC)
      if s and type(s) == "number" and 0 < s then
        scale = s
      end
    end
  end)
  if screenPixelW <= 200 then
    screenPixelW = (PlayerMapMarker._cachedViewportW or 1920) * scale
    screenPixelH = (PlayerMapMarker._cachedViewportH or 1080) * scale
  end
  if not PlayerMapMarker._CachedTopCenterPixel then
    PlayerMapMarker._CachedTopCenterPixel = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
  end
  PlayerMapMarker._CachedTopCenterPixel.X = screenPixelW / 2.0
  PlayerMapMarker._CachedTopCenterPixel.Y = (PlayerMapMarker.SnapLineOriginY or 50) * scale
  local fromCanvasPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
  local fromX = fromCanvasPos.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0)
  local fromY = fromCanvasPos.Y
  return fromX, fromY
end

function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
  if not PlayerMapMarker.bUseSnapLines then
    return
  end
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return
  end
  local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
  if not bOnScreen or not CanvasPos then
    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
      pcall(function()
        LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      end)
    end
    return
  end
  local bIsNew = false
  if not LineData then
    LineData = PlayerMapMarker.CreateSnapLine()
    if not (LineData and LineData.Widget) or not LineData.Slot then
      return
    end
    PlayerMapMarker.SnapLineWidgets[KeyStr] = LineData
    bIsNew = true
  end
  local Widget = LineData.Widget
  local Slot = LineData.Slot
  pcall(function()
    Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end)
  if not LineData._PivotSet then
    pcall(function()
      Widget.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X = 0, Y = 0.5}
    end)
    pcall(function()
      Widget:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X = 0, Y = 0.5})
    end)
    LineData._PivotSet = true
  end
  local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
  local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)
  local dx = toX - fromX
  local dy = toY - fromY
  local length = math.sqrt(dx * dx + dy * dy)
  local thickness = PlayerMapMarker.SnapLineThickness or 1.5
  local angle_rad = 0
  if math.atan2 then
    angle_rad = math.atan2(dy, dx)
  else
    angle_rad = math.atan(dy, dx)
  end
  local angle = angle_rad * (180.0 / math.pi)
  if not LineData._CachedPosVec then
    LineData._CachedPosVec = FVector2D and FVector2D(fromX, fromY - thickness / 2.0) or {
      X = fromX,
      Y = fromY - thickness / 2.0
    }
    LineData._CachedSizeVec = FVector2D and FVector2D(length, thickness) or {X = length, Y = thickness}
  else
    LineData._CachedPosVec.X = fromX
    LineData._CachedPosVec.Y = fromY - thickness / 2.0
    LineData._CachedSizeVec.X = length
    LineData._CachedSizeVec.Y = thickness
  end
  pcall(function()
    Slot:SetPosition(LineData._CachedPosVec)
    Slot:SetSize(LineData._CachedSizeVec)
    if bIsNew then
      Slot:SetZOrder(1)
    end
  end)
  pcall(function()
    Widget:SetRenderAngle(angle)
  end)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
  local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
  if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
    pcall(function()
      LineData.Widget:RemoveFromParent()
      LineData.Widget:ConditionalBeginDestroy()
    end)
    PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
  end
end

function PlayerMapMarker.ClearAllSnapLines()
  for KeyStr, LineData in pairs(PlayerMapMarker.SnapLineWidgets) do
    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
      pcall(function()
        LineData.Widget:RemoveFromParent()
        LineData.Widget:ConditionalBeginDestroy()
      end)
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
  if not IsValid(PC) or not WorldLoc then
    return false, 0, 0
  end
  if not PlayerMapMarker._tempScreenPixelPos then
    PlayerMapMarker._tempScreenPixelPos = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0}
  end
  local tempPos = PlayerMapMarker._tempScreenPixelPos
  local bOK = false
  pcall(function()
    local res = PC:ProjectWorldLocationToScreen(WorldLoc, tempPos, true)
    if res == true or res == 1 then
      bOK = true
    end
  end)
  if not bOK or tempPos.X == 0 and tempPos.Y == 0 then
    return false, 0, 0
  end
  local canvasX, canvasY = PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, tempPos.X, tempPos.Y)
  return true, canvasX, canvasY
end

function PlayerMapMarker.GetBoneLocationWithFallback(Character, PrimaryBoneName)
  if not IsValid(Character) or not PrimaryBoneName then
    return nil
  end
  if Character._cachedBoneNames and Character._cachedBoneNames[PrimaryBoneName] then
    local cachedName = Character._cachedBoneNames[PrimaryBoneName]
    local loc
    pcall(function()
      local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
      if Mesh and Game:IsValid(Mesh) then
        if Mesh.GetSocketLocation then
          loc = Mesh:GetSocketLocation(cachedName)
        elseif Mesh.GetBoneLocation then
          loc = Mesh:GetBoneLocation(cachedName)
        end
      end
    end)
    if loc then
      return loc
    end
  end
  local fallbacks = PlayerMapMarker.BoneNameFallbacks[PrimaryBoneName] or {PrimaryBoneName}
  for _, bname in ipairs(fallbacks) do
    local loc
    pcall(function()
      local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
      if Mesh and Game:IsValid(Mesh) then
        if Mesh.GetSocketLocation then
          loc = Mesh:GetSocketLocation(bname)
        elseif Mesh.GetBoneLocation then
          loc = Mesh:GetBoneLocation(bname)
        end
      end
    end)
    if loc then
      if not Character._cachedBoneNames then
        Character._cachedBoneNames = {}
      end
      Character._cachedBoneNames[PrimaryBoneName] = bname
      return loc
    end
  end
  return nil
end

function PlayerMapMarker.IsPlayerVisible(PC, Character)
  if not IsValid(PC) or not IsValid(Character) then
    return false
  end
  local now = os.clock()
  if Character._lastVisTime and now - Character._lastVisTime < 0.15 then
    return Character._cachedIsVisible or false
  end
  Character._lastVisTime = now
  local bVis = false
  pcall(function()
    if PC.LineOfSightTo then
      if not PlayerMapMarker._ZeroVector then
        local VT = FVector or import("/Script/CoreUObject.Vector")
        if VT then
          PlayerMapMarker._ZeroVector = VT(0, 0, 0)
        end
      end
      bVis = PC:LineOfSightTo(Character, PlayerMapMarker._ZeroVector, false)
    end
  end)
  if not bVis then
    local KismetSystemLibrary = import("KismetSystemLibrary")
    if KismetSystemLibrary and KismetSystemLibrary.LineTraceSingle then
      pcall(function()
        local camMgr
        local GameplayStatics = import("GameplayStatics")
        if GameplayStatics and GameplayStatics.GetPlayerCameraManager then
          camMgr = GameplayStatics.GetPlayerCameraManager(PC, 0)
        end
        local startLoc = camMgr and camMgr:GetCameraLocation() or PlayerMapMarker.GetMyLocation()
        local headLoc = PlayerMapMarker.GetBoneLocationWithFallback(Character, "head")
        if startLoc and headLoc then
          if not PlayerMapMarker._CachedHitResult then
            local HitResultClass = import("HitResult") or import("/Script/Engine.HitResult")
            PlayerMapMarker._CachedHitResult = HitResultClass and HitResultClass() or {}
          end
          local bHit = KismetSystemLibrary.LineTraceSingle(PC, startLoc, headLoc, 0, false, nil, 0, PlayerMapMarker._CachedHitResult, true)
          if bHit then
            local hitActor
            if type(PlayerMapMarker._CachedHitResult.GetActor) == "function" then
              hitActor = PlayerMapMarker._CachedHitResult:GetActor()
            elseif PlayerMapMarker._CachedHitResult.Actor then
              hitActor = PlayerMapMarker._CachedHitResult.Actor
            end
            if hitActor and (hitActor == Character or type(hitActor.IsChildOf) == "function" and hitActor:IsChildOf(Character)) then
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
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return nil
  end
  local Border
  pcall(function()
    Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas)
  end)
  if not Border or not slua.isValid(Border) then
    return nil
  end
  pcall(function()
    Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X = 0, Y = 0.5}
  end)
  pcall(function()
    Border:SetRenderTransformPivot(FVector2D and FVector2D(0.0, 0.5) or {X = 0, Y = 0.5})
  end)
  local Slot
  pcall(function()
    Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
    if Slot then
      Slot:SetAutoSize(false)
      Slot:SetZOrder(5)
    end
  end)
  return {
    Widget = Border,
    Slot = Slot,
    posVec = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0},
    sizeVec = FVector2D and FVector2D(0, 0) or {X = 0, Y = 0},
    lastFromX = -99999,
    lastFromY = -99999,
    lastToX = -99999,
    lastToY = -99999
  }
end

function PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, bVisible, TeamColor, bPlayerOnScreen, charLoc)
  if not PlayerMapMarker.bUseSkeleton then
    return
  end
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return
  end
  local PlayerBones = PlayerMapMarker.SkeletonWidgets[KeyStr]
  if not (bVisible and IsValid(Character)) or not IsValid(PC) then
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
  charLoc = charLoc or PlayerMapMarker.GetESPLocation(Character)
  if not charLoc then
    return
  end
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
    dist = math.sqrt(dx * dx + dy * dy + dz * dz)
  end
  if PlayerMapMarker.SkeletonMaxDistance and 0 < PlayerMapMarker.SkeletonMaxDistance and dist > PlayerMapMarker.SkeletonMaxDistance then
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
  if not PlayerBones then
    PlayerBones = {}
    PlayerMapMarker.SkeletonWidgets[KeyStr] = PlayerBones
  end
  local lineColor
  if PlayerMapMarker.bUseVisibilityColor then
    local bTargetVisible = PlayerMapMarker.IsPlayerVisible(PC, Character)
    if bTargetVisible then
      lineColor = PlayerMapMarker.SkeletonVisibleColor or FLinearColor(0.0, 1.0, 0.0, 0.8)
    else
      lineColor = PlayerMapMarker.SkeletonCoverColor or FLinearColor(0.9, 0.0, 0.0, 0.6)
    end
  else
    lineColor = PlayerMapMarker.SkeletonColor or TeamColor or FLinearColor(1.0, 1.0, 1.0, PlayerMapMarker.SkeletonOpacity or 0.8)
  end
  local cache = PlayerMapMarker._StaticBoneLocCache
  for k in pairs(cache) do
    cache[k] = nil
  end
  local lineIndex = 0
  local thickness = PlayerMapMarker.SkeletonThickness or 1.2
  if not Character._cachedBones3D then
    Character._cachedBones3D = {}
  end
  for _, chain in ipairs(PlayerMapMarker.SkeletonChains) do
    local lastCanvasX, lastCanvasY
    for _, boneName in ipairs(chain) do
      local boneWorldLoc = cache[boneName]
      if boneWorldLoc == nil then
        boneWorldLoc = PlayerMapMarker.GetBoneLocationWithFallback(Character, boneName) or false
        cache[boneName] = boneWorldLoc
      end
      if boneWorldLoc == false then
        boneWorldLoc = nil
      end
      local currentCanvasX, currentCanvasY
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
        if not (LineData and LineData.Widget) or not slua.isValid(LineData.Widget) then
          LineData = PlayerMapMarker.CreateSkeletonLineWidget()
          if LineData then
            PlayerBones[lineIndex] = LineData
          end
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
          if 8000 < dist then
            threshold = 0.8
          elseif 4000 < dist then
            threshold = 0.4
          end
          if threshold < math.abs(fromX - LineData.lastFromX) or threshold < math.abs(fromY - LineData.lastFromY) or threshold < math.abs(toX - LineData.lastToX) or threshold < math.abs(toY - LineData.lastToY) then
            LineData.lastFromX = fromX
            LineData.lastFromY = fromY
            LineData.lastToX = toX
            LineData.lastToY = toY
            local dx = toX - fromX
            local dy = toY - fromY
            local length = math.sqrt(dx * dx + dy * dy)
            local angle_rad = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
            local angle = angle_rad * 57.29577951308232
            local pVec = LineData.posVec
            pVec.X = fromX
            pVec.Y = fromY - thickness / 2.0
            Slot:SetPosition(pVec)
            local sVec = LineData.sizeVec
            sVec.X = length
            sVec.Y = thickness
            Slot:SetSize(sVec)
            Widget:SetRenderAngle(angle)
          end
        end
      end
      lastCanvasX = currentCanvasX
      lastCanvasY = currentCanvasY
    end
  end
  for i = lineIndex + 1, {} do
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
        if child and slua.isValid(child) and PlayerMapMarker.IsOurESPWidget(child) then
          PlayerMapMarker.ESPCanvas:RemoveChild(child)
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
  if not PlayerMapMarker.bUseScreenESP then
    return
  end
  PlayerMapMarker.bUseSnapLines = _G.LexusConfig.Esp9_Line
  PlayerMapMarker.bUseSkeleton = _G.LexusConfig.Esp9_Skeleton
  if not PlayerMapMarker.InitESPCanvas() then
    return
  end
  if PlayerMapMarker._OBHeadWidgetLoadFailed then
    return
  end
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
  local MyChar
  pcall(function()
    local GDP = PlayerMapMarker.GetGameplayData()
    if GDP and GDP.GetLocalCharacter then
      MyChar = GDP.GetLocalCharacter()
    elseif PC and PC.GetPawn then
      MyChar = PC:GetPawn()
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
      if bIsMe and not PlayerMapMarker.bIncludeMe then
        bSkip = true
      end
      if bIsAI and not PlayerMapMarker.bIncludeAI then
        bSkip = true
      end
      local TeamID = PlayerMapMarker.GetTeamID(Character)
      if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then
        bSkip = true
      end
      local bIsAlive = PlayerMapMarker.IsAlive(Character)
      if not bSkip and Loc then
        SeenKeys[KeyStr] = true
        local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]
        local Text = ""
        if _G.LexusConfig.Esp9_Name then
          Text = Name
        end
        if _G.LexusConfig.Esp9_Distance and DistStr and DistStr ~= "" then
          if Text ~= "" then
            Text = string.format("%s [%s]", Text, DistStr)
          else
            Text = string.format("[%s]", DistStr)
          end
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
              TeamID = TeamID
            }
            PlayerMapMarker.UpdateESPText(Widget, Text)
            if bIsAlive then
              PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
              PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
              local HP = Character.Health or 0
              local MaxHP = Character.MaxHealth or 120
              local pct = 0
              if 0 < HP and 0 < MaxHP then
                pct = HP / MaxHP
                if 1 < pct then
                  pct = 1
                end
                if pct < 0 then
                  pct = 0
                end
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
              pcall(function()
                Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
              end)
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
            if 0 < HP and 0 < MaxHP then
              pct = HP / MaxHP
              if 1 < pct then
                pct = 1
              end
              if pct < 0 then
                pct = 0
              end
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
            pcall(function()
              Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end)
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
  if RedBoxOverlay and RedBoxOverlay.bActive then
    RedBoxOverlay.UpdatePosition()
  end
  if not PlayerMapMarker.bUseScreenESP then
    return
  end
  PlayerMapMarker.bUseSnapLines = _G.LexusConfig.Esp9_Line
  PlayerMapMarker.bUseSkeleton = _G.LexusConfig.Esp9_Skeleton
  if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then
    return
  end
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not IsValid(PC) then
    return
  end
  PlayerMapMarker.UpdateCanvasTransform(PC)
  local fromX, fromY = 0, 0
  if PlayerMapMarker.bUseSnapLines then
    fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
  end
  for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
    local Widget = ESPData.Widget
    local Character = ESPData.Character
    local Container = Widget and (Widget.Container or Widget)
    local bWidgetValid = false
    pcall(function()
      bWidgetValid = Container and slua.isValid(Container)
    end)
    if Widget and bWidgetValid and Character and IsValid(Character) then
      do
        local bIsAlive = PlayerMapMarker.IsAlive(Character)
        if not bIsAlive then
          pcall(function()
            Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
          end)
          PlayerMapMarker.RemoveSnapLine(KeyStr)
          PlayerMapMarker.RemoveSkeletonLines(KeyStr)
        else
          local bShowAnyUI = _G.LexusConfig.Esp9_Name or _G.LexusConfig.Esp9_Distance or _G.LexusConfig.Esp9_HP or _G.LexusConfig.Esp9_Team or _G.LexusConfig.Esp9_Weapon
          if bShowAnyUI then
            pcall(function()
              Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
          else
            pcall(function()
              Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end)
          end
          pcall(function()
            Container:SetRenderOpacity(1.0)
          end)
          local Loc = PlayerMapMarker.GetESPLocation(Character)
          if Loc then
            local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
            PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
            if PlayerMapMarker.bUseSnapLines then
              PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
            else
              PlayerMapMarker.RemoveSnapLine(KeyStr)
            end
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
end

function PlayerMapMarker.UpdateESPDistances()
  if not PlayerMapMarker.bUseScreenESP then
    return
  end
  local MyLoc = PlayerMapMarker.GetMyLocation()
  if not MyLoc then
    return
  end
  local PC = PlayerMapMarker.GetMyPlayerController()
  if not IsValid(PC) then
    return
  end
  PlayerMapMarker.UpdateCanvasTransform(PC)
  for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
    local Character = ESPData.Character
    local Widget = ESPData.Widget
    local Container = Widget and (Widget.Container or Widget)
    local bWidgetValid = false
    pcall(function()
      bWidgetValid = Container and slua.isValid(Container)
    end)
    if Character and IsValid(Character) and Widget and bWidgetValid then
      do
        local Loc = PlayerMapMarker.GetESPLocation(Character)
        if Loc then
          local Dist = PlayerMapMarker.CalcDistance(MyLoc, Loc)
          ESPData.LastDistance = Dist
          if PlayerMapMarker.bShowDistance then
            local DistStr = ""
            local Meters = 0
            if Dist then
              Meters = Dist / 100
              if Meters < 1000 then
                DistStr = string.format("%dm", math.floor(Meters))
              else
                DistStr = string.format("%.1fkm", Meters / 1000)
              end
            end
            local Name = ESPData.Name or "Unknown"
            local Text = ""
            if _G.LexusConfig.Esp9_Name then
              Text = Name
            end
            if _G.LexusConfig.Esp9_Distance and DistStr and DistStr ~= "" then
              if Text ~= "" then
                Text = string.format("%s [%s]", Text, DistStr)
              else
                Text = string.format("[%s]", DistStr)
              end
            end
            ESPData.LastDistStr = DistStr
            Widget._LastESPText = nil
            PlayerMapMarker.UpdateESPText(Widget, Text)
          end
        end
      end
    end
  end
end

function PlayerMapMarker.ScanAndUpdate()
  local AllChars = PlayerMapMarker.GetAllCharacters()
  if not AllChars then
    RedBoxOverlay.SetCounts(0, 0)
    return 0
  end
  local MyKey = PlayerMapMarker.GetMyPlayerKey()
  local MyLoc = PlayerMapMarker.GetMyLocation()
  local MyChar
  pcall(function()
    local GDP = PlayerMapMarker.GetGameplayData()
    if GDP and GDP.GetLocalCharacter then
      MyChar = GDP.GetLocalCharacter()
    else
      local PC = PlayerMapMarker.GetMyPlayerController()
      if PC and PC.GetPawn then
        MyChar = PC:GetPawn()
      end
    end
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
          if targetTeamID == MyTeamID then
            bIsMyTeam = true
          end
        end
        if not bIsMyTeam then
          if bIsAI then
            botPlayers = botPlayers + 1
          else
            realPlayers = realPlayers + 1
          end
        end
      end
    end
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
      local now = os.time()
      if PlayerMapMarker._AttachPending and PlayerMapMarker._AttachPendingTime and now - PlayerMapMarker._AttachPendingTime < 2 then
        return
      end
      PlayerMapMarker._AttachPending = true
      PlayerMapMarker._AttachPendingTime = now
      pcall(function()
        require("timer").SetGameTimer(1.0, false, function()
          PlayerMapMarker._AttachPending = nil
          PlayerMapMarker._AttachPendingTime = nil
          PlayerMapMarker.AttachTimers()
        end)
      end)
      return
    end
    PlayerMapMarker._AttachPending = nil
    PlayerMapMarker._AttachPendingTime = nil
    local now = os.time()
    local lastPC = PlayerMapMarker._ActiveTimerPC
    local lastTick = PlayerMapMarker._ActiveTimerTick
    if lastPC and slua.isValid(lastPC) and lastPC == pc and lastTick and now - lastTick < 5 then
      return
    end
    PlayerMapMarker._ActiveTimerPC = pc
    PlayerMapMarker._ActiveTimerTick = now
    pcall(function()
      pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.5, true, function()
        PlayerMapMarker._ActiveTimerTick = os.time()
        if PlayerMapMarker.bActive then
          pcall(function()
            PlayerMapMarker.ScanAndUpdate()
          end)
        end
      end)
    end)
    pcall(function()
      pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.02, true, function()
        PlayerMapMarker._ActiveTimerTick = os.time()
        if PlayerMapMarker.bActive then
          pcall(function()
            PlayerMapMarker.UpdateESPLight()
          end)
        end
      end)
    end)
    pcall(function()
      pc:AddGameTimer(PlayerMapMarker._DistanceUpdateInterval or 0.1, true, function()
        PlayerMapMarker._ActiveTimerTick = os.time()
        if PlayerMapMarker.bActive and PlayerMapMarker.bUseScreenESP and PlayerMapMarker.bShowDistance then
          pcall(function()
            PlayerMapMarker.UpdateESPDistances()
          end)
        end
      end)
    end)
    pcall(function()
      require("timer").SetGameTimer(5.0, false, PlayerMapMarker.AttachTimers)
    end)
  end)
end

function PlayerMapMarker.Start()
  if PlayerMapMarker.bActive then
    return
  end
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
local _cachedGameplayData, _cachedTicker, _cachedSysLib
local _loopFrameCount = 0
local _slowTickCounter = 0

local function MainLoop()
  if isExpired then
    return
  end
  _loopFrameCount = _loopFrameCount + 1
  _slowTickCounter = _slowTickCounter + 1
  if not _cachedGameplayData then
    pcall(function()
      _cachedGameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    end)
  end
  if not _cachedTicker then
    pcall(function()
      _cachedTicker = require("common.time_ticker")
    end)
  end
  pcall(function()
    local SystemLib = _cachedSysLib or import("KismetSystemLibrary")
    if SystemLib then
      _cachedSysLib = SystemLib
    end
    if SystemLib and not _G.FakeHWID_Hooked then
      _G.Original_GetDeviceId = SystemLib.GetDeviceId
      
      function SystemLib.GetDeviceId(...)
        if _G.LexusConfig.FakeHWID then
          if not _G.FakeHWID_String then
            local chars = "0123456789abcdef"
            local hwid = ""
            for i = 1, 32 do
              hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16))
            end
            _G.FakeHWID_String = hwid
          end
          return _G.FakeHWID_String
        end
        if _G.Original_GetDeviceId then
          return _G.Original_GetDeviceId(...)
        end
        return "UNKNOWN"
      end
      
      _G.FakeHWID_Hooked = true
    end
  end)
  
  function _G.GetOriginalHWID()
    if _G.Original_GetDeviceId then
      return tostring(_G.Original_GetDeviceId())
    end
    local SystemLib = import("KismetSystemLibrary")
    if SystemLib and type(SystemLib.GetDeviceId) == "function" then
      return tostring(SystemLib.GetDeviceId())
    end
    return "UNKNOWN_DEVICE"
  end
  
  if _G.LexusState.CustomTextData == nil then
    _G.LexusState.CustomTextData = {}
  end
  local GameplayData = _cachedGameplayData
  if not GameplayData then
    local ok
    ok, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and GameplayData then
      _cachedGameplayData = GameplayData
    end
  end
  if not GameplayData then
    return
  end
  local pc = GameplayData.GetPlayerController()
  local localPlayer
  if Valid(pc) then
    localPlayer = pc:GetPlayerCharacterSafety()
  end
  if not Valid(localPlayer) then
    if _G.PlayerMapMarker and type(_G.PlayerMapMarker.Stop) == "function" then
      _G.PlayerMapMarker.Stop()
    end
    if _G.RedBoxOverlay and type(_G.RedBoxOverlay.Stop) == "function" then
      _G.RedBoxOverlay.Stop()
    end
    if _G.LexusState.TrackedMarks then
      for markId, _ in pairs(_G.LexusState.TrackedMarks) do
        SafeRemoveMark(markId)
      end
    end
    _G.LexusState.TrackedMarks = {}
    for key, data in pairs(_G.LexusState.EnemyMarks) do
      if data and data.MIDs then
        for meshStr, midTable in pairs(data.MIDs) do
          for k, _ in pairs(midTable) do
            midTable[k] = nil
          end
        end
        data.MIDs = nil
      end
      if data and data.MIDs_V3 then
        for meshStr, midTable in pairs(data.MIDs_V3) do
          for k, _ in pairs(midTable) do
            midTable[k] = nil
          end
        end
        data.MIDs_V3 = nil
      end
    end
    _G.LexusState.EnemyMarks = {}
    _G.LexusState.PrevGraphicsState = {}
    return
  end
  if not _G.LexusState.NativeESPReady then
    InitializeNativeESP()
  end
  if not _G.LexusState.MenuShown then
    ShowLexusVIPMenu()
  end
  if _G.LexusConfig.EspLoai9 then
    if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then
      _G.PlayerMapMarker.Start()
    end
  elseif _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then
    _G.PlayerMapMarker.Stop()
  end
  if _G.LexusConfig.UnlockFPS and not _G.LexusState.GraphicsUnlocked then
    InitializeGraphicsUnlock()
  end
  if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
    pcall(function()
      local targetTPP = _G.LexusState.CustomTextData.IpadViewFOV or 120
      local uTPPCam = localPlayer.ThirdPersonCameraComponent
      if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming and uTPPCam.FieldOfView ~= targetTPP then
        uTPPCam.FieldOfView = targetTPP
      end
    end)
  else
    pcall(function()
      local uTPPCam = localPlayer.ThirdPersonCameraComponent
      if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming and uTPPCam.FieldOfView ~= 80 then
        uTPPCam.FieldOfView = 80
      end
    end)
  end
  if _G.LexusConfig.ModSkin then
    if not _G.TDSkinLoopStarted then
      if _G.InitializeSkinModSystem then
        _G.InitializeSkinModSystem()
      end
      if _G.ForceRefreshSkinMaps then
        _G.ForceRefreshSkinMaps()
      end
      _G.TDSkinLoopStarted = true
    end
    _G.LexusState.SkinWasApplied = true
    local curTime = os.clock()
    if not _G.LastSkinUpdateTime or curTime - _G.LastSkinUpdateTime > 1.5 then
      _G.LastSkinUpdateTime = curTime
      pcall(function()
        local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
        if isAlive then
          if _G.ReadLiveConfig then
            _G.ReadLiveConfig()
          end
          if _G.equip_character_avatar then
            _G.equip_character_avatar(localPlayer)
          end
          if _G.ApplyWeaponSkins then
            _G.ApplyWeaponSkins(localPlayer)
          end
          if _G.ApplyVehicleSkins then
            _G.ApplyVehicleSkins(localPlayer)
          end
          if _G.HandlePetLogic then
            _G.HandlePetLogic()
          end
        end
      end)
    end
  else
    if _G.LexusState.SkinWasApplied then
      _G.OutfitMap = {}
      _G.WeaponSkinMap = {}
      _G.VehicleSkinMap = {}
      pcall(function()
        local WeaponManager = localPlayer:GetWeaponManager()
        if Valid(WeaponManager) then
          for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if Valid(Weapon) and Valid(Weapon.synData) then
              do
                local WeaponID = Weapon:GetWeaponID()
                local SkinData = Weapon.synData:Get(7)
                if SkinData and SkinData.defineID then
                  SkinData.defineID.TypeSpecificID = WeaponID
                  Weapon.synData:Set(7, SkinData)
                  if Weapon.SetWeaponAvatarID then
                    pcall(function()
                      Weapon:SetWeaponAvatarID(WeaponID)
                    end)
                  end
                  if Weapon.DelayHandleAvatarMeshChanged then
                    pcall(function()
                      Weapon:DelayHandleAvatarMeshChanged()
                    end)
                  end
                end
              end
            end
          end
        end
        local Vehicle = localPlayer:GetCurrentVehicle()
        if Valid(Vehicle) then
          local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
          if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
            local defId = VehicleAvatar:GetDefaultAvatarID()
            if VehicleAvatar.ChangeItemAvatar then
              VehicleAvatar:ChangeItemAvatar(defId, true)
            end
          end
        end
        if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
          localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
      end)
      _G.LexusState.SkinWasApplied = false
    end
    _G.TDSkinLoopStarted = false
  end
  if _G.LexusConfig.KillCounter and not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then
    _G.ForceEnableKillCounterUI()
  end
  if _G.LexusConfig.DeadBoxSkin and _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then
    _G.DeadBox_TemperRequest(pc)
  end
  pcall(function()
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
  pcall(function()
    local EAvatarDamagePosition = import("EAvatarDamagePosition")
    if not EAvatarDamagePosition then
      return
    end
    local modulesToHook = {
      "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
      "GameLua.Logic.Weapon.ShootWeaponEntity"
    }
    for _, path in ipairs(modulesToHook) do
      local hitLogic = package.loaded[path]
      if hitLogic then
        local original_GetHitBodyType = hitLogic.GetHitBodyType
        
        function hitLogic:GetHitBodyType(ImpactResult, InImpactVec)
          if _G.LexusConfig.AutoHead then
            return EAvatarDamagePosition.BigHead
          end
          if original_GetHitBodyType then
            return original_GetHitBodyType(self, ImpactResult, InImpactVec)
          end
        end
        
        local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
        
        function hitLogic:GetHitBodyTypeByHitPos(InImpactVec)
          if _G.LexusConfig.AutoHead then
            return EAvatarDamagePosition.BigHead
          end
          if original_GetHitBodyTypeByHitPos then
            return original_GetHitBodyTypeByHitPos(self, InImpactVec)
          end
        end
      end
    end
  end)
  pcall(function()
    local weapon
    pcall(function()
      local weaponManager = localPlayer.WeaponManagerComponent
      if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
        weapon = weaponManager:GetCurrentWeapon()
      end
    end)
    if not Valid(weapon) then
      if type(localPlayer.GetCurrentShootWeapon) == "function" then
        weapon = localPlayer:GetCurrentShootWeapon()
      elseif type(localPlayer.GetCurrentWeapon) == "function" then
        weapon = localPlayer:GetCurrentWeapon()
      end
    end
    if Valid(weapon) then
      local entities = {}
      if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then
        table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE)
      end
      if Valid(weapon.ShootWeaponEntity) then
        table.insert(entities, weapon.ShootWeaponEntity)
      end
      if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then
        table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent)
      end
      for _, entity in ipairs(entities) do
        local anyWeaponModOn = _G.LexusConfig.CustomHRecoil or _G.LexusConfig.CustomVRecoil or _G.LexusConfig.LessShake or _G.LexusConfig.Accuracy or _G.LexusConfig.Crosshair or _G.LexusConfig.GodMode or _G.LexusConfig.AutoHead or _G.LexusConfig.CustomAimbot or _G.LexusConfig.CustomAimbotClose
        if anyWeaponModOn then
          if not entity.OriginalStatsCached then
            entity.OriginalStatsCached = {
              GameDeviationFactor = entity.GameDeviationFactor,
              GameDeviationAccuracy = entity.GameDeviationAccuracy,
              BulletFireSpeed = entity.BulletFireSpeed,
              ShootInterval = entity.ShootInterval,
              BaseDamage = entity.BaseDamage,
              AccessoriesHRecoilFactor = entity.AccessoriesHRecoilFactor,
              AccessoriesVRecoilFactor = entity.AccessoriesVRecoilFactor,
              RecoilKick = entity.RecoilKick,
              RecoilKickADS = entity.RecoilKickADS,
              AnimationKick = entity.AnimationKick
            }
          end
          if _G.LexusConfig.Crosshair then
            entity.GameDeviationFactor = 0.0
          else
            entity.GameDeviationFactor = entity.OriginalStatsCached.GameDeviationFactor
          end
          if _G.LexusConfig.Accuracy then
            entity.GameDeviationAccuracy = 0.0
          else
            entity.GameDeviationAccuracy = entity.OriginalStatsCached.GameDeviationAccuracy
          end
          if _G.LexusConfig.CustomHRecoil then
            entity.AccessoriesHRecoilFactor = _G.LexusState.CustomTextData.HRecoil or 0.3
          elseif _G.LexusConfig.LessRecoil then
            entity.AccessoriesHRecoilFactor = 0.3
          end
          if _G.LexusConfig.CustomVRecoil then
            entity.AccessoriesVRecoilFactor = _G.LexusState.CustomTextData.VRecoil or 0.3
          elseif _G.LexusConfig.VerticalRecoil then
            entity.AccessoriesVRecoilFactor = 0.3
          end
          if _G.LexusConfig.LessShake then
            entity.RecoilKickADS = 0.0
            entity.RecoilKickADS = 0.0
            entity.RecoilKickADS = 0.0
          end
          if _G.LexusConfig.Accuracy then
            entity.GameDeviationAccuracy = 0.0
          end
          if _G.LexusConfig.Crosshair then
            entity.GameDeviationFactor = 0.0
          end
          if _G.LexusConfig.GodMode then
            entity.BulletFireSpeed = 500000.0
            entity.ShootInterval = 0.001
            entity.BaseDamage = 60000.0
          end
          if entity.AutoAimingConfig and not entity.OriginalAutoAimCached then
            entity.OriginalAutoAimCached = {
              OuterSpeed = entity.AutoAimingConfig.OuterRange and entity.AutoAimingConfig.OuterRange.Speed,
              InnerSpeed = entity.AutoAimingConfig.InnerRange and entity.AutoAimingConfig.InnerRange.Speed
            }
          end
          entity.GTLMODWeaponModsActive = true
        elseif entity.GTLMODWeaponModsActive then
          if entity.OriginalStatsCached then
            local orig = entity.OriginalStatsCached
            entity.GameDeviationFactor = orig.GameDeviationFactor
            entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
            entity.BulletFireSpeed = orig.BulletFireSpeed
            entity.ShootInterval = orig.ShootInterval
            entity.BaseDamage = orig.BaseDamage
            entity.AccessoriesHRecoilFactor = orig.AccessoriesHRecoilFactor
            entity.AccessoriesVRecoilFactor = orig.AccessoriesVRecoilFactor
            entity.RecoilKick = orig.RecoilKick
            entity.RecoilKickADS = orig.RecoilKickADS
            entity.AnimationKick = orig.AnimationKick
          end
          entity.GTLMODWeaponModsActive = false
        end
      end
    end
  end)
  local mHead_Global, mBody_Global, mLegs_Global = 1.0, 1.0, 1.0
  local runInject_Global = false
  pcall(function()
    if _G.LexusConfig.CustomMagicBullet then
      runInject_Global = true
      mHead_Global = 1.0
      mBody_Global = 1.0
      mLegs_Global = 1.0
      if _G.LexusState.CustomTextData then
        local cData = _G.LexusState.CustomTextData
        if cData.MagicHead ~= nil then
          mHead_Global = tonumber(cData.MagicHead) or mHead_Global
        end
        if cData.MagicBody ~= nil then
          mBody_Global = tonumber(cData.MagicBody) or mBody_Global
        end
        if cData.MagicLegs ~= nil then
          mLegs_Global = tonumber(cData.MagicLegs) or mLegs_Global
        end
      end
    end
    if runInject_Global then
      local currentMagicHash = "M_" .. tostring(mHead_Global) .. "_" .. tostring(mBody_Global) .. "_" .. tostring(mLegs_Global)
      if _G.LexusState.LastMagicConfigHash ~= currentMagicHash then
        _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
        _G.LexusState.LastMagicConfigHash = currentMagicHash
      end
    elseif _G.LexusState.LastMagicConfigHash ~= "OFF" then
      _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
      _G.LexusState.LastMagicConfigHash = "OFF"
    end
  end)
  pcall(function()
    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
      allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
      for _, char in pairs(GameplayData.GameCharacters) do
        table.insert(allCharacters, char)
      end
    end
    local currentValidKeys = {}
    for _, enemy in pairs(allCharacters) do
      if Valid(enemy) and enemy ~= localPlayer then
        currentValidKeys[GetSafeEnemyKey(enemy)] = true
      end
    end
    for key, data in pairs(_G.LexusState.EnemyMarks) do
      if not currentValidKeys[key] then
        SafeRemoveMark(data.radarMark)
        SafeRemoveMark(data.hpMark)
        SafeRemoveMark(data.distMark)
        if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then
          _G.AimTouchVisCache[key] = nil
        end
        if data.MIDs then
          for meshStr, midTable in pairs(data.MIDs) do
            for k, _ in pairs(midTable) do
              midTable[k] = nil
            end
          end
          data.MIDs = nil
        end
        if data.MIDs_V3 then
          for meshStr, midTable in pairs(data.MIDs_V3) do
            for k, _ in pairs(midTable) do
              midTable[k] = nil
            end
          end
          data.MIDs_V3 = nil
        end
        data.enemy = nil
        data.CachedMeshes = nil
        _G.LexusState.EnemyMarks[key] = nil
      end
    end
    local BoneScaleMap = {
      head = mHead_Global,
      neck_01 = mHead_Global,
      pelvis = mBody_Global,
      spine_01 = mBody_Global,
      spine_02 = mBody_Global,
      spine_03 = mBody_Global,
      thigh_l = mLegs_Global,
      thigh_r = mLegs_Global,
      calf_l = mLegs_Global,
      calf_r = mLegs_Global,
      foot_l = mLegs_Global,
      foot_r = mLegs_Global
    }
    local mLoc
    pcall(function()
      if type(localPlayer.K2_GetActorLocation) == "function" then
        mLoc = localPlayer:K2_GetActorLocation()
      end
    end)
    for _, enemy in pairs(allCharacters) do
      if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
        local bIsReallyDead = false
        pcall(function()
          if type(enemy.IsDead) == "function" then
            bIsReallyDead = enemy:IsDead()
          elseif enemy.bIsDead ~= nil then
            bIsReallyDead = enemy.bIsDead
          elseif enemy.bIsDeadFlag ~= nil then
            bIsReallyDead = enemy.bIsDeadFlag
          end
          if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then
            bIsReallyDead = true
          end
        end)
        local eKey = GetSafeEnemyKey(enemy)
        _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or {enemy = enemy}
        local markData = _G.LexusState.EnemyMarks[eKey]
        markData.enemy = enemy
        if not bIsReallyDead then
          if markData.lastEnemyActor ~= enemy then
            if markData.hpMark then
              SafeRemoveMark(markData.hpMark)
              markData.hpMark = nil
            end
            if markData.hpMark8 then
              SafeRemoveMark(markData.hpMark8)
              markData.hpMark8 = nil
            end
            if markData.distMark then
              SafeRemoveMark(markData.distMark)
              markData.distMark = nil
            end
            if markData.radarMark then
              SafeRemoveMark(markData.radarMark)
              markData.radarMark = nil
            end
            markData.lastEnemyActor = enemy
            markData.LastUIComp = nil
            markData.LastFrameUIState = nil
          end
          local eMesh
          pcall(function()
            eMesh = enemy.Mesh or type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil
          end)
          local aLoc
          pcall(function()
            if type(enemy.K2_GetActorLocation) == "function" then
              aLoc = enemy:K2_GetActorLocation()
            end
          end)
          local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
          local isBot = markData.AK_IS_BOT or false
          local currentMeshCount = 0
          if Valid(eMesh) then
            local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
            currentMeshCount = {}
          end
          local isMeshChanged = markData.LastMeshCountWall ~= currentMeshCount
          if _G.LexusConfig.WallXuyenTuong then
            if isMeshChanged or not markData.WallhackApplied then
              ApplyWallXuyenTuong(enemy, markData)
              markData.WallhackApplied = true
              markData.LastMeshCountWall = currentMeshCount
            end
          else
            UndoWallXuyenTuong(enemy, markData)
          end
          if _G.LexusConfig.ColorBodyV2 then
            ApplyColorBodyV2(enemy, pc, markData)
          else
            UndoColorBodyV2(enemy, markData)
          end
          if _G.LexusConfig.ColorBodyV3 then
            ApplyColorBodyV3(enemy, markData)
          else
            UndoColorBodyV3(enemy, markData)
          end
          if _G.LexusConfig.ColorBodyNew then
            ApplyColorBodyNew(enemy, markData)
          else
            UndoColorBodyNew(enemy, markData)
          end
          local WH2_READY = false
          local WH2_SEEN = {}
          local WH2_TICKS = 0
          local WH2_TMR
          local WH2_ITV = 0.3
          local WH2_SLOTS = {
            0,
            1,
            2,
            3,
            4,
            5,
            6,
            7
          }
          local LC = CACHED_LinearColor
          local WH2_VIS = LC and LC(0, 255, 0, 255) or {
            R = 0,
            G = 255,
            B = 0,
            A = 255
          }
          local WH2_OCC = LC and LC(255, 0, 0, 255) or {
            R = 255,
            G = 0,
            B = 0,
            A = 255
          }
          local WH2_BVIS = LC and LC(0, 180, 0, 200) or {
            R = 0,
            G = 180,
            B = 0,
            A = 200
          }
          local WH2_BOCC = LC and LC(180, 0, 0, 200) or {
            R = 180,
            G = 0,
            B = 0,
            A = 200
          }
          
          local function WH2_SetupConsole()
            if WH2_READY then
              return
            end
            pcall(function()
              local KSL = KismetSystemLibrary
              local world = slua.getWorld()
              if not KSL or not world then
                return
              end
              KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
              KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
              KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
              KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
              WH2_READY = true
            end)
          end
          
          local function WH2_ApplyMesh(mesh, vc, oc)
            if not mesh or not slua.isValid(mesh) then
              return
            end
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
          
          local function WH2_UndoMesh(mesh)
            if not mesh or not slua.isValid(mesh) then
              return
            end
            pcall(function()
              mesh:SetDrawDyeing(false)
              mesh:SetDrawHighlight(false)
              mesh:SetDrawIdeaOutline(false)
              mesh:SetRenderCustomDepth(false)
            end)
          end
          
          local function WH2_Tick()
            if not _G.LexusConfig or not _G.LexusConfig.WallhackV2 then
              if WH2_TMR then
                pcall(function()
                  if _G.Game then
                    _G.Game:RemoveGameTimer(WH2_TMR)
                  end
                end)
                WH2_TMR = nil
              end
              WH2_SEEN = {}
              WH2_TICKS = 0
              WH2_READY = false
              return
            end
            pcall(function()
              local gd = package.loaded["GameLua.GameCore.Data.GameplayData"] or GameplayData
              local lp = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
              if not Valid(lp) then
                return
              end
              WH2_SetupConsole()
              WH2_TICKS = WH2_TICKS + 1
              if WH2_TICKS % 6 == 0 then
                WH2_SEEN = {}
              end
              local myTeam = lp.TeamID or 0
              local pawns = {}
              if gd.GetAllPlayerCharacters then
                pawns = gd.GetAllPlayerCharacters() or {}
              elseif gd.GameCharacters then
                for _, c in pairs(gd.GameCharacters) do
                  table.insert(pawns, c)
                end
              end
              local n = 0
              for _, pawn in pairs(pawns) do
                if 20 <= n then
                  break
                end
                if Valid(pawn) and pawn ~= lp then
                  local pid = tostring(pawn.PlayerKey or pawn)
                  if not WH2_SEEN[pid] and (pawn.TeamID or 0) ~= myTeam and 0 < (pawn.Health or 100) then
                    local bot = false
                    pcall(function()
                      if pawn.bIsAI or pawn.AIData then
                        bot = true
                      end
                    end)
                    local vc = bot and WH2_BVIS or WH2_VIS
                    local oc = bot and WH2_BOCC or WH2_OCC
                    pcall(function()
                      if Valid(pawn.Mesh) then
                        WH2_ApplyMesh(pawn.Mesh, vc, oc)
                      end
                      local av = pawn.CharacterAvatarComp2_BP
                      if not av and type(pawn.getAvatarComponent2) == "function" then
                        av = pawn:getAvatarComponent2()
                      end
                      if av and av.GetMeshCompBySlot then
                        for _, s in ipairs(WH2_SLOTS) do
                          local m = av:GetMeshCompBySlot(s)
                          if Valid(m) then
                            WH2_ApplyMesh(m, vc, oc)
                          end
                        end
                      end
                      local w = type(pawn.GetCurrentWeapon) == "function" and pawn:GetCurrentWeapon()
                      if Valid(w) and Valid(w.Mesh) then
                        WH2_ApplyMesh(w.Mesh, vc, oc)
                      end
                    end)
                    WH2_SEEN[pid] = true
                    n = n + 1
                  end
                end
              end
            end)
          end
          
          local function WH2_Start()
            WH2_SetupConsole()
            if WH2_TMR then
              pcall(function()
                if _G.Game then
                  _G.Game:RemoveGameTimer(WH2_TMR)
                end
              end)
              WH2_TMR = nil
            end
            if _G.Game and type(_G.Game.AddGameTimer) == "function" then
              WH2_TMR = _G.Game:AddGameTimer(WH2_ITV, true, WH2_Tick)
              return
            end
            local ok, tk = pcall(require, "common.time_ticker")
            if ok and tk and tk.AddTimerOnce then
              local function loop()
                WH2_Tick()
                
                if _G.LexusConfig and _G.LexusConfig.WallhackV2 then
                  tk.AddTimerOnce(WH2_ITV, loop)
                end
              end
              
              tk.AddTimerOnce(WH2_ITV, loop)
            end
          end
          
          _G.StartWallhackV2 = WH2_Start
          pcall(function()
            if Valid(eMesh) then
              local targetScale = 1.0
              if _G.LexusConfig.BugManEnable and _G.LexusState.CustomTextData then
                targetScale = 177.0 / (_G.LexusState.CustomTextData.BugManRatio or 133)
                if targetScale < 1.0 then
                  targetScale = 1.0
                end
                if 2.0 < targetScale then
                  targetScale = 2.0
                end
              end
              if markData.LastFatScale ~= targetScale then
                eMesh:SetRelativeScale3D(FVector(targetScale, targetScale, 1.0))
                markData.LastFatScale = targetScale
              end
            end
          end)
          pcall(function()
            local EnemyMesh = eMesh
            if slua.isValid(EnemyMesh) then
              local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
              if markData.MagicBulletHash == _G.LexusState.LastMagicConfigHash and markData.MagicTargetID == uniqueID then
                return
              end
              local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
              if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then
                PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset
              end
              if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                if not _G.AK_ModdedPhysAssets then
                  _G.AK_ModdedPhysAssets = {}
                end
                do
                  local PhysAssetName = "DefaultPhys"
                  pcall(function()
                    PhysAssetName = PhysicsAsset:GetName()
                  end)
                  if _G.AK_ModdedPhysAssets[PhysAssetName] ~= _G.LexusState.LastMagicConfigHash then
                    if not _G.AK_OrigHitboxes then
                      _G.AK_OrigHitboxes = {}
                    end
                    if not _G.AK_OrigHitboxes[PhysAssetName] then
                      _G.AK_OrigHitboxes[PhysAssetName] = {}
                    end
                    local OrigHitboxData = _G.AK_OrigHitboxes[PhysAssetName]
                    local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                    local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or {}
                    local limit = 50 < numSetups and 50 or numSetups
                    for i = 1, limit do
                      local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i - 1) or SkeletalBodySetups[i]
                      if slua.isValid(BodySetup) then
                        local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                        local MatchedBoneKey
                        for k, _ in pairs(BoneScaleMap) do
                          if string.find(LowerBoneName, k, 1, true) then
                            MatchedBoneKey = k
                            break
                          end
                        end
                        if MatchedBoneKey then
                          local TargetScale = 1.0
                          if runInject_Global then
                            TargetScale = BoneScaleMap[MatchedBoneKey]
                          end
                          local AggGeom = BodySetup.AggGeom
                          local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                          local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                          local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems
                          local BoxElem = GetFirstElemSafe(BoxElems)
                          local SphereElem = GetFirstElemSafe(SphereElems)
                          local SphylElem = GetFirstElemSafe(SphylElems)
                          if not OrigHitboxData[MatchedBoneKey] then
                            OrigHitboxData[MatchedBoneKey] = {
                              Box = nil,
                              Sphere = nil,
                              Sphyl = nil
                            }
                            if BoxElem then
                              OrigHitboxData[MatchedBoneKey].Box = {
                                X = BoxElem.X,
                                Y = BoxElem.Y,
                                Z = BoxElem.Z
                              }
                            end
                            if SphereElem then
                              OrigHitboxData[MatchedBoneKey].Sphere = {
                                Radius = SphereElem.Radius
                              }
                            end
                            if SphylElem then
                              OrigHitboxData[MatchedBoneKey].Sphyl = {
                                Radius = SphylElem.Radius,
                                Length = SphylElem.Length
                              }
                            end
                          end
                          local OrigElemData = OrigHitboxData[MatchedBoneKey]
                          if OrigElemData.Box and BoxElem then
                            BoxElem.X = OrigElemData.Box.X * TargetScale
                            BoxElem.Y = OrigElemData.Box.Y * TargetScale
                            BoxElem.Z = OrigElemData.Box.Z * TargetScale
                            if type(BoxElems.Set) == "function" then
                              BoxElems:Set(0, BoxElem)
                            else
                              BoxElems[1] = BoxElem
                            end
                            if AggGeom then
                              AggGeom.BoxElems = BoxElems
                              BodySetup.AggGeom = AggGeom
                            else
                              BodySetup.BoxElems = BoxElems
                            end
                          end
                          if OrigElemData.Sphere and SphereElem then
                            SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                            if type(SphereElems.Set) == "function" then
                              SphereElems:Set(0, SphereElem)
                            else
                              SphereElems[1] = SphereElem
                            end
                            if AggGeom then
                              AggGeom.SphereElems = SphereElems
                              BodySetup.AggGeom = AggGeom
                            else
                              BodySetup.SphereElems = SphereElems
                            end
                          end
                          if OrigElemData.Sphyl and SphylElem then
                            SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                            SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                            if type(SphylElems.Set) == "function" then
                              SphylElems:Set(0, SphylElem)
                            else
                              SphylElems[1] = SphylElem
                            end
                            if AggGeom then
                              AggGeom.SphylElems = SphylElems
                              BodySetup.AggGeom = AggGeom
                            else
                              BodySetup.SphylElems = SphylElems
                            end
                          end
                        end
                      end
                    end
                    _G.AK_ModdedPhysAssets[PhysAssetName] = _G.LexusState.LastMagicConfigHash
                  end
                  if EnemyMesh.SetPhysicsAsset then
                    EnemyMesh:SetPhysicsAsset(PhysicsAsset)
                  end
                  EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                  markData.MagicBulletHash = _G.LexusState.LastMagicConfigHash
                  markData.MagicTargetID = uniqueID
                end
              end
            end
          end)
          if _G.LexusConfig.EspAntenna then
            pcall(function()
              local MyHUD = pc and pc.MyHUD
              if Valid(MyHUD) and distM <= 400 then
                local loopCount = 8
                local zStep = 1000
                local baseZ = 105
                local topZ = baseZ + loopCount * zStep
                for i = 1, loopCount do
                  local zOffset = baseZ + i * zStep
                  MyHUD:AddDebugText("|", enemy, 0.06, {
                    X = 0,
                    Y = 0,
                    Z = zOffset
                  }, {
                    X = 0,
                    Y = 0,
                    Z = zOffset
                  }, {
                    R = 0,
                    G = 255,
                    B = 0,
                    A = 255
                  }, true, false, true, nil, 1.2, true)
                end
                MyHUD:AddDebugText("I", enemy, 0.06, {
                  X = 0,
                  Y = 0,
                  Z = topZ + 60
                }, {
                  X = 0,
                  Y = 0,
                  Z = topZ + 60
                }, {
                  R = 0,
                  G = 255,
                  B = 0,
                  A = 255
                }, true, false, true, nil, 1.5, true)
              end
            end)
          end
          if _G.LexusConfig.EspLoai6 then
            pcall(function()
              local curTime = os.clock()
              if markData.LastEsp6Time == nil or curTime - markData.LastEsp6Time >= 0.05 then
                markData.LastEsp6Time = curTime
                local MyHUD = pc and pc.MyHUD
                if Valid(MyHUD) and Valid(eMesh) and aLoc and distM <= 250 and type(eMesh.GetSocketLocation) == "function" then
                  for _, bName in ipairs(GLOBAL_BONE_LIST) do
                    if distM > 50 and bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01" then
                    else
                      local wLoc = eMesh:GetSocketLocation(bName)
                      if wLoc then
                        local offset = {
                          X = wLoc.X - aLoc.X,
                          Y = wLoc.Y - aLoc.Y,
                          Z = wLoc.Z - aLoc.Z
                        }
                        local mark = "\226\150\170"
                        local fixedSize = 0.25
                        local color = C_CYAN
                        if bName == "head" then
                          mark = "\226\151\143"
                          fixedSize = 0.45
                          color = C_RED
                        elseif bName == "pelvis" or bName == "neck_01" then
                          mark = "\226\150\170"
                          fixedSize = 0.35
                          color = C_YELLOW
                        end
                        MyHUD:AddDebugText(mark, enemy, 0.06, offset, offset, color, true, false, true, nil, fixedSize, true)
                      end
                    end
                  end
                end
              end
            end)
          end
          if _G.LexusConfig.EspLoai7 then
            pcall(function()
              local MyHUD = pc and pc.MyHUD
              if Valid(MyHUD) and distM <= 600 then
                local stateText = ""
                if _G.LexusConfig.Esp7_TuThe then
                  local pose
                  if enemy.PoseState then
                    pose = enemy.PoseState
                  elseif type(enemy.GetPoseState) == "function" then
                    pose = enemy:GetPoseState()
                  end
                  if pose == 0 or pose == "Stand" then
                    stateText = "\196\144\225\187\169ng"
                  elseif pose == 1 or pose == "Crouch" then
                    stateText = "Ng\225\187\147i"
                  elseif pose == 2 or pose == "Prone" then
                    stateText = "N\225\186\177m"
                  else
                    stateText = "\196\144\225\187\169ng"
                  end
                end
                if _G.LexusConfig.Esp7_VuKhi then
                  local curTime = os.clock()
                  if markData.AK_LAST_WEP_TIME == nil or curTime > markData.AK_LAST_WEP_TIME + 1.5 then
                    local eWeapon
                    if enemy.CurrentWeapon then
                      eWeapon = enemy.CurrentWeapon
                    elseif type(enemy.GetCurrentWeapon) == "function" then
                      eWeapon = enemy:GetCurrentWeapon()
                    elseif enemy.WeaponManagerComponent then
                      eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated
                    end
                    local weaponName = "Tay Kh\195\180ng"
                    if Valid(eWeapon) and type(eWeapon.GetWeaponName) == "function" then
                      weaponName = eWeapon:GetWeaponName()
                    end
                    markData.AK_CACHED_WEP_NAME = tostring(weaponName)
                    markData.AK_LAST_WEP_TIME = curTime
                  end
                  if stateText ~= "" then
                    stateText = stateText .. " - " .. (markData.AK_CACHED_WEP_NAME or "Tay Kh\195\180ng")
                  else
                    stateText = markData.AK_CACHED_WEP_NAME or "Tay Kh\195\180ng"
                  end
                end
                if stateText ~= "" then
                  local textColor = isBot and C_CYAN or C_YELLOW
                  local dynamicScale = math.max(0.5, 0.8 - distM / 400)
                  MyHUD:AddDebugText(stateText, enemy, 0.06, {
                    X = 0,
                    Y = 0,
                    Z = 100
                  }, {
                    X = 0,
                    Y = 0,
                    Z = 100
                  }, textColor, true, false, true, nil, dynamicScale, true)
                end
              end
            end)
          end
          if _G.LexusConfig.EspLoai5 or _G.LexusConfig.EspVipPro or _G.LexusConfig.EspVip then
            pcall(function()
              local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
              local show = true
              if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive and not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then
                show = false
              end
              if show and mLoc and aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector and SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) and (aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000) then
                show = false
              end
              if show then
                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then
                  enemy:Replay_CreateEnemyFrameUI(true, true)
                end
                if enemy.Replay_SetVisiableOfFrameUI then
                  enemy:Replay_SetVisiableOfFrameUI(true)
                end
                if enemy.Replay_UpdateEnemyFrameUI then
                  enemy:Replay_UpdateEnemyFrameUI(hpRatio)
                end
                local uiComp = enemy.EnemyFrameUI or type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI()
                if Valid(uiComp) and markData.LastFrameUIState ~= "VISIBLE" then
                  if type(uiComp.SetVisibility) == "function" then
                    uiComp:SetVisibility(0)
                  end
                  if type(uiComp.SetHiddenInGame) == "function" then
                    uiComp:SetHiddenInGame(false)
                  end
                  markData.LastFrameUIState = "VISIBLE"
                end
              end
            end)
          else
            pcall(function()
              if enemy.Replay_SetVisiableOfFrameUI then
                enemy:Replay_SetVisiableOfFrameUI(false)
              end
              local uiComp = enemy.EnemyFrameUI or type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI()
              if Valid(uiComp) and markData.LastFrameUIState ~= "HIDDEN" then
                if type(uiComp.SetVisibility) == "function" then
                  uiComp:SetVisibility(2)
                end
                if type(uiComp.SetHiddenInGame) == "function" then
                  uiComp:SetHiddenInGame(true)
                end
                markData.LastFrameUIState = "HIDDEN"
              end
            end)
          end
          if _G.LexusConfig.EspVipPro then
          end
          if _G.LexusConfig.EspDistance then
          end
          if _G.LexusConfig.EspVip then
            if markData.hpMark == nil then
              markData.hpMark = SafeAddMark(1006, FVector(0, 0, 0), 0, "", 4, enemy)
            end
            if markData.distMark == nil then
              markData.distMark = SafeAddMark(9999, FVector(0, 0, 0), 0, "", 4, enemy)
            end
          else
            if markData.hpMark then
              SafeRemoveMark(markData.hpMark)
              markData.hpMark = nil
            end
            if markData.distMark then
              SafeRemoveMark(markData.distMark)
              markData.distMark = nil
            end
          end
          if _G.LexusConfig.EspLoai8 then
            if markData.hpMark8 == nil then
              markData.hpMark8 = SafeAddMark(1006, FVector(0, 0, 0), 0, "", 4, enemy)
            end
          elseif markData.hpMark8 then
            SafeRemoveMark(markData.hpMark8)
            markData.hpMark8 = nil
          end
          if _G.LexusConfig.EspRadar then
            if not markData.radarMark or markData.radarMark == 0 then
              markData.radarMark = SafeAddMark(8888, FVector(0, 0, 0), 0, "", 4, enemy)
            end
          elseif markData.radarMark and markData.radarMark ~= 0 then
            SafeRemoveMark(markData.radarMark)
            markData.radarMark = nil
          end
          if _G.LexusConfig.EspOutline then
            pcall(function()
              local outColorChoice = _G.LexusState.CustomTextData.OutlineColor or 4
              local outThick = _G.LexusConfig.OutlineThickness or 10
              local outlineHash = string.format("%d_%d", outThick, outColorChoice)
              local meshes = GetAllSkeletalMeshes(enemy, markData)
              local currentMeshCount = {}
              if markData.OutlineState ~= outlineHash or markData.LastMeshCountOutline ~= currentMeshCount then
                local r, g, b = 255, 255, 0
                if outColorChoice == 1 then
                  r, g, b = 255, 0, 0
                elseif outColorChoice == 2 then
                  r, g, b = 0, 255, 0
                elseif outColorChoice == 3 then
                  r, g, b = 0, 0, 255
                elseif outColorChoice == 4 then
                  r, g, b = 255, 255, 0
                elseif outColorChoice == 5 then
                  r, g, b = 255, 0, 255
                elseif outColorChoice == 6 then
                  r, g, b = 255, 255, 255
                end
                local glowIntensity = 80.0
                local LinearColorClass = import("LinearColor") or _G.FLinearColor
                local glowDynamic = LinearColorClass and LinearColorClass(r / 255 * glowIntensity, g / 255 * glowIntensity, b / 255 * glowIntensity, 1.0) or {
                  R = r * glowIntensity,
                  G = g * glowIntensity,
                  B = b * glowIntensity,
                  A = 255
                }
                for _, comp in ipairs(meshes) do
                  if Valid(comp) then
                    pcall(function()
                      comp.UseScopeDistanceCulling = false
                      comp.PrimitiveShadingStrategy = 1
                      comp.ShadingRate = 6
                    end)
                    if comp.SetDrawIdeaOutline then
                      comp:SetDrawIdeaOutline(true)
                      if comp.OverrideIdeaOutlineColor then
                        comp:OverrideIdeaOutlineColor(true, glowDynamic)
                      end
                      if comp.OverrideIdeaOutlineThickness then
                        comp:OverrideIdeaOutlineThickness(true, _G.LexusConfig.OutlineThickness)
                      end
                    end
                  end
                end
                markData.OutlineState = outlineHash
                markData.LastMeshCountOutline = currentMeshCount
              end
            end)
          else
            pcall(function()
              if markData.OutlineState ~= "OFF" then
                local meshes = GetAllSkeletalMeshes(enemy, markData)
                for _, comp in ipairs(meshes) do
                  if Valid(comp) then
                    pcall(function()
                      comp.PrimitiveShadingStrategy = 0
                      comp.ShadingRate = 1
                    end)
                    if comp.SetDrawIdeaOutline then
                      comp:SetDrawIdeaOutline(false)
                    end
                  end
                end
                markData.OutlineState = "OFF"
                markData.LastMeshCountOutline = 0
              end
            end)
          end
        elseif not markData.IsCleanedUp then
          SafeRemoveMark(markData.radarMark)
          markData.radarMark = nil
          SafeRemoveMark(markData.hpMark)
          markData.hpMark = nil
          SafeRemoveMark(markData.hpMark8)
          markData.hpMark8 = nil
          SafeRemoveMark(markData.distMark)
          markData.distMark = nil
          if markData.MIDs then
            for meshStr, midTable in pairs(markData.MIDs) do
              for k, _ in pairs(midTable) do
                midTable[k] = nil
              end
            end
            markData.MIDs = nil
          end
          if markData.MIDs_V3 then
            for meshStr, midTable in pairs(markData.MIDs_V3) do
              for k, _ in pairs(midTable) do
                midTable[k] = nil
              end
            end
            markData.MIDs_V3 = nil
          end
          pcall(function()
            local eObj = markData.enemy
            if Valid(eObj) then
              if eObj.Replay_SetVisiableOfFrameUI then
                eObj:Replay_SetVisiableOfFrameUI(false)
              end
              local uiComp = eObj.EnemyFrameUI or type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI()
              if Valid(uiComp) then
                if type(uiComp.SetVisibility) == "function" then
                  uiComp:SetVisibility(2)
                end
                if type(uiComp.SetHiddenInGame) == "function" then
                  uiComp:SetHiddenInGame(true)
                end
              end
            end
            local PPM = import("PostProcessManager").GetInstance()
            local avatarComp = Valid(eObj) and type(eObj.getAvatarComponent2) == "function" and eObj:getAvatarComponent2() or nil
            if Valid(avatarComp) and Valid(PPM) then
              PPM:EnableAvatarOutline(avatarComp, false)
            end
          end)
          markData.IsCleanedUp = true
        end
      end
    end
  end)
  pcall(function()
    local lsg = require("client.slua.logic.setting.logic_setting_graphics")
    local gi = lsg.GetGameInstance()
    if gi then
      if _G.GTLMODConfig.RemoveGrass and not _G.GTLMODState.PrevGraphicsState.RemoveGrass then
        gi:ExecuteCMD("grass.DensityScale", "0")
        gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
        _G.GTLMODState.PrevGraphicsState.RemoveGrass = true
      elseif not _G.GTLMODConfig.RemoveGrass and _G.GTLMODState.PrevGraphicsState.RemoveGrass then
        gi:ExecuteCMD("grass.DensityScale", "1")
        gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
        _G.GTLMODState.PrevGraphicsState.RemoveGrass = false
      end
      if _G.GTLMODConfig.RemoveFog and not _G.GTLMODState.PrevGraphicsState.RemoveFog then
        gi:ExecuteCMD("r.SkyAtmosphere", "1")
        gi:ExecuteCMD("r.Fog", "0")
        gi:ExecuteCMD("r.VolumetricFog", "0")
        _G.GTLMODState.PrevGraphicsState.RemoveFog = true
      elseif not _G.GTLMODConfig.RemoveFog and _G.GTLMODState.PrevGraphicsState.RemoveFog then
        gi:ExecuteCMD("r.SkyAtmosphere", "1")
        gi:ExecuteCMD("r.Fog", "1")
        gi:ExecuteCMD("r.VolumetricFog", "1")
        _G.GTLMODState.PrevGraphicsState.RemoveFog = false
      end
      if _G.GTLMODConfig.WhiteBody and not _G.GTLMODState.PrevGraphicsState.WhiteBody then
        gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
        gi:ExecuteCMD("r.CharacterDiffusePower", "5")
        gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
        _G.GTLMODState.PrevGraphicsState.WhiteBody = true
      elseif not _G.GTLMODConfig.WhiteBody and _G.GTLMODState.PrevGraphicsState.WhiteBody then
        gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
        gi:ExecuteCMD("r.CharacterDiffusePower", "1")
        gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
        _G.GTLMODState.PrevGraphicsState.WhiteBody = false
      end
      if _G.GTLMODConfig.ColorBodyV2 and not _G.GTLMODState.PrevGraphicsState.ColorBodyV2 then
        gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
        gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
        gi:ExecuteCMD("r.CharacterDiffusePower", "200")
        _G.GTLMODState.PrevGraphicsState.ColorBodyV2 = true
      elseif not _G.GTLMODConfig.ColorBodyV2 and _G.GTLMODState.PrevGraphicsState.ColorBodyV2 then
        gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
        gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
        gi:ExecuteCMD("r.CharacterDiffusePower", "1")
        _G.GTLMODState.PrevGraphicsState.ColorBodyV2 = false
      end
      if _G.GTLMODConfig.BlackSky and not _G.GTLMODState.PrevGraphicsState.BlackSky then
        gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
        _G.GTLMODState.PrevGraphicsState.BlackSky = true
      elseif not _G.GTLMODConfig.BlackSky and _G.GTLMODState.PrevGraphicsState.BlackSky then
        gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
        _G.GTLMODState.PrevGraphicsState.BlackSky = false
      end
    end
  end)
end

_G.AkoStability = _G.AkoStability or {
  MainInterval = 0.05,
  AimbotInterval = 0.033,
  SlowFrameThreshold = 0.025,
  SlowFrameBackoff = 0.066,
  SlowFrameCount = 0,
  DrawCounterFrame = 0
}

local function AkoSafeCall(fn)
  if type(fn) ~= "function" then
    return false
  end
  return pcall(fn)
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
local myToken = _G.LexusState.LoopToken

local function FastTick()
  if isExpired then
    if not _G.LexusNotifiedExpire then
      Notify([[
MOD HAS BEEN EXPIRED, DM TO OWNER TO BUY THE FILE!
Inbox Tele @OfficialOwner10x]])
      _G.LexusNotifiedExpire = true
      ExpiredTick()
    end
    return
  end
  if myToken ~= _G.LexusState.LoopToken then
    return
  end
  local started = os.clock()
  AkoSafeCall(MainLoop)
  local st = _G.AkoStability
  st.DrawCounterFrame = st.DrawCounterFrame + 1
  if st.DrawCounterFrame >= 3 then
    st.DrawCounterFrame = 0
    AkoSafeCall(_M_DrawCounter)
  end
  local elapsed = os.clock() - started
  local nextInterval = st.MainInterval
  if elapsed > st.SlowFrameThreshold then
    st.SlowFrameCount = st.SlowFrameCount + 1
    nextInterval = st.SlowFrameBackoff
  else
    st.SlowFrameCount = math.max(0, st.SlowFrameCount - 1)
  end
  local ticker = _cachedTicker
  if not ticker then
    local ok
    ok, ticker = pcall(require, "common.time_ticker")
    if ok and ticker then
      _cachedTicker = ticker
    end
  end
  if ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(nextInterval, FastTick)
  end
end

local aimbotToken = 0

local function FastAimbotTick()
  if isExpired then
    return
  end
  if aimbotToken ~= _G.LexusState.AimbotLoopToken then
    return
  end
  pcall(function()
    if _G.LexusConfig.AimTouchEnable and type(_G.AimTouch) == "function" then
      _G.AimTouch()
    end
  end)
  local ticker = _cachedTicker
  if not ticker then
    local ok
    ok, ticker = pcall(require, "common.time_ticker")
    if ok and ticker then
      _cachedTicker = ticker
    end
  end
  if ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(_G.AkoStability.AimbotInterval, FastAimbotTick)
  end
end

if not isExpired then
  FastTick()
  _G.LexusState.AimbotLoopToken = (_G.LexusState.AimbotLoopToken or 0) + 1
  aimbotToken = _G.LexusState.AimbotLoopToken
  local okTicker, ticker = pcall(require, "common.time_ticker")
  if okTicker and ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(0.1, FastAimbotTick)
  end
  Notify("GIVE FEEDBACKS  Inbox Tele @OfficialOwner10x")
else
  FastTick()
end

local function InitAllModSystems()
  if isExpired then
    return
  end
  local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
  if not GameplayData then
    return
  end
  pcall(function()
    local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
    if slua.isValid(LocalPlayer) and LocalPlayer.bHasShownDevNotice == nil then
      LocalPlayer.bHasShownDevNotice = false
      LocalPlayer.bHasShownExpiredNotice = false
      LocalPlayer.bIsDeadFlag = false
    end
  end)
end

if not isExpired then
  pcall(function()
    require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems)
  end)
end
pcall(function()
  local function FixKillMessages()
    pcall(function()
      local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
      
      local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
      if KillInfo and KillInfo.__inner_impl then
        if not KillInfo.__inner_impl._originalFileItem then
          KillInfo.__inner_impl._originalFileItem = KillInfo.__inner_impl.FileItem
        end
        
        function KillInfo.__inner_impl:FileItem(DamageRecordData)
          local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
          if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then
            local currentWeapon = LocalPlayer:GetCurrentWeapon()
            if slua.isValid(currentWeapon) then
              local weaponID = currentWeapon:GetWeaponID()
              _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
              if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then
                DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit
              end
            end
          end
          if KillInfo.__inner_impl._originalFileItem then
            return KillInfo.__inner_impl._originalFileItem(self, DamageRecordData)
          end
        end
        
        print("\226\156\133 Kill messages restored!")
      end
    end)
  end
  
  local ok, ticker = pcall(require, "common.time_ticker")
  if ok and ticker and ticker.AddTimerOnce then
    ticker.AddTimerOnce(2.0, FixKillMessages)
  else
    FixKillMessages()
  end
end)
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  }
}, "BRPlayerCharacterBase")
