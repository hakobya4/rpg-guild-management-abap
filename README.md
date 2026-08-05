# RPG Guild Managment SAP RAP Application

- This application uses the ABAP RESTful Application Programming Model to develop a web application that lets user create and manage their dnd adventurer.
- This app lets users create an adventurer with a class, join a guild, accept and complete quests, earn gold and xp to level up, buy and sell items from a marketplace.
- It uses Eclipse and SAP Business Technology Platform to create a RESTful application with all the best practices including test classes that validate the functionalities of the app.
- Uses OData V4 - UI, a standardized, REST-based protocol for building and consuming APIs.
-Started as a basic CRUD app but I kept adding to it as I learned more of the framework - it now also has procedural generation, an AMDP written in SQLScript, and a real call out to an AI API from ABAP.

Stack: ABAP RAP (managed + unmanaged BOs) · CDS views/annotations · AMDP (SQLScript) · OData V4 · Fiori Elements · ABAP HTTP client / external REST integration

## Table of Contents
- [Features](#Features)
- [Screenshots](#Screenshots)
- [Technical_Requirements](#Technical_Requirements)
- [Dependencies](#Dependencies)

## Features
### Adventurers

- Create an adventurer with a class and 6 D&D-style ability scores (Strength, Dexterity, Constitution, Intelligence, Wisdom, Charisma), rolled the classic way - 4d6, drop the lowest, per stat.
- Level up from XP, join and leave a guild.

### Quests

- Accept and complete quests. Completing one isn't guaranteed - it rolls a d20 plus a modifier based on whichever ability the quest cares about, against the quest's difficulty class, same as a D&D skill check.
- Quests can also be given by an NPC instead of picked up normally - an NPC's page shows the quests they've handed out.

### Marketplace and Inventory

-Buy and sell items. Items can give an adventurer stat bonuses, applied for real onto the adventurer's own stats the moment you buy them (and removed again if you sell your only copy).

### Loot

- Quests have their own separate loot pool (not the same items as the marketplace, though loot can be resold into the marketplace afterward).
- Finishing a quest has a chance to drop an item - 30% chance of any drop at all, then the rarity is rolled on its own odds. Higher-level quests shift those odds toward the rarer tiers instead of always being 60/25/10/5.
- There's an AMDP (SQLScript running directly in HANA) that calculates the drop-rate breakdown for a quest's loot pool, used by a "Preview Loot Odds" button so you can see the odds before you commit to a quest.

### NPCs (AI-generated)

- Pick a race and a role and an action calls out to Anthropic's Claude API over plain ABAP HTTP client classes and generates a name and a flavor-text description for the NPC. This was the hardest part to get working - had to figure out ABAP's HTTP client classes, JSON serialization, and how to keep the API key out of the code.

### Expeditions

- A group-quest version where multiple adventurers can join a party for the same quest. Built this one fully unmanaged (no framework-generated CRUD) to learn how RAP behaves without the managed scaffolding doing everything for you.

### General

- Value helps, validations, and determinations throughout so the UI guides you toward valid input instead of just rejecting it after the fact.
- Draft-enabled where it made sense (Fiori's edit-in-progress pattern), plain CRUD where it didn't.
- Test classes for the core quest logic.


## Screenshots

<img width="400" height="250" alt="Adventurers" src="https://github.com/user-attachments/assets/b332cabb-0773-4764-b6b7-2688e4bc54f9"/>
<img width="400" height="250" alt="Adventurer" src="https://github.com/user-attachments/assets/ff43fc3f-2e2c-4222-8469-08adfad8d0f2" />
<img width="400" height="250" alt="Classes" src="https://github.com/user-attachments/assets/39850a48-6c1b-42ed-bf68-2f6e52e6057d" />
<img width="400" height="250" alt="Creating Quests" src="https://github.com/user-attachments/assets/85deac78-1675-4368-b92b-1c7b025aad32"/>
<img width="400" height="250" alt="Available Quests" src="https://github.com/user-attachments/assets/dcebd141-56a3-451a-941e-5819296588d8" />
<img width="400" height="250" alt="My Quests"  src="https://github.com/user-attachments/assets/6f29ab1e-3368-4554-99ea-f9d3a5bc45fe" />
<img width="400" height="250" alt="AI Generated Quest" src="https://github.com/user-attachments/assets/24c48e0f-cdf3-40bb-8ec3-1328d2d549a6" />
<img width="400" height="250" alt="Buy Potion" src="https://github.com/user-attachments/assets/5ab44151-4719-402a-a6a0-641294dc8f19" />
<img width="400" height="250" alt="Inventory and Marketplace" src="https://github.com/user-attachments/assets/07997dbe-fbaa-49dd-95ad-64f06d75565b" />
<img  width="400" height="250" alt="Generate NPC AI" src="https://github.com/user-attachments/assets/78a401ad-b14b-48bb-a1c7-c7430fcf7cac" />
<img width="400" height="250" alt="NPCs" src="https://github.com/user-attachments/assets/38fa327d-93c0-4d40-9dbe-bf94c078a0db" />
<img width="400" height="250" alt="No input error quest" src="https://github.com/user-attachments/assets/cb02b24c-6a9f-416a-933c-72b22d407611" />

## Technical_Requirements
- Works on Eclipse if the user has a SAP BTP account.
- Handles exceptions or errors that arise during user input.
- Provides an easy-to-use interface, supported by simple forms of input and concise, easy-to-follow instructions.
- The AI features need an Anthropic API key configured on the BTP side - it's read from a plain internal table at runtime, never hardcoded, so it's safe to check this repo in publicly.

## Dependencies
- A SAP BTP account with an ABAP Environment instance (I've been building this against a trial system).
- Eclipse with the ABAP Development Tools (ADT) plugin installed.
abapGit, to actually get this code into your own system - that's how this repo is structured.
- An Anthropic API key if you want the NPC generation feature to work (everything else runs without it).


