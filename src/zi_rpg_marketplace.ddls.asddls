@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View Entity Marketplace Table'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RPG_MARKETPLACE
  as select from zrpg_marketplace
  association [0..*] to ZI_RPG_ADVENTURER as _Adventurer on $projection.AdventurerId = _Adventurer.AdventurerId

{

  key       item_id               as ItemId,
            adventurerid          as AdventurerId,
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
            amount_available      as AmountAvailable,
            status                as Status,

            @Semantics.systemDateTime.createdAt: true
            created_at            as CreatedAt,
            @Semantics.user.createdBy: true
            created_by            as CreatedBy,
            @Semantics.systemDateTime.lastChangedAt: true
            last_changed_at       as LastChangedAt,
            @Semantics.user.lastChangedBy: true
            last_changed_by       as LastChangedBy,
            @Semantics.systemDateTime.localInstanceLastChangedAt: true
            local_last_changed_at as LocalLastChangedAt,

            _Adventurer
}
