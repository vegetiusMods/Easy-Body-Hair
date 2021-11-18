Scriptname SBHQuest extends Quest  

;Properties
SBHMcm Property Mcm Auto
ReferenceAlias Property PlayerAlias Auto  
GlobalVariable Property GameDaysPassed Auto

bool Property Started Auto Hidden
bool Property ErrorState Auto Hidden

string[] property ArmpitsPresets auto
string[] property PubesPresets auto
string[] property Presets auto

string[] property ArmpitsTrimmings auto
string[] property PubesTrimmings auto

Idle[] property IdleShaveArmpits auto
Idle property IdleShavePubes auto
Idle property IdleStop auto

FormList Property SBH_PreventArmpitsAccess Auto
FormList Property SBH_PreventPubesAccess Auto

string property Armpits = "Armpits" auto
string property Pubes = "Pubes" auto

int property ArmpitsMaxStage = 0 auto
int property PubesMaxStage = 0 auto

Sound Property SBHShaving Auto

; Constants
string defaultTexture = "actors\\character\\overlays\\default.dds"
string naturalPresetsFolder = "../SBH/growth_presets/"
string trimmingPresetsFolder = "../SBH/trimmings/"

float LongPollingInterval = 24.0
Actor Player

string lastUpdateStorageKeyPrefix = "SBH_LastUpdate_"
string stageStorageKeyPrefix = "SBH_Stage_"
string overlayNodeStorageKeyPrefix = "SBH_OverlayNode_"

; UI
string chooseAreaMsg = "[Choose an area to shave]"
string chooseTrimmingMsg = "[Choose a trimming]"
string cleanlyShavedButton = "Cleanly Shaven"
string cancelBtn = "[Cancel]"

; Init and mod lifecycle

Event OnInit()
    Utility.Wait(2)

    Player = PlayerAlias.GetActorRef()

    OnLoad(true)
    ArmpitsPresets[0] = new string[1]
EndEvent

Function OnLoad(bool forceStart)
    ;Reload texture presets data
    ErrorState = !SecureLoad()
    if ErrorState
        StopMod(false)
        return
    endIf

    if (forceStart && !ErrorState)
        StartMod(false)
    elseif (Started)
        RestartMod()
    endIf

    RefreshMod()
EndFunction

; Return true if successful (mod can start)
bool Function SecureLoad()
    ; Load presets
    ArmpitsPresets = JsonUtil.JsonInFolder(naturalPresetsFolder + Armpits)

    if ArmpitsPresets.Length == 0
        Debug.MessageBox("Simple Body Hair\nNo Armpits body preset file has been found, the mod is unable to start.\nIf this is intentional, please Clean the mod in the MCM.")
        return false
    endIf

    bool found = false
    if Mcm.ActivePreset != ""
        ; Check if preset in use is present
        
        int i = 0
        while i < Presets.Length
            if Presets[i] == MCM.ActivePreset
                found = true
                i = Presets.Length
            endif
            i += 1
        endWhile
        if !found
            Debug.MessageBox("Simple Body Hair\nThe body hair preset saved with this game could not be found.\nThis does not prevent the mod friom running as a default preset has been selected.\nPlease check the MCM.")
        endIf
    endIf

    if !found
        ; We set the first available preset
        MCM.ActivePreset = Presets[0]
    endIf

    ; Preload max stages
    ArmpitsMaxStage = JsonUtil.StringListCount(GetPresetFile(), armpits) - 1
    PubesMaxStage = JsonUtil.StringListCount(GetPresetFile(), pubes) - 1

    return true
EndFunction

Function StartMod(bool quiet)
    log(player.GetEquippedArmorInSlot(32))

    If (Started)
        return
    endIf

    If (Mcm.IsUpdateOnSleep())
        log("Update On Sleep, RegisterForSleep")
        RegisterForSleep()
    Else
        log("Update Daily, RegisterForSingleUpdateGameTime(24.0)")
        RegisterForSingleUpdateGameTime(LongPollingInterval)
    EndIf
    Started = true
    if (!quiet)
        Debug.Notification("Simple body hair Started")
    endif
EndFunction

Function StopMod(bool quiet)
    UnregisterForSleep()
    UnregisterForUpdateGameTime()
    Started = false
    if (!quiet)
        Debug.Notification("Simple body hair Stopped")
    endif
EndFunction

Function RestartMod()
    StopMod(true)

    Utility.Wait(1)

    StartMod(true)
EndFunction

Function RefreshMod()
    RefreshZoneOverlay(Armpits)
    RefreshZoneOverlay(Pubes)
