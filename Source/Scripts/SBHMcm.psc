Scriptname SBHMcm extends SKI_ConfigBase

;Properties
SBHQuest Property MainQuest Auto
string property UpdateType auto
int property DaysForGrowth = 2 auto
string Property ActivePreset Auto

;Variables
string oldSelectedPreset
string[] updateTypes
int selectedUpdateTypeIndex
int oldSelectedUpdateTypeIndex
int desiredArmpitsStage
int desiredPubesStage
int oldArmpitsStage
int oldPubesStage

;IDS
int IdModActive
int idClean
int idRefresh
int IdPreset
int IdUpdateType
int IdDaysForGrowth
int IdArmpitsStage
int IdPubesStage
int IdMaxArmpitsStage
int IdMaxPubesStage

; Constants
string generalPage = "General"

event OnConfigInit()
	Pages = new String[3]
	Pages[0] = generalPage
	Pages[1] = MainQuest.Armpits
	Pages[2] = MainQuest.Pubes

    updateTypes = new string[2]
    updateTypes[0] = "On Sleep"
    updateTypes[1] = "Daily"
    selectedUpdateTypeIndex = 0
endEvent

event OnConfigOpen()
	oldSelectedPreset = ActivePreset
	oldArmpitsStage = MainQuest.GetZoneStage(MainQuest.Armpits)
	oldPubesStage = MainQuest.GetZoneStage(MainQuest.Pubes)
	desiredArmpitsStage = oldArmpitsStage
	desiredPubesStage = oldPubesStage
endEvent

event OnConfigClose()
	if oldArmpitsStage != desiredArmpitsStage
		MainQuest.HandleZoneStageChange(MainQuest.Armpits, desiredArmpitsStage)
	endif
	if oldPubesStage != desiredPubesStage
		MainQuest.HandleZoneStageChange(MainQuest.Pubes, desiredPubesStage)
	endif
	if oldPubesStage == desiredPubesStage && oldPubesStage == desiredPubesStage && oldSelectedPreset != ActivePreset
		MainQuest.HandlePresetChange()
	endIf
endEvent

Event OnPageReset(String Page)
	; if Page = "Ge"
	
	; IdPreset = AddMenuOption("Preset", ActivePreset, activePresetFlags) ; WHAT TO DO ?
	; AddTextOptionST("Clean", "Clean", "Click")
	; IdUpdateType = AddMenuOption("Update type", GetUpdateType()) ; Restart the mod on change
	; AddTextOptionST("Refresh", "Refresh", "Click")
    ; IdDaysForGrowth = AddSliderOption("Growth stage interval", DaysForGrowth, "{0} days") ; Nothing to do
    ; AddEmptyOption()
    ; AddEmptyOption()
	; IdMaxArmpitsStage = AddTextOption("Max armpits stages", MainQuest.ArmpitsMaxStage, OPTION_FLAG_DISABLED)
	; IdArmpitsStage = AddSliderOption("Current armpits stage", MainQuest.GetZoneStage(MainQuest.Armpits)) ; Update stage & overlay on change
	; IdMaxPubesStage = AddTextOption("Max pubes stages", MainQuest.PubesMaxStage, OPTION_FLAG_DISABLED)
	; IdPubesStage = AddSliderOption("Current pubes stage", MainQuest.GetZoneStage(MainQuest.Pubes))  ; Update stage & overlay on change
endEvent

Function GeneralPage()
	int modActiveFlags = 0
	if (MainQuest.ErrorState)
		modActiveFlags = OPTION_FLAG_DISABLED
	endIf
	IdModActive = AddToggleOption("Mod active", MainQuest.Started, modActiveFlags)
	int activePresetFlags = 0
	if (MainQuest.Presets.Length > 1)
		activePresetFlags = OPTION_FLAG_DISABLED
	endIf
EndFunction

Function ArmpitsPage()

EndFunction

Function PubesPage()

EndFunction

