@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'NPC Role - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZI_RPG_NPCROLE_VH
  as select from I_Language
{
  @Search.defaultSearchElement: true
  key cast( 'BLACKSMITH'  as abap.char(20) ) as NpcRole,
      cast( 'Blacksmith'  as abap.char(30) ) as NpcRoleName
}
union select from I_Language
{
  key cast( 'INNKEEPER'   as abap.char(20) ) as NpcRole,
      cast( 'Innkeeper'   as abap.char(30) ) as NpcRoleName
}
union select from I_Language
{
  key cast( 'QUEST_GIVER' as abap.char(20) ) as NpcRole,
      cast( 'Quest Giver' as abap.char(30) ) as NpcRoleName
}
union select from I_Language
{
  key cast( 'MERCHANT'    as abap.char(20) ) as NpcRole,
      cast( 'Merchant'    as abap.char(30) ) as NpcRoleName
}
union select from I_Language
{
  key cast( 'GUARD'       as abap.char(20) ) as NpcRole,
      cast( 'Guard'       as abap.char(30) ) as NpcRoleName
}
union select from I_Language
{
  key cast( 'SAGE'        as abap.char(20) ) as NpcRole,
      cast( 'Sage'        as abap.char(30) ) as NpcRoleName
}
union select from I_Language
{
  key cast( 'STRANGER'    as abap.char(20) ) as NpcRole,
      cast( 'Mysterious Stranger' as abap.char(30) ) as NpcRoleName
}
union select from I_Language
{
  key cast( 'VILLAIN'    as abap.char(20) ) as NpcRole,
      cast( 'Villain' as abap.char(30) ) as NpcRoleName
}
