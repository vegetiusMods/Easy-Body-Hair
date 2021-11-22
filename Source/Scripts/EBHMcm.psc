Scriptname EBHMcm extends SKI_ConfigBase

;Properties
EBHQuest Property MainQuest Auto
string property UpdateType auto Hidden
bool Property IsGlobalDaysForGrowth = true Auto Hidden
bool Property IsProgressiveGrowthInterval = true Auto Hidden
int property DaysForGrowthGlobal = 2 auto Hidden
string[] Property ActivePresets Auto Hidden
int[] Property AreasDaysForGrowth Auto Hidden
string Property Version = "1.X" Auto Hidden

;Variables
string[] oldSelectedPresets
int[] desiredAreasStages
int[] oldAreasStages

string[] updateTypes
int selectedUpdateTypeIndex
int oldSelectedUpdateTypeIndex

;IDS
int IdModActive
int idClean
int idRefresh
int IdUpdateType
int IdDaysForGrowthGlobal
int IdUseDaysForGrowthGlobal
int IdProgressiveGrowthInterval

int IdAreaPreset
int IdAreaStage
int IdMaxAreaStage
int IdAreaDaysForGrowth

; Constants
string generalPage = "General"
int maxDaysForGrowth = 30 ;Arbitrary

; Navigation
string CurrentArea
int CurrentAreaIndex
string[] CurrentPresets

event OnConfigInit()
	Utility.Wait(2.0)

    updateTypes = new string[2]
    updateTypes[0] = "On Sleep"
    updateTypes[1] = "Daily"
    selectedUpdateTypeIndex = 0
endEvent

event OnConfigOpen()
	AreasDaysForGrowth = Utility.CreateIntArray(MainQuest.AreasCount)
	oldSelectedPresets = Utility.CreateStringArray(MainQuest.AreasCount)
	oldAreasStages = Utility.CreateIntArray(MainQuest.AreasCount)
	desiredAreasStages = Utility.CreateIntArray(MainQuest.AreasCount)
	Pages = Utility.CreateStringArray(MainQuest.AreasCount as int + 1)
	Pages[0] = generalPage
	int i = 0
	while i < MainQuest.AreasCount
		Pages[i + 1] = MainQuest.Areas[i]
		oldSelectedPresets[i] = ActivePresets[i]
		oldAreasStages[i] = MainQuest.GetZoneStage(i)
		desiredAreasStages[i] = oldAreasStages[i]
		i += 1
	endWhile
endEvent

event OnConfigClose()
	int i =0
	while i < MainQuest.AreasCount
		if oldAreasStages[i] != desiredAreasStages[i]
			MainQuest.HandleZoneStageChange(MainQuest.Areas[i], desiredAreasStages[i])
		elseIf oldSelectedPresets[i] != ActivePresets[i]
			MainQuest.HandlePresetChange(i)
		endIf
		i += 1
	endWhile
endEvent

Event OnPageReset(String Page)
	if Page == "" || Page == generalPage
		GeneralPage()
	Else
		AreaPage(Page)
	endif
endEvent

Function GeneralPage()
	int modActiveFlags = 0
	if (MainQuest.ErrorState)
		modActiveFlags = OPTION_FLAG_DISABLED
	endIf
	IdModActive = AddToggleOption("Mod active", MainQuest.Started, modActiveFlags)
	AddTextOptionST("Clean", "Clean", "Click")
	IdUpdateType = AddMenuOption("Update type", GetUpdateType())
	AddTextOptionST("Refresh", "Refresh", "Click")
	IdUseDaysForGrowthGlobal = AddToggleOption("Global growth interval", IsGlobalDaysForGrowth)
	AddTextOptionST("Reset", "Reset", "Click")
	IdProgressiveGrowthInterval = AddToggleOption("Progressive growth interval", IsProgressiveGrowthInterval)
	AddEmptyOption()
	IdDaysForGrowthGlobal = AddSliderOption("Growth stage interval", DaysForGrowthGlobal, "{0} days") ; Nothing to do
EndFunction

Function AreaPage(string areaName)
	CurrentArea = areaName
	CurrentAreaIndex = MainQuest.GetAreaIndex(areaName)

	int activePresetFlags = 0
	if (MainQuest.AreasPresetsCount[CurrentAreaIndex] < 2)
		activePresetFlags = OPTION_FLAG_DISABLED
	endIf
	IdAreaPreset = AddMenuOption("Preset", ActivePresets[CurrentAreaIndex], activePresetFlags)
	IdMaxAreaStage = AddTextOption("Stages range", "[0 - " + MainQuest.AreaMaxStage[currentAreaIndex] + "]", OPTION_FLAG_DISABLED)
	IdAreaStage = AddSliderOption("Current stage", MainQuest.GetZoneStage(areaName)) ; Update stage & overlay on change
	AddEmptyOption()
	int daysForGrowthFlags = 0
	if (IsGlobalDaysForGrowth)
		daysForGrowthFlags = OPTION_FLAG_HIDDEN
	endIf
	IdAreaDaysForGrowth =  AddSliderOption("Growth stage interval", AreasDaysForGrowth[CurrentAreaIndex], "{0} days", daysForGrowthFlags)
