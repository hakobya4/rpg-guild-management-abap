@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quest Types - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZI_RPG_STAT_VH as select from I_Language
{

  @Search.defaultSearchElement: true
  key cast( 'STR'    as abap.char(20) ) as QuestStat,
      cast( 'Strenght'    as abap.char(30) ) as QuestStatType
}

union select from I_Language
{
  key cast( 'DEX'  as abap.char(20) ) as QuestStat,
      cast( 'Dexterity'  as abap.char(30) ) as QuestStatType
}

union select from I_Language
{
  key cast( 'CON' as abap.char(20) ) as QuestStat,
      cast( 'Constitution' as abap.char(30) ) as QuestStatType
}

union select from I_Language
{
  key cast( 'INT' as abap.char(20) ) as QuestStat,
      cast( 'Intelligence' as abap.char(30) ) as QuestStatType
}

union select from I_Language
{
  key cast( 'WIS' as abap.char(20) ) as QuestStat,
      cast( 'WISDOM' as abap.char(30) ) as QuestStatType
}

union select from I_Language
{
  key cast( 'CHA' as abap.char(20) ) as QuestStat,
      cast( 'Charisma' as abap.char(30) ) as QuestStatType
}
