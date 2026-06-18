@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG - Item Subtype Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel.dataCategory: #VALUE_HELP
// Fixed catalogue of valid (ItemType, ItemSubtype) pairs.
// ItemType is exposed so the marketplace value help can filter
// subtypes by the currently selected type (cascading value help).
define view entity ZI_ItemSubtype_VH
  as select from I_Language
{
      @Search.defaultSearchElement: true

  key cast( 'WEAPON'     as abap.char(20) ) as ItemType,
  key cast( 'LONGSWORD'  as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'WEAPON'     as abap.char(20) ) as ItemType,
  key cast( 'DAGGER'     as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'WEAPON'     as abap.char(20) ) as ItemType,
  key cast( 'GREATAXE'   as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'WEAPON'     as abap.char(20) ) as ItemType,
  key cast( 'BOW'        as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'ARMOR'      as abap.char(20) ) as ItemType,
  key cast( 'SHIELD'     as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'ARMOR'      as abap.char(20) ) as ItemType,
  key cast( 'PLATE'      as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'ARMOR'      as abap.char(20) ) as ItemType,
  key cast( 'LEATHER'    as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'CONSUMABLE' as abap.char(20) ) as ItemType,
  key cast( 'POTION'     as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'CONSUMABLE' as abap.char(20) ) as ItemType,
  key cast( 'SCROLL'     as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'MAGIC ITEM' as abap.char(20) ) as ItemType,
  key cast( 'WAND'       as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'MAGIC ITEM' as abap.char(20) ) as ItemType,
  key cast( 'RING'       as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'MAGIC ITEM' as abap.char(20) ) as ItemType,
  key cast( 'AMULET'     as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'MISCELLANEOUS' as abap.char(20) ) as ItemType,
  key cast( 'ROPE'          as abap.char(30) ) as ItemSubtype
}
union select from I_Language
{
  key cast( 'MISCELLANEOUS' as abap.char(20) ) as ItemType,
  key cast( 'TORCH'         as abap.char(30) ) as ItemSubtype
}
