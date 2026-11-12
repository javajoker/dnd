---
pack_id: starter_two
pack_type: campaign
name: The Ferryman's Debt
source_locale: en
recommended_level: [1, 2]
start: {"gold": 15, "items": [{"item": "potion", "n": 1}]}
balance: {"act_level": {"F1": 1}}
default_party: ["hero", "ally"]
---
<!-- New-campaign template for a game built from the starter kit (uses the kit's hero, ally, bandit,
     wolf, scout and potion). Copy kit/starter's design files (characters / enemies / items / skills)
     next to the output, then import into it. -->

# ACT F1: The Ferryman's Debt | role: Starter

## F-1 scene: The Ferry Landing
The ferryman will not cross until his debt is paid, and the men he owes are camped on the far bank.
- choice "Wade across at the ford" -> F-2
- choice "Pay him with your last coins" -> F-3 [do gold -10]

## F-2 check: The Ford
The river is high and the stones are slick.
- check athletics easy "Cross the ford" -> F-3 | fail F-4 [fail_do clock +1]

## F-3 battle: The Creditors' Camp
Two hired blades and their scout are counting someone else's money.
> encounter: easy | enemies bandit x2, scout | xp 60 | gold 12
- choice "Take the ledger" -> F-5 [do write debt_cleared]

## F-4 battle: Wolves on the Bank
You come out of the water downstream, where the wolves drink.
> encounter: easy | enemies wolf x2 | xp 40
- choice "Walk back to the landing" -> F-3

## F-5 ending: A Free Crossing
The ferryman tears the page out of the ledger and poles you across for nothing.
> ending: default
