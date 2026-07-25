@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inteface for npc table'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_RPG_NPC
  as select from zrpg_npc
  association [0..*] to ZI_RPG_QUEST as _Quest on _Quest.QuestTypeName = 'NPC'
{
  key npc_id                as NpcId,
      npc_name              as NpcName,
      npc_race              as NpcRace,
      npc_role              as NpcRole,
      flavor_text           as FlavorText,
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
