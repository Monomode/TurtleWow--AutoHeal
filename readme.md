AutoHeal
===
An addon to manage your consumables for health and mana in Turtle WoW.  
---
* 2.0 hooks spell casts without needing macros at all
---
This addon uses consumes when you have enough mana missing and are in combat. This means considerably more available health/mana throughout a fight.  

Having to toggle settings on more than one spell when I wanted to change my consume use on the fly was quite painful. To that end this addon automatically hooks into casts to avoid macro use at all.
This is particularly useful for toggling mana potion use since on some bosses you don't care too much about potion cooldown.  

`/autoheal` to see in game settings, the current settings are:
* Toggle the addon being enabled
* Toggle whether to use consumes only in combat
* Choose the size of group you need to be in for the addon be active

Using a flask sets your mana to 2k, which means it's suitable as an (expensive) emergency potion.  
If enabled, Major Rejuvenation will be used instead of Major Mana if you're missing enough health to benefit from it. In practise this rarely results in the mana if gives being wasted, despite triggering from health.