Event OnOptionHighlight(int option)
	If (Option == IdModActive)
		SetInfoText("Starts/Stops the mod.")
	EndIf 
	If (Option == IdPreset)
		SetInfoText("Selected the body hair preset to use. Mod will auto refresh on change.")
	EndIf 
	If (Option == IdClean)
		SetInfoText("Remove overlays and reset growth stages. Does not stop the mod.")
	EndIf 
	If (Option == IdRefresh)
		SetInfoText("Force refreshing the overlays. Please only use if you notice an anomaly, every MCM setting change will cause the mod to auto refresh if needed.")
	EndIf 
	If (Option == IdUpdateType)
		SetInfoText("Select the hair growth update type. On Sleep updates each time the PC wakes up, Daily forces a daily update. On Sleep is recommended, but you might want to use daily if you have a lot of mods triggering on sleep or you don't use any mod that forces you to sleep regularly.")
	EndIf 
	If (Option == IdDaysForGrowth)
		SetInfoText("Number of days between each growth stage. Does not impact performance, so set to your liking.")
	EndIf 
	If (Option == IdArmpitsStage)
		SetInfoText("Manually change the Armpits growth stage. Mod will auto refresh on change.")
	EndIf 
	If (Option == IdPubesStage)
		SetInfoText("Manually change the Armpits growth stage. Mod will auto refresh on change.")
	EndIf 
	If (Option == IdMaxArmpitsStage)
		SetInfoText("Informs you of the number of known armpits stages.")
	EndIf 
	If (Option == IdMaxPubesStage)
		SetInfoText("Informs you of the number of known pubes stages.")
	EndIf 
EndEvent

state Clean
	event OnSelectST()
		SetSliderOptionValue(IdArmpitsStage, 0)
		SetSliderOptionValue(IdPubesStage, 0)
		MainQuest.HandleClean()
	endEvent
	event OnHighlightST()
		SetInfoText("Remove overlays and reset growth stages. Does not stop the mod.")
	endEvent
endState
state Refresh
	event OnSelectST()
		Debug.MessageBox("The overlays will refresh once you exit the menu.")
		MainQuest.HandleRefresh()
	endEvent
	event OnHighlightST()
		SetInfoText("Force refreshing the overlays.")
	endEvent
endState

Event OnOptionSelect(Int OptionID)
	If (OptionID == IdModActive)
		MainQuest.HandleModStateChange()
		SetToggleOptionValue(IdModActive, MainQuest.Started)
	ElseIf (OptionID == IdClean)
		MainQuest.HandleClean()
	ElseIf (OptionID == idRefresh)
		MainQuest.HandleRefresh()
	EndIf
EndEvent

Event OnOptionMenuOpen(int option)
	If (option == IdUpdateType)
		oldSelectedUpdateTypeIndex = selectedUpdateTypeIndex
		SetMenuDialogOptions(updateTypes)
		SetMenuDialogDefaultIndex(selectedUpdateTypeIndex)
	ElseIf (option == IdPreset)
		SetMenuDialogOptions(MainQuest.Presets)
		SetMenuDialogDefaultIndex(0)
	EndIf
EndEvent

Event OnOptionMenuAccept(int option, int index)
	If (option == IdUpdateType && index != oldSelectedUpdateTypeIndex && index != -1)
		selectedUpdateTypeIndex = index
		SetMenuOptionValue(IdUpdateType, GetUpdateType())
		MainQuest.HandleUpdateTypeChange()
	ElseIf (option == IdPreset && index != -1)
		ActivePreset = MainQuest.Presets[index]
		SetMenuOptionValue(IdPreset, ActivePreset)
	EndIf
EndEvent

Event OnOptionSliderOpen(int OptionID)
	If OptionID == IdDaysForGrowth
		SetSliderOptions(Value = DaysForGrowth, Default = 2, Min = 0, Max = 30, Interval = 1)
	ElseIf OptionID == IdArmpitsStage
		SetSliderOptions(Value = desiredArmpitsStage, Default = oldArmpitsStage, Min = 0, Max = MainQuest.ArmpitsMaxStage, Interval = 1)
	ElseIf OptionID == IdPubesStage
		SetSliderOptions(Value = desiredPubesStage, Default = oldPubesStage, Min = 0, Max = MainQuest.PubesMaxStage, Interval = 1)
	EndIf
EndEvent

Event OnOptionSliderAccept(int option, float value)
	If (option == IdDaysForGrowth)
		DaysForGrowth = value as int
		SetSliderOptionValue(IdDaysForGrowth, value, "{0} days")
	ElseIf (option == IdArmpitsStage)
		desiredArmpitsStage = value as int
		SetSliderOptionValue(IdArmpitsStage, value)
	ElseIf (option == IdPubesStage)
		desiredPubesStage = value as int
		SetSliderOptionValue(IdPubesStage, value)
	EndIf
EndEvent

; Getters

bool Function IsUpdateOnSleep()
	return selectedUpdateTypeIndex == 0
EndFunction

string Function GetUpdateType()
	return updateTypes[selectedUpdateTypeIndex]
EndFunction

; Utils

Function SetSliderOptions(Float Value, Float Default, Float Min, Float Max, Float Interval)
	SetSliderDialogStartValue(Value)
	SetSliderDialogDefaultValue(Default)
	SetSliderDialogRange(Min, Max)
	SetSliderDialogInterval(Interval)
EndFunction