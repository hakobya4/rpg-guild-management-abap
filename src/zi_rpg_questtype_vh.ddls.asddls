@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quest Types - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_RPG_QUESTTYPE_VH
  as select from I_Language
{
  @Search.defaultSearchElement: true
  key cast( 'COMBAT'    as abap.char(20) ) as QuestTypeName,
      cast( 'Combat'    as abap.char(30) ) as QuestTypeNames
}

union select from I_Language
{
  key cast( 'EXPLORATION'  as abap.char(20) ) as QuestTypeName,
      cast( 'exploration'  as abap.char(30) ) as QuestTypeNames
}

union select from I_Language
{
  key cast( 'MISCELLANEOUS' as abap.char(20) ) as QuestTypeName,
      cast( 'Miscellaneous' as abap.char(30) ) as QuestTypeNames
}
