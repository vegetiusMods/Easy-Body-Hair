Scriptname EBHQuest extends Quest  

; Hello, I'm a stupidly complex and configurable but easy to use mod to simulate body hair growth.
; Please love me

;Properties
EBHMcm Property Mcm Auto
ReferenceAlias Property PlayerAlias Auto  
GlobalVariable Property GameDaysPassed Auto

bool Property Started Auto Hidden
bool Property ErrorState Auto Hidden

string[] Property Areas Auto Hidden
int Property AreasCount = 0 Auto Hidden

Form[] property IdleShaveArea auto Hidden
Idle property IdleStop auto

Form[] Property PreventAreaAccessKeywords Auto Hidden

int[] Property AreaMaxStage Auto Hidden
int[] Property AreasPresetsCount Auto Hidden

string[] Property AreasLastTrimmings Auto Hidden

Sound Property EBHShaving Auto

; Constants
string fullRootLocation = "data/skse/plugins/"
string relativeRootLocation = "../"
string ebhFolder = "EBH/"
string maleFolder = "m/"
string femaleFolder = "f/"
string growthPresetsFolder = "growth_presets/"
string trimmingsFolder = "trimmings/"

string defaultTexture = "actors\\character\\overlays\\default.dds"

float LongPollingInterval = 24.0
Actor Player


string lastUpdateStorageKeyPrefix = "EBH_LastUpdate_"
string stageStorageKeyPrefix = "EBH_Stage_"
string overlayNodeStorageKeyPrefix = "EBH_OverlayNode_"

string stagesKey = "stages"

; UI
string chooseAreaMsg = "[Choose an area to shave]"
string chooseTrimmingMsg = "[Choose a trimming]"
string lastTrimmingButtonPre = "[Last: "
string lastTrimmingButtonSu = "]"
string cleanlyShavedButton = "Cleanly Shaven"
string cancelBtn = "[Cancel]"

; Init and mod lifecycle
Event OnInit()
    Utility.Wait(1)

    Player = PlayerAlias.GetActorRef()

    OnLoad(true)
EndEvent

Function OnLoad(bool firstStart)
    ;Reload texture presets data
    ErrorState = !SecureLoad(firstStart)
    if ErrorState
        StopMod(false)
        return
    endIf

    if (firstStart && !ErrorState)
        StartMod(false)
    elseif (Started)
        RestartMod()
    endIf

    RefreshMod()
EndFunction

; Return true if successful (mod can start)
bool Function SecureLoad(bool firstStart)
    Areas = MiscUtil.FoldersInFolder(GetSexFolder(false))

    AreasCount = Areas.Length
    if (AreasCount == 0)
        return false
    endif

    if firstStart
        Mcm.ActivePresets = Utility.CreateStringArray(AreasCount)
        AreasLastTrimmings = Utility.CreateStringArray(AreasCount)
    endif

    PreventAreaAccessKeywords = Utility.CreateFormArray(AreasCount)
    IdleShaveArea = Utility.CreateFormArray(AreasCount)
    AreasPresetsCount = Utility.CreateIntArray(AreasCount)
    AreaMaxStage = Utility.CreateIntArray(AreasCount)
    
    ; Todo Consolidate Mcm.AP
    int iArea = 0

    while iArea < AreasCount
        string[] presetsNames = GetPresetsNames(Areas[iArea])
        int j = 0
        string area = Areas[iArea]
        log("Saved preset file: " + GetActivePresetFile(area, relative = false))
        AreasPresetsCount[iArea] = presetsNames.Length
        PreventAreaAccessKeywords[iArea] = JsonUtil.GetFormValue(GetConfigFile(area), "preventAccessFormList")
        IdleShaveArea[iArea] = JsonUtil.GetFormValue(GetConfigFile(area), "shavingIdle")
        AreasLastTrimmings[iArea] = ""
        ;JsonUtil.SetFormValue(GetConfigFile(area), "preventAccessFormList", PreventAreaAccessKeywords[iArea])
        ;JsonUtil.SetFormValue(GetConfigFile(area), "shavingIdle", IdleShaveArea[iArea])

        if (presetsNames.Length == 0)
            Mcm.ActivePresets[iArea] == ""
        Else
            bool found = false
            if Mcm.ActivePresets[iArea] != ""
                ; Check if preset in use is present
                if !MiscUtil.FileExists(GetActivePresetFile(area, relative = false))
                    Debug.MessageBox("Easy Body Hair\nThe body hair preset saved with this game could not be found.\nThis does not prevent the mod from running as a default preset has been selected.\nPlease check the MCM.")
                else
                    found = true
                endIf
            endIf
    
            if !found
                MCM.ActivePresets[iArea] = presetsNames[0]
            endIf
        endIf

        log("Active preset: " + Mcm.ActivePresets[iArea])
        AreaMaxStage[iArea] = JsonUtil.StringListCount(GetActivePresetFile(Areas[iArea]), stagesKey) - 1

        iArea += 1
    endWhile
    return true