EndFunction

Event OnOptionHighlight(int option)
	If (Option == IdModActive)
		SetInfoText("Starts/Stops the mod.")
	EndIf 
	If (Option == IdAreaPreset)
		SetInfoText("Selected the area hair preset to use. Mod will auto refresh on change.")
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
	If (Option == IdUseDaysForGrowthGlobal)
		SetInfoText("Check to use a single interval for all body areas, uncheck to set an interval individually for each area.")
	EndIf 
	If (Option == IdProgressiveGrowthInterval)
		SetInfoText("If checked, for each stage the interval for growth will be increased by your current stage (Interval = Base Value + Current Stage).")
	EndIf 
	If (Option == IdDaysForGrowthGlobal && IdAreaDaysForGrowth)
		SetInfoText("Number of days between each growth stage. Does not impact performance, so set to your liking.")
	EndIf 
	If (Option == IdAreaStage)
		SetInfoText("Manually change the growth stage. Mod will auto refresh on change.")
	EndIf 
	If (Option == IdMaxAreaStage)
		SetInfoText("Just informs you of the number of the range of possible stages for the area.")
	EndIf 
EndEvent

state Clean
	event OnSelectST()
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
state Reset
	event OnSelectST()
		Debug.MessageBox("The mod will reset once you exit the menu.")
		MainQuest.HandleReset()
	endEvent
	event OnHighlightST()
		SetInfoText("Reset everything related to mod and restart it, you should use this if things are messed up.")
	endEvent
endState


Event OnOptionSelect(Int OptionID)
	If (OptionID == IdModActive)
		MainQuest.HandleModStateChange()
		SetToggleOptionValue(IdModActive, MainQuest.Started)
	ElseIf OptionID == IdUseDaysForGrowthGlobal
		IsGlobalDaysForGrowth = !IsGlobalDaysForGrowth
		SetToggleOptionValue(IdUseDaysForGrowthGlobal, IsGlobalDaysForGrowth)
	ElseIf OptionID == IdProgressiveGrowthInterval
		IsProgressiveGrowthInterval = !IsProgressiveGrowthInterval
		SetToggleOptionValue(IdProgressiveGrowthInterval, IsProgressiveGrowthInterval)
	EndIf
EndEvent

Event OnOptionMenuOpen(int option)
	If (option == IdUpdateType)
		oldSelectedUpdateTypeIndex = selectedUpdateTypeIndex
		SetMenuDialogOptions(updateTypes)
		SetMenuDialogDefaultIndex(selectedUpdateTypeIndex)
	ElseIf (option == IdAreaPreset)
		CurrentPresets = MainQuest.GetPresetsNames(CurrentArea)
		SetMenuDialogOptions(CurrentPresets)
		SetMenuDialogDefaultIndex(0)
	EndIf
EndEvent

Event OnOptionMenuAccept(int option, int index)
	If (option == IdUpdateType && index != oldSelectedUpdateTypeIndex && index != -1)
		selectedUpdateTypeIndex = index
		SetMenuOptionValue(IdUpdateType, GetUpdateType())
		MainQuest.HandleUpdateTypeChange()
	ElseIf (option == IdAreaPreset && index != -1)
		ActivePresets[CurrentAreaIndex] = CurrentPresets[index]
		SetMenuOptionValue(IdAreaPreset, ActivePresets[CurrentAreaIndex])
	EndIf
EndEvent

Event OnOptionSliderOpen(int OptionID)
	If OptionID == IdDaysForGrowthGlobal
		SetSliderOptions(Value = DaysForGrowthGlobal, Default = 2, Min = 0, Max = maxDaysForGrowth, Interval = 1)
	ElseIf OptionID == IdAreaDaysForGrowth
		SetSliderOptions(Value = AreasDaysForGrowth[CurrentAreaIndex], Default = 2, Min = 0, Max = maxDaysForGrowth, Interval = 1)
	ElseIf OptionID == IdAreaStage
		SetSliderOptions(Value = MainQuest.GetAreaStageIx(CurrentAreaIndex), Default = oldAreasStages[CurrentAreaIndex], Min = 0, Max = MainQuest.GetMaxZoneStageIx(CurrentAreaIndex), Interval = 1)
	EndIf
EndEvent

Event OnOptionSliderAccept(int option, float value)
	If (option == IdDaysForGrowthGlobal)
		DaysForGrowthGlobal = value as int
		SetSliderOptionValue(IdDaysForGrowthGlobal, value, "{0} days")
	ElseIf (option == IdAreaDaysForGrowth)
		AreasDaysForGrowth[CurrentAreaIndex] = value as int
		SetSliderOptionValue(IdAreaDaysForGrowth, AreasDaysForGrowth[CurrentAreaIndex], "{0} days")
	ElseIf (option == IdAreaStage)
		desiredAreasStages[CurrentAreaIndex] = value as int
		SetSliderOptionValue(IdAreaStage, desiredAreasStages[CurrentAreaIndex])
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