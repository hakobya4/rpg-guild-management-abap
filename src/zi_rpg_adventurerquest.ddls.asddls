@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RPG Adventurer Quest Log'
@Metadata.allowExtensions: true
define root view entity ZI_RPG_AdventurerQuest
  as select from zrpg_adv_quest
  association [1..1] to ZI_RPG_Adventurer as _Adventurer
    on $projection.AdventurerUUID = _Adventurer.AdventurerUUID
  association [1..1] to ZI_RPG_Quest as _Quest
    on $projection.QuestUUID = _Quest.QuestUUID
{
  key adv_quest_uuid as AdvQuestUUID,
      adventurer_uuid as AdventurerUUID,
      quest_uuid      as QuestUUID,
      quest_status    as QuestStatus,
      accepted_at     as AcceptedAt,
      completed_at    as CompletedAt,
      reward_claimed  as RewardClaimed,
      xp_granted      as XPGranted,
      created_at      as CreatedAt,
      created_by      as CreatedBy,
      last_changed_at as LastChangedAt,
      last_changed_by as LastChangedBy,
      _Adventurer,
      _Quest
}
