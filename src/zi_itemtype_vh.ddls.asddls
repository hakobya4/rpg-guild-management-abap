@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Adventurer Classes - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_ITEMTYPE_VH
  as select from I_Language
{
  @Search.defaultSearchElement: true
  key cast( 'WEAPON' as abap.char(20) ) as ItemType,
      cast( 'weapon' as abap.char(30) ) as ItemTypeName
}

union select from I_Language
{
  key cast( 'ARMOR' as abap.char(20) ) as ItemType,
      cast( 'armor' as abap.char(30) ) as ItemTypeName
}

union select from I_Language
{
  key cast( 'CONSUMABLE' as abap.char(20) ) as ItemType,
      cast( 'consumable' as abap.char(30) ) as ItemTypeName
}
union select from I_Language
{
  key cast( 'MAGIC ITEM' as abap.char(20) ) as ItemType,
      cast( 'magic item' as abap.char(30) ) as ItemTypeName
}

union select from I_Language
{
  key cast( 'MISCELLANEOUS' as abap.char(20) ) as ItemType,
      cast( 'miscellaneous' as abap.char(30) ) as ItemTypeName
}

