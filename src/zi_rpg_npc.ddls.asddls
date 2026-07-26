@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inteface for npc table'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RPG_NPC
  as select from zrpg_npc
association [0..*] to ZI_RPG_QUEST as _Quest on _Quest.NpcId = $projection.NpcId
{
  key npc_id                as NpcId,
      npc_name              as NpcName,
      npc_race              as NpcRace,
      npc_role              as NpcRole,
      flavor_text           as FlavorText,
      count(distinct _Quest.QuestId) as NumberOfQuests,
      

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

      _Quest
}
group by
    npc_id,
    npc_name,
    npc_race,
    npc_role,
    flavor_text,
    created_at,
    created_by,
    last_changed_at,
    last_changed_by,
    local_last_changed_at

