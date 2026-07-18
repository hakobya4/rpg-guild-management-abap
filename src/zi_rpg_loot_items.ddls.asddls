@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Loot Item Catalog - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_RPG_LOOT_ITEMS
  as select from zrpg_loot_items
{
  key item_id               as ItemId,
      item_name             as ItemName,
      item_type             as ItemType,
      item_subtype          as ItemSubtype,
      item_rarity           as ItemRarity,
      description           as Description,
      required_level        as RequiredLevel,
      str_bonus             as StrBonus,
      dex_bonus             as DexBonus,
      con_bonus             as ConBonus,
      int_bonus             as IntBonus,
      wis_bonus             as WisBonus,
      cha_bonus             as ChaBonus,
      price                 as Price,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
