@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'NPC Race - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_RPG_NPC_RACE_VH
  as select from I_Language
{
  @Search.defaultSearchElement: true
  key cast( 'HUMAN'      as abap.char(20) ) as NpcRace,
      cast( 'Human'      as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'ELF'        as abap.char(20) ) as NpcRace,
      cast( 'Elf'        as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'DWARF'      as abap.char(20) ) as NpcRace,
      cast( 'Dwarf'      as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'HALFLING'   as abap.char(20) ) as NpcRace,
      cast( 'Halfling'   as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'GNOME'      as abap.char(20) ) as NpcRace,
      cast( 'Gnome'      as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'HALF_ELF'   as abap.char(20) ) as NpcRace,
      cast( 'Half-Elf'   as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'HALF_ORC'   as abap.char(20) ) as NpcRace,
      cast( 'Half-Orc'   as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'ORC'        as abap.char(20) ) as NpcRace,
      cast( 'Orc'        as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'TIEFLING'   as abap.char(20) ) as NpcRace,
      cast( 'Tiefling'   as abap.char(30) ) as NpcRaceName
}

union select from I_Language
{
  key cast( 'DRAGONBORN' as abap.char(20) ) as NpcRace,
      cast( 'Dragonborn' as abap.char(30) ) as NpcRaceName
}
