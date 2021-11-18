Scriptname SBHShavingCream extends activemagiceffect  

SBHQuest Property MainQuest Auto
Potion Property ShavingCream Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    if(!MainQuest.Shave(akCaster))
        akCaster.AddItem(ShavingCream, abSilent = True)
    endIf
EndEvent