EndFunction

Function StartMod(bool quiet)
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
        Debug.Notification("Easy body hair Started")
    endif
EndFunction

Function StopMod(bool quiet)
    UnregisterForSleep()
    UnregisterForUpdateGameTime()
    Started = false
    if (!quiet)
        Debug.Notification("Easy body hair Stopped")
    endif
EndFunction

Function RestartMod()
    StopMod(true)

    Utility.Wait(1)

    StartMod(true)
EndFunction

Function RefreshMod()
    int i = 0
    while i < AreasCount
        RefreshZoneOverlay(Areas[i])
        i += 1
    endWhile
EndFunction

Function CleanMod()
    int i = 0
    while i < AreasCount
        ClearZone(Areas[i])
        i += 1
    endWhile
EndFunction

Function ResetMod()
    StopMod(true)
    Utility.Wait(1)
    CleanMod()
    OnLoad(true)
    StartMod(true)
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
    Debug.MessageBox("Easy Body Hair has reseted all values and removed overlays.")
EndFunction

Function HandleRefresh()
    RefreshMod()
    Debug.MessageBox("Easy Body Hair has refreshed overlays.")
EndFunction

Function HandleReset()
    ResetMod()
    Debug.MessageBox("Easy Body Hair has been reset.")
EndFunction

Function HandlePresetChange(int areaIndex)
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
    UpdateGrowth()
    RegisterForSingleUpdateGameTime(LongPollingInterval)
EndEvent

Event OnSleepStop(bool abInterrupted)
    UpdateGrowth()
EndEvent

Function UpdateGrowth()
    int gameDayPassedValue = GameDaysPassed.GetValueInt()

    int i = 0
    while i < AreasCount
        UpdateZoneHair(Areas[i], gameDayPassedValue, AreaMaxStage[i])
        i += 1
    endWhile
EndFunction

