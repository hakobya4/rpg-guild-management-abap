@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Rarity - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true

define view entity ZI_RPG_RARITY_VH
  as select from I_Language
{
  @Search.defaultSearchElement: true
  key cast( 'COMMON'    as abap.char(20) ) as Rarity,
      cast( 'Common'    as abap.char(30) ) as RarityName
}

union select from I_Language
{
  key cast( 'UNCOMMON'  as abap.char(20) ) as Rarity,
      cast( 'Uncommon'  as abap.char(30) ) as RarityName
}

union select from I_Language
{
  key cast( 'RARE'      as abap.char(20) ) as Rarity,
      cast( 'Rare'      as abap.char(30) ) as RarityName
}

union select from I_Language
{
  key cast( 'LEGENDARY' as abap.char(20) ) as Rarity,
      cast( 'Legendary' as abap.char(30) ) as RarityName
}
