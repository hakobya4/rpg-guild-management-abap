@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Adventurer Classes - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_RPG_CLASS_VH
  as select from I_Language
{
  @Search.defaultSearchElement: true
  key cast( 'BARBARIAN' as abap.char(20) ) as AdventurerClass,
      cast( 'Barbarian' as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'BARD'      as abap.char(20) ) as AdventurerClass,
      cast( 'Bard'      as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'CLERIC'    as abap.char(20) ) as AdventurerClass,
      cast( 'Cleric'    as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'DRUID'     as abap.char(20) ) as AdventurerClass,
      cast( 'Druid'     as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'FIGHTER'   as abap.char(20) ) as AdventurerClass,
      cast( 'Fighter'   as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'MONK'      as abap.char(20) ) as AdventurerClass,
      cast( 'Monk'      as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'PALADIN'   as abap.char(20) ) as AdventurerClass,
      cast( 'Paladin'   as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'RANGER'    as abap.char(20) ) as AdventurerClass,
      cast( 'Ranger'    as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'ROGUE'     as abap.char(20) ) as AdventurerClass,
      cast( 'Rogue'     as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'SORCERER'  as abap.char(20) ) as AdventurerClass,
      cast( 'Sorcerer'  as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'WARLOCK'   as abap.char(20) ) as AdventurerClass,
      cast( 'Warlock'   as abap.char(30) ) as AdventurerClassName
}

union select from I_Language
{
  key cast( 'WIZARD'    as abap.char(20) ) as AdventurerClass,
      cast( 'Wizard'    as abap.char(30) ) as AdventurerClassName
}