bool Function Shave(Actor target)
    if (target != Player)
        return false
    endIf

    if (player.GetEquippedArmorInSlot(32))
        Debug.MessageBox("You must be naked to shave.")
        return false
    endIf
    
    ; Select zone to shave
    UIListMenu shavingMenu = uiextensions.GetMenu("UIListMenu") as UIListMenu
    shavingMenu.AddEntryItem(chooseAreaMsg)
    int sumAreasStages = 0
    int i = 0
    while i < AreasCount
        int areaStage = GetZoneStage(Areas[i])
        if areaStage > 0
            shavingMenu.AddEntryItem(Areas[i])
        endIf
        sumAreasStages += areaStage
        i += 1
    endWhile

    if (sumAreasStages == 0)
        Debug.MessageBox("You are already thoroughly shaved.")
        return false
    endIf

    Game.DisablePlayerControls(true, true, true, false, true, true, true)
	Game.ForceThirdPerson()
    shavingMenu.AddEntryItem(cancelBtn)
    shavingMenu.OpenMenu(none)
    String zoneName = shavingMenu.GetResultString()

    if zoneName == chooseAreaMsg || zoneName == cancelBtn
        Game.EnablePlayerControls()
        return false
    endIf

    int areaIndex = GetAreaIndex(zoneName)
    ; Check if zone available
    if !IsZoneAvailableIx(areaIndex)
        Debug.MessageBox("Your outfit prevents accessing this zone!")
        Game.EnablePlayerControls()
        return false
    endIf

    ; Pattern selection
    int newStage = 0
    int currentStage = GetZoneStage(zoneName)

    String trimming = ""
    String texture = ""
    String[] trimmings = GetTrimmingsNames(zoneName)

    if (trimmings.Length > 0)
        UIListMenu trimmingMenu = uiextensions.GetMenu("UIListMenu") as UIListMenu

        trimmingMenu.AddEntryItem(chooseTrimmingMsg)

        bool lastUsedFound = false
        int iTrimming = 0
        int addedTrimmings = 0
        while iTrimming < trimmings.Length
            if (JsonUtil.GetIntValue(GetTrimmingFile(zoneName, trimmings[iTrimming]), "stage") < currentStage)
                addedTrimmings += 1
                log(AreasLastTrimmings[areaIndex] + ":" + trimmings[iTrimming])
                if AreasLastTrimmings[areaIndex] == trimmings[iTrimming]
                    lastUsedFound = true
                endIf
            else
                trimmings[iTrimming] = ""
            endIf
            iTrimming += 1
        endWhile

        if (lastUsedFound)
            trimmingMenu.AddEntryItem(lastTrimmingButtonPre + AreasLastTrimmings[areaIndex] + lastTrimmingButtonSu)
        endIf

        if Mcm.ActivePresets[areaIndex] != ""
            trimmingMenu.AddEntryItem(cleanlyShavedButton)
        endIf

        if (addedTrimmings > 0)
            iTrimming = 0
            while iTrimming < trimmings.Length
                if (trimmings[iTrimming] != "")
                    trimmingMenu.AddEntryItem(trimmings[iTrimming])
                endIf
                iTrimming += 1
            endWhile
        endIf
        
        log(addedTrimmings + " found for stage " + currentStage)

        if (addedTrimmings > 0)
            shavingMenu.AddEntryItem(cancelBtn)

            trimmingMenu.OpenMenu(none)
            trimming = trimmingMenu.GetResultString()

            if trimming == chooseTrimmingMsg || trimming == cancelBtn
                Game.EnablePlayerControls()
                return false
            elseif StringUtil.Find(trimming, lastTrimmingButtonPre) > -1
                trimming = AreasLastTrimmings[areaIndex]
            elseif trimming != cleanlyShavedButton
                AreasLastTrimmings[areaIndex] = trimming
            endIf
            
            string trimmingFile = GetTrimmingFile(zoneName, trimming)
            log("Chosen trimming file: " + trimmingFile)
            texture = JsonUtil.GetStringValue(trimmingFile, "texture")
            newStage = JsonUtil.GetIntValue(trimmingFile, "stage")
        endIf
    endIf

    ; Shaving
    Idle shavingIddle = IdleShaveArea[areaIndex] as Idle

    If Player.IsWeaponDrawn()
        Player.SheatheWeapon()
        Utility.Wait(1.500000)
    Else
        Utility.Wait(0.200000)
    EndIf
    
    Player.PlayIdle(shavingIddle)
    EBHShaving.Play(Player)
    Utility.Wait(1.0)
    EBHShaving.Play(Player)
    ApplyZoneStage(zoneName, newStage, GetMaxZoneStage(zoneName), texture)
    StorageUtil.SetIntValue(Player, lastUpdateStorageKeyPrefix + zoneName, GameDaysPassed.GetValueInt())
    Utility.Wait(1.0)
    EBHShaving.Play(Player)
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