EndFunction

Function CleanMod()
    ClearZone(armpits)
    ClearZone(Pubes)
EndFunction

; Config change handlers

Function HandleModStateChange()
    if (Started || ErrorState)
        StopMod(false)
    else
        StartMod(false)
    endIf
EndFunction

Function HandleClean()
    CleanMod()
    Debug.MessageBox("Simple Body Hair has reseted all values and removed overlays.")
EndFunction

Function HandleRefresh()
    RefreshMod()
    Debug.MessageBox("Simple Body Hair has refreshed overlays.")
EndFunction

Function HandlePresetChange()
    RefreshMod()
EndFunction

Function HandleUpdateTypeChange()
    if (Started)
        RestartMod()
    endIf
EndFunction

Function HandleZoneStageChange(string zoneName, int newStage)
    ApplyZoneStage(zoneName, newStage, GetMaxZoneStage(zoneName))
EndFunction

; Mod logic

Event OnUpdateGameTime()
    log("Receiving daily update event.")
    UpdateGrowth()
    RegisterForSingleUpdateGameTime(LongPollingInterval)
EndEvent

Event OnSleepStop(bool abInterrupted)
    log("Receiving sleep stop event.")
    UpdateGrowth()
EndEvent

Function UpdateGrowth()
    int gameDayPassedValue = 500 ; GameDaysPassed.GetValueInt()

    UpdateZoneHair(armpits, gameDayPassedValue, ArmpitsMaxStage)
    UpdateZoneHair(pubes, gameDayPassedValue, PubesMaxStage)
EndFunction

bool Function Shave(Actor target)
    if (target != Player)
        return false
    endIf

    if (player.GetEquippedArmorInSlot(32))
        Debug.MessageBox("You must be naked to shave.")
        return false
    endIf
    
    int armpitsStage = GetZoneStage(Armpits)
    int pubesStage = GetZoneStage(Pubes)

    if (armpitsStage == 0 && pubesStage == 0)
        Debug.MessageBox("You are already thoroughly shaved.")
        return false
    endIf

    Game.DisablePlayerControls(true, true, true, false, true, true, true)
	Game.ForceThirdPerson()

    ; Select zone to shave
    UIListMenu shavingMenu = uiextensions.GetMenu("UIListMenu") as UIListMenu
    shavingMenu.AddEntryItem(chooseAreaMsg)
    if armpitsStage > 0
        shavingMenu.AddEntryItem(armpits)
    endIf
    if pubesStage > 0
        shavingMenu.AddEntryItem(pubes)
    endIf
    shavingMenu.AddEntryItem(cancelBtn)
    shavingMenu.OpenMenu(none)
    String zoneName = shavingMenu.GetResultString()

    if zoneName == chooseAreaMsg || zoneName == cancelBtn
        Game.EnablePlayerControls()
        return false
    endIf

    ; Check if zone available
    if !IsZoneAvailable(zoneName)
        Debug.MessageBox("Your outfit prevents accessing this zone!")
        Game.EnablePlayerControls()
        return false
    endIf

    ; Pattern selection
    int newStage = 0
    int currentStage = GetZoneStage(zoneName)

    String trimming = ""
    String texture = ""
    String[] trimmings = JsonUtil.JsonInFolder(trimmingPresetsFolder + zoneName)
    if (trimmings.Length > 0)
        UIListMenu trimmingMenu = uiextensions.GetMenu("UIListMenu") as UIListMenu

        trimmingMenu.AddEntryItem(chooseTrimmingMsg)
        trimmingMenu.AddEntryItem(cleanlyShavedButton)

        int iTrimming = 0
        int addedTrimmings = 0
        while iTrimming < trimmings.Length
            if (JsonUtil.GetIntValue(trimmingPresetsFolder + zoneName + "/" + trimmings[iTrimming], "stage") <= currentStage)
                trimmingMenu.AddEntryItem(StringUtil.Substring(trimmings[iTrimming], 0, StringUtil.GetLength(trimmings[iTrimming]) - 5))
                addedTrimmings += 1
            endIf
            iTrimming += 1
        endWhile

        log(addedTrimmings + " found for stage " + currentStage)

        if (addedTrimmings > 0)
            shavingMenu.AddEntryItem(cancelBtn)

            trimmingMenu.OpenMenu(none)
            trimming = trimmingMenu.GetResultString()

            if trimming == chooseTrimmingMsg || trimming == cancelBtn
                Game.EnablePlayerControls()
                return false
            elseif trimming != cleanlyShavedButton
                texture = JsonUtil.GetStringValue(trimmingPresetsFolder + zoneName + "/" + trimming, "texture")
                newStage = JsonUtil.GetIntValue(trimmingPresetsFolder + zoneName + "/" + trimming, "stage")
            endIf
        endIf
    endIf

    ; Shaving
    Idle shavingIddle
    if zoneName == Armpits
        shavingIddle = IdleShaveArmpits
    ElseIf zoneName == Pubes
        shavingIddle = IdleShavePubes
    endif

    If Player.IsWeaponDrawn()
        Player.SheatheWeapon()
        Utility.Wait(1.500000)
    Else
        Utility.Wait(0.200000)
    EndIf
    
    Player.PlayIdle(shavingIddle)
    SBHShaving.Play(Player)
    Utility.Wait(1.0)
    SBHShaving.Play(Player)
    ApplyZoneStage(zoneName, newStage, GetMaxZoneStage(zoneName), texture)
    StorageUtil.SetIntValue(Player, lastUpdateStorageKeyPrefix + zoneName, GameDaysPassed.GetValueInt())
    Utility.Wait(1.0)
    SBHShaving.Play(Player)
    Utility.Wait(4.0)
    Player.PlayIdle(IdleStop)
    if(texture == "")
        Debug.Notification("You have cleanly shaved your " + zoneName)
    Else
        Debug.Notification("You have trimmed your " + zoneName)
    endIf
    Utility.Wait(0.500000)

	Game.EnablePlayerControls()
    return true
