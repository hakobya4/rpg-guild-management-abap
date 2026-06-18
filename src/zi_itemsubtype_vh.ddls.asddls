@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG - Item Subtype Value Help'

@Search.searchable: true
@ObjectModel.dataCategory: #VALUE_HELP

define view entity ZI_ItemSubtype_VH
  as select distinct from zrpg_marketplace
{
      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
  key item_subtype as ItemSubtype,

      item_type    as ItemType
}
where
  item_subtype is not initial