bool Function IsZoneAvailableIx(int areaIndex)
    string areaname = Areas[areaIndex]
    FormList preventKeywords = PreventAreaAccessKeywords[areaIndex] as FormList

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

    Form[] preventKeywordsJson = JsonUtil.FormListToArray(GetConfigFile(areaName), "preventAccessKeywords")
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
    if Mcm.ActivePresets[GetAreaIndex(zoneName)] == ""
        log("No active preset for area " + zoneName + ", aborting growth update.")
        return
    endIf

    int zoneStage = GetZoneStage(zoneName)
    int lastUpdate = StorageUtil.GetIntValue(Player, lastUpdateStorageKeyPrefix + zoneName, missing = 0)
    int daysForGrowth = Mcm.DaysForGrowthGlobal
    if (!Mcm.IsGlobalDaysForGrowth)
        daysForGrowth = Mcm.AreasDaysForGrowth[GetAreaIndex(zoneName)]
    endIf
    If Mcm.IsProgressiveGrowthInterval
        daysForGrowth += zoneStage
    EndIf

    if gameDayPassedValue - lastUpdate >= daysForGrowth
        StorageUtil.SetIntValue(Player, lastUpdateStorageKeyPrefix + zoneName, gameDayPassedValue)
        ; Update stage
        
        log(gameDayPassedValue + " days passed, last update for " + zoneName + " was on day:" + lastUpdate + " the difference is greater than or equal to " + daysForGrowth + ", hair will grow")
        if(zoneStage < maxStage)
            zoneStage += 1
            Debug.Notification("You notice your " + zoneName + " hair has grown")
        endIf

        ApplyZoneStage(zoneName, zoneStage, maxStage)
    else
        log(gameDayPassedValue + " days passed, last update for " + zoneName + " was on day:" + lastUpdate + " the difference is lesser than " + daysForGrowth + ", no hair growth")
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
        texture = JsonUtil.StringListGet(GetActivePresetFile(zoneName), stagesKey, stage)
    endIf
    string overlayNode = StorageUtil.GetStringValue(Player, overlayNodeStorageKeyPrefix + zoneName, missing = "")
    log("Applying stage: " + stage + " to zone: " + zoneName + " texturefound: " + texture + " current overlay node: " + overlayNode)
    if (IsDefaultOrEmptyTexture(texture) && overlayNode != "")
        log("Texture string is empty or default, removing current overlay")
        ClearOverlay(overlayNode)
        StorageUtil.UnsetStringValue(Player, overlayNodeStorageKeyPrefix + zoneName)
    Else
        if (overlayNode == "")
            overlayNode = GetEmptyNode()
            if (overlayNode == "")
                Debug.MessageBox("Easy Body Hair was not able to find an available overlay node to apply body hair.\nPlease increase the number of available nodes in NiOverride.ini.")
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
    bool female = IsFemale()
    NiOverride.AddNodeOverrideString(player, female, node, 9, 0, texture, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideInt(player, female, node, 7, -1, tintColor, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideInt(player, female, node, 0, -1, 0, true)
    Utility.Wait(0.01)
    ;NiOverride.AddNodeOverrideFloat(player, female, node, 1, -1, 1.0, true)
    ;Utility.Wait(0.01)
    ; 8 - float - ShaderAlpha
    NiOverride.AddNodeOverrideFloat(player, female, node, 8, -1, 1.0, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideFloat(player, female, node, 2, -1, 0.0, true)
    Utility.Wait(0.01)
    NiOverride.AddNodeOverrideFloat(player, female, node, 3, -1, 0.0, true)
    NiOverride.ApplyNodeOverrides(player)
EndFunction

Function ClearOverlay(String node)
    bool female = IsFemale()
    NiOverride.AddNodeOverrideString(player, female, Node, 9, 0, defaultTexture, false)
	NiOverride.RemoveNodeOverride(player, female, node , 9, 0)
	NiOverride.RemoveNodeOverride(player, female, Node, 7, -1)
	NiOverride.RemoveNodeOverride(player, female, Node, 0, -1)
	NiOverride.RemoveNodeOverride(player, female, Node, 8, -1)
	NiOverride.RemoveNodeOverride(player, female, Node, 2, -1)
	NiOverride.RemoveNodeOverride(player, female, Node, 3, -1)
EndFunction

String Function GetEmptyNode()
	Int i = 0
	Int NumSlots = NiOverride.GetNumBodyOverlays()
	String TexPath
	Bool FirstPass = true

	While i < NumSlots
        string bodyOvl = "Body [ovl" + i + "]"
        int iArea = 0
        bool reserved = false
        while iArea < AreasCount && !reserved
            if bodyOvl == StorageUtil.GetStringValue(Player, overlayNodeStorageKeyPrefix + Areas[iArea])
                reserved = true
            else
                iArea += 1
            endif
        endWhile

        if !reserved
            TexPath = NiOverride.GetNodeOverrideString(player, true, bodyOvl, 9, 0)
            If IsDefaultOrEmptyTexture(TexPath)
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
    return Areas.Find(areaName)
EndFunction

int Function GetZoneStage(string zoneName)
    return StorageUtil.GetIntValue(Player, stageStorageKeyPrefix + zoneName, missing = 0)
EndFunction

int Function GetAreaStageIx(int areaIndex)
    return GetZoneStage(Areas[areaIndex])
EndFunction

int Function GetMaxZoneStage(string zoneName)
    return GetMaxZoneStageIx(GetAreaIndex(zoneName))
EndFunction

int Function GetMaxZoneStageIx(int zoneindex)
    return AreaMaxStage[zoneindex]
EndFunction

string Function GetSexFolder(bool relative = true)
    string folderPath
    if relative
        folderPath = relativeRootLocation
    else
        folderPath = fullRootLocation
    endIf

    folderPath += ebhFolder
    
    if (IsFemale())
        folderPath += femaleFolder
    else
        folderPath += maleFolder
    endIf
    ;log("SexFolder: " + folderPath)
    return folderPath
EndFunction

string Function GetAreaFolder(string areaName, bool relative = true)
    ;log("AreaFolder: " + GetSexFolder(relative) + areaName + "/")
    return GetSexFolder(relative) + areaName + "/"
endFunction

string Function GetTrimmingsFolder(string areaName)
    ;log("TrimmingsFolder: " + GetAreaFolder(areaName) + trimmingsFolder)
    return GetAreaFolder(areaName) + trimmingsFolder
endFunction

string[] Function GetTrimmingsNames(string areaName)
    string[] trimmings = JsonUtil.JsonInFolder(GetTrimmingsFolder(areaName))
    int i = 0
    while i < trimmings.length
        trimmings[i] = RemoveJsonExtension(trimmings[i])
        i += 1
    endWhile
    return trimmings
endFunction

string Function GetTrimmingFile(string areaName, string trimming)
    ;log("TrimmingsFolder: " + GetAreaFolder(areaName) + trimmingsFolder)
    return GetAreaFolder(areaName) + trimmingsFolder + trimming
endFunction

string function GetPresetsFolder(string areaName, bool relative = true)
    ;log("PresetsFolder: " + GetAreaFolder(areaName, relative) + growthPresetsFolder)
    return GetAreaFolder(areaName, relative) + growthPresetsFolder
endFunction

string[] Function GetPresetsNames(string areaName)
    string[] presets = JsonUtil.JsonInFolder(GetPresetsFolder(areaName))
    int i = 0
    while i < presets.length
        presets[i] = RemoveJsonExtension(presets[i])
        i += 1
    endWhile
    return presets
EndFunction

string Function GetPresetFilePath(string areaName, string presetName, bool relative = true)
    ;log("AreaPresetFile: " + GetAreaFolder(areaName, relative) + growthPresetsFolder)
    return GetPresetsFolder(areaName, relative) + presetName  
EndFunction

string Function GetActivePresetFile(string areaName, bool relative = true)
    string presetFile = GetPresetFilePath(areaName, Mcm.ActivePresets[GetAreaIndex(areaName)], relative)
    if (!relative)
        presetFile += ".json"
    endIf
    ;log("ActivePresetFile: " + presetFile)
    return presetFile
EndFunction

string Function GetConfigFile(string areaName)
    ;log("AreaConfigFile: " + GetAreaFolder(areaName) + "config")
    return GetAreaFolder(areaName) + "config"
EndFunction

string Function RemoveJsonExtension(string jsonFileName)
    if (StringUtil.Find(jsonFileName, ".json") > -1)
        return StringUtil.Substring(jsonFileName, 0, StringUtil.GetLength(jsonFileName) - 5)
    else
        return jsonFileName
    endIf
EndFunction

; Utilities
bool Function IsFemale()
    return Player.GetActorBase().GetSex() == 1
EndFunction

bool function IsDefaultOrEmptyTexture(string texturePath)
    return texturePath == "" || StringUtil.Find(texturePath, "efault.dds") > -1
EndFunction

function log(string in)
	MiscUtil.PrintConsole("Easy Body Hair: " + In)
EndFunction