EndFunction

bool Function IsZoneAvailable(string zoneName)
    FormList preventKeywords
    if zoneName == Armpits
        preventKeywords = SBH_PreventArmpitsAccess
    ElseIf zoneName == Pubes
        preventKeywords = SBH_PreventPubesAccess
    endif

    if preventKeywords
        int i = 0
        int max = preventKeywords.GetSize()

        While (i < max)
            Keyword k = preventKeywords.GetAt(i) as Keyword
            if (k && player.WornHasKeyword(k))
                return false
            endif
            i += 1
        EndWhile
    endIf

    Form[] preventKeywordsJson = JsonUtil.FormListToArray(GetPresetFile(), "preventAccess" + zoneName)
    int i = 0
    
    While (i < preventKeywordsJson.Length)
        Keyword k = preventKeywordsJson[i] as Keyword
        if (k && player.WornHasKeyword(k))
            return false
        endif
        i += 1
    EndWhile

    return true
EndFunction

Function UpdateZoneHair(String zoneName, int gameDayPassedValue, int maxStage)
    int lastUpdate = StorageUtil.GetIntValue(Player, lastUpdateStorageKeyPrefix + zoneName, missing = 0)

    if gameDayPassedValue - lastUpdate >= Mcm.DaysForGrowth
        
        StorageUtil.SetIntValue(Player, lastUpdateStorageKeyPrefix + zoneName, gameDayPassedValue)
        ; Update stage
        int zoneStage = GetZoneStage(zoneName)
        log(gameDayPassedValue + " days passed, last update for " + zoneName + " was on day:" + lastUpdate + " the difference is greater than " + Mcm.DaysForGrowth + ", hair will grow")
        if(zoneStage < maxStage)
            zoneStage += 1
            Debug.Notification("You notice your " + zoneName + " hair has grown")
        endIf

        ApplyZoneStage(zoneName, zoneStage, maxStage)
    else
        log(gameDayPassedValue + " days passed, last update for " + zoneName + " was on day:" + lastUpdate + " the difference is lesser than " + Mcm.DaysForGrowth + ", no hair growth")
    endIf
EndFunction

Function ApplyZoneStage(String zoneName, int stage, int maxStage, string pattern = "")
    if (stage > maxStage)
        stage = maxStage
    endIf

    StorageUtil.SetIntValue(Player, stageStorageKeyPrefix + zoneName, stage)

    RefreshZoneOverlay(zoneName, stage, pattern)
EndFunction

