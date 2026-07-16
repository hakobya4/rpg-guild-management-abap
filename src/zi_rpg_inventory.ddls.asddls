@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View Entity Inventory'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RPG_INVENTORY
  as select from zrpg_inventory
  association [1..1] to ZI_RPG_ADVENTURER as _Adventurer on $projection.Adventurerid = _Adventurer.AdventurerId

{
  key inventory_id          as InventoryId,
      adventurerid          as Adventurerid,
      item_id               as ItemId,
      item_name             as ItemName,
      item_type             as ItemType,
      item_subtype          as ItemSubtype,
      description           as Description,
      required_level        as RequiredLevel,
      str_bonus             as StrBonus,
      dex_bonus             as DexBonus,
      con_bonus             as ConBonus,
      int_bonus             as IntBonus,
      wis_bonus             as WisBonus,
      cha_bonus             as ChaBonus,
      price                 as Price,
      amount                as Amount,
      created_at            as CreatedAt,
      created_by            as CreatedBy,
      last_changed_at       as LastChangedAt,
      last_changed_by       as LastChangedBy,
      local_last_changed_at as LocalLastChangedAt,
      _Adventurer
}