Function RefreshZoneOverlay(string zoneName, int stage = -1, string texture = "")
    if (stage == -1)
        stage = GetZoneStage(zoneName)
    endIf

    ; Update overlay
    if texture == ""
        texture = JsonUtil.StringListGet(GetPresetFile(), zoneName, stage)
    endIf
    string overlayNode = StorageUtil.GetStringValue(Player, overlayNodeStorageKeyPrefix + zoneName, missing = "")
    log("Applying stage: " + stage + " to zone: " + zoneName + " texturefound: " + texture + " current overlay node: " + overlayNode)
    if ((texture == "" || texture == defaultTexture) && overlayNode != "")
        log("Texture string is empty or default, removing current overlay")
        ClearOverlay(overlayNode)
        StorageUtil.UnsetStringValue(Player, overlayNodeStorageKeyPrefix + zoneName)
    Else
        if (overlayNode == "")
            overlayNode = GetEmptyNode()
            if (overlayNode == "")
                Debug.MessageBox("Simple Body Hair was not able to find an available overlay node to apply body hair.\nPlease increase the number of available nodes in NiOverride.ini.")
                return
            else
                StorageUtil.SetStringValue(Player, overlayNodeStorageKeyPrefix + zoneName, overlayNode)
            endif
        endIf
        log("Applying overlay to node: " + overlayNode)
        ApplyOverlay(overlayNode, texture, Player.GetActorBase().GetHairColor().GetColor())
    endIf
EndFunction

Function ClearZone(string zoneName)
    string overlayNode = StorageUtil.GetStringValue(Player, overlayNodeStorageKeyPrefix + zoneName, missing = "")
    if (overlayNode != "")
        ClearOverlay(overlayNode)
        StorageUtil.UnsetStringValue(Player, overlayNodeStorageKeyPrefix + zoneName)
    endif
    Storageutil.UnsetIntValue(Player, lastUpdateStorageKeyPrefix + zoneName)
    Storageutil.UnsetIntValue(Player, stageStorageKeyPrefix + zoneName)
EndFunction

; NiO interactions

Function ApplyOverlay(String node, String texture, int tintColor)
    NiOverride.AddNodeOverrideString(player, true, node, 9, 0, texture, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideInt(player, true, node, 7, -1, tintColor, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideInt(player, true, node, 0, -1, 0, true)
    Utility.Wait(0.01)
    ;NiOverride.AddNodeOverrideFloat(player, true, node, 1, -1, 1.0, true)
    ;Utility.Wait(0.01)
    ; 8 - float - ShaderAlpha
    NiOverride.AddNodeOverrideFloat(player, true, node, 8, -1, 1.0, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideFloat(player, true, node, 2, -1, 0.0, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideFloat(player, true, node, 3, -1, 0.0, true)
    NiOverride.ApplyNodeOverrides(player)
EndFunction

Function ClearOverlay(String node)
    NiOverride.AddNodeOverrideString(player, true, Node, 9, 0, defaultTexture, false)
	NiOverride.RemoveNodeOverride(player, true, node , 9, 0)
	NiOverride.RemoveNodeOverride(player, true, Node, 7, -1)
	NiOverride.RemoveNodeOverride(player, true, Node, 0, -1)
	NiOverride.RemoveNodeOverride(player, true, Node, 8, -1)
	NiOverride.RemoveNodeOverride(player, true, Node, 2, -1)
	NiOverride.RemoveNodeOverride(player, true, Node, 3, -1)
EndFunction

String Function GetEmptyNode()
	Int i = 0
	Int NumSlots = NiOverride.GetNumBodyOverlays()
	String TexPath
	Bool FirstPass = true

	While i < NumSlots
        string bodyOvl = "Body [ovl" + i + "]"
        if StorageUtil.GetStringValue(Player, overlayNodeStorageKeyPrefix + armpits) != bodyOvl && StorageUtil.GetStringValue(Player, overlayNodeStorageKeyPrefix + pubes) != bodyOvl
            TexPath = NiOverride.GetNodeOverrideString(player, true, bodyOvl, 9, 0)
            If TexPath == "" || TexPath == defaultTexture
                log("Slot " + i + " chosen")
                Return bodyOvl
            EndIf
        endIf
		i += 1
		If !FirstPass && i == NumSlots
			FirstPass = true
			i = 0
		EndIf
	EndWhile
	Return none
EndFunction

; Getters

int Function GetAreaIndex(string areaName)

EndFunction

int Function GetZoneStage(string zoneName)
    return StorageUtil.GetIntValue(Player, stageStorageKeyPrefix + zoneName, missing = 0)
EndFunction

int Function GetMaxZoneStage(string zoneName)
    if zoneName == Armpits
        return ArmpitsMaxStage
    ElseIf zoneName == Pubes
        return PubesMaxStage
    Else
        ; ERROR
        return 0
    EndIf
EndFunction

string Function GetPresetFile()
    return naturalPresetsFolder + Mcm.ActivePreset
EndFunction

; Utilities

function log(string in)
	MiscUtil.PrintConsole("Simple Body Hair: " + In)
EndFunction