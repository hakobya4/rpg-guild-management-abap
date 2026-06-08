  CLASS lhc_adventurerquest DEFINITION INHERITING FROM cl_abap_behavior_handler.
    PRIVATE SECTION.
      " Determination: fills default values when quest log records are created/modified.
      METHODS setDefaults FOR DETERMINE ON MODIFY
        IMPORTING keys FOR AdventurerQuest~setDefaults.

      " Validation: checks that the adventurer is high enough level for the quest.
      METHODS validateLevelRequirement FOR VALIDATE ON SAVE
        IMPORTING keys FOR AdventurerQuest~validateLevelRequirement.

      " Validation: prevents the same adventurer from accepting the same quest twice.
      METHODS validateDuplicateQuest FOR VALIDATE ON SAVE
        IMPORTING keys FOR AdventurerQuest~validateDuplicateQuest.

      " Action: marks a quest log as accepted.
      METHODS acceptQuest FOR MODIFY
        IMPORTING keys FOR ACTION AdventurerQuest~acceptQuest RESULT result.

      " Action: marks an accepted quest as completed and grants XP.
      METHODS completeQuest FOR MODIFY
        IMPORTING keys FOR ACTION AdventurerQuest~completeQuest RESULT result.

      " Action: marks the reward as claimed after quest completion.
      METHODS claimReward FOR MODIFY
        IMPORTING keys FOR ACTION AdventurerQuest~claimReward RESULT result.
  ENDCLASS.

  CLASS lhc_adventurerquest IMPLEMENTATION.
    METHOD setDefaults.
      " Read the quest log instances currently being processed by RAP.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        FIELDS ( AdvQuestUUID QuestStatus RewardClaimed XPGranted )
        WITH CORRESPONDING #( keys )
        RESULT DATA(quest_logs).

      " Update only the default-related fields in the RAP transaction buffer.
      MODIFY ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        UPDATE FIELDS ( QuestStatus RewardClaimed XPGranted )
        WITH VALUE #(
          FOR quest_log IN quest_logs
          " %tky is RAP's technical key for the current entity instance.
          ( %tky = quest_log-%tky
            " Keep existing values if present; otherwise apply safe RPG defaults.
            QuestStatus = COND #( WHEN quest_log-QuestStatus IS INITIAL THEN 'NEW' ELSE quest_log-QuestStatus )
            RewardClaimed = COND #( WHEN quest_log-RewardClaimed IS INITIAL THEN abap_false ELSE quest_log-RewardClaimed )
            XPGranted = COND #( WHEN quest_log-XPGranted IS INITIAL THEN 0 ELSE quest_log-XPGranted ) ) ).
    ENDMETHOD.
    METHOD validateLevelRequirement.
      " Read the adventurer and quest IDs for the records being saved.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        FIELDS ( AdventurerUUID QuestUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(quest_logs).

      LOOP AT quest_logs INTO DATA(quest_log).
        " Get the adventurer's current level from the adventurer table.
        SELECT SINGLE level_value
          FROM zrpg_adventurer
          WHERE adventurer_uuid = @quest_log-AdventurerUUID
          INTO @DATA(adventurer_level).

        " Get the minimum level required by the selected quest.
        SELECT SINGLE min_level
          FROM zrpg_quest
          WHERE quest_uuid = @quest_log-QuestUUID
          INTO @DATA(required_level).

        IF adventurer_level < required_level.
          " Tell RAP this instance failed validation and must not be saved.
          APPEND VALUE #( %tky = quest_log-%tky ) TO failed-adventurerquest.
          " Send a readable error message back to the UI/API caller.
          APPEND VALUE #(
            %tky = quest_log-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = |Adventurer level { adventurer_level } is below quest requirement { required_level }.| ) )
            TO reported-adventurerquest.
        ENDIF.
      ENDLOOP.
    ENDMETHOD.

    METHOD validateDuplicateQuest.
      " Read enough fields to compare the current quest log with existing ones.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        FIELDS ( AdvQuestUUID AdventurerUUID QuestUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(quest_logs).

      LOOP AT quest_logs INTO DATA(quest_log).
        " Look for another quest log with the same adventurer and quest.
        SELECT SINGLE adv_quest_uuid
          FROM zrpg_adv_quest
          WHERE adventurer_uuid = @quest_log-AdventurerUUID
            AND quest_uuid = @quest_log-QuestUUID
            " Exclude the current row, so updates to the same record are not blocked.
            AND adv_quest_uuid <> @quest_log-AdvQuestUUID
          INTO @DATA(existing_log_uuid).

        IF sy-subrc = 0.
          " A row was found, so this would be a duplicate quest acceptance.
          APPEND VALUE #( %tky = quest_log-%tky ) TO failed-adventurerquest.
          APPEND VALUE #(
            %tky = quest_log-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = 'This adventurer has already accepted this quest.' ) )
            TO reported-adventurerquest.
        ENDIF.
      ENDLOOP.
    ENDMETHOD.

    METHOD acceptQuest.
      " Store the exact time the quest was accepted.
      GET TIME STAMP FIELD DATA(now_utc).

      " Change selected quest logs to ACCEPTED in the RAP transaction buffer.
      MODIFY ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        UPDATE FIELDS ( QuestStatus AcceptedAt )
        WITH VALUE #( FOR key IN keys
          ( %tky = key-%tky
            QuestStatus = 'ACCEPTED'
            AcceptedAt = now_utc ) ).

      " Read the updated records so the action can return fresh data to the caller.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(updated_logs).

      " %param is the payload returned by the RAP action.
      result = VALUE #( FOR updated_log IN updated_logs
        ( %tky = updated_log-%tky %param = updated_log ) ).
    ENDMETHOD.

    METHOD completeQuest.
      " Read the selected quest logs before trying to complete them.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        FIELDS ( QuestStatus QuestUUID AdventurerUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(quest_logs).

      GET TIME STAMP FIELD DATA(now_utc).

      LOOP AT quest_logs INTO DATA(quest_log).
        IF quest_log-QuestStatus <> 'ACCEPTED'.
          " Only accepted quests can move to completed.
          APPEND VALUE #( %tky = quest_log-%tky ) TO failed-adventurerquest.
          APPEND VALUE #(
            %tky = quest_log-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = 'Only accepted quests can be completed.' ) )
            TO reported-adventurerquest.
          CONTINUE.
        ENDIF.

        " Get the XP reward configured on the quest.
        SELECT SINGLE xp_reward
          FROM zrpg_quest
          WHERE quest_uuid = @quest_log-QuestUUID
          INTO @DATA(xp_reward).

        " Mark the quest as completed and record the XP granted.
        MODIFY ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
          ENTITY AdventurerQuest
          UPDATE FIELDS ( QuestStatus CompletedAt XPGranted )
          WITH VALUE #( ( %tky = quest_log-%tky
                          QuestStatus = 'COMPLETED'
                          CompletedAt = now_utc
                          XPGranted = xp_reward ) ).

        " Add the quest XP to the adventurer's total XP.
        UPDATE zrpg_adventurer
          SET xp_total = xp_total + @xp_reward
          WHERE adventurer_uuid = @quest_log-AdventurerUUID.
      ENDLOOP.

      " Return updated quest log data after the completion action.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(updated_logs).

      result = VALUE #( FOR updated_log IN updated_logs
        ( %tky = updated_log-%tky %param = updated_log ) ).
    ENDMETHOD.

    METHOD claimReward.
      " Read current quest status and reward flag before claiming.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        FIELDS ( QuestStatus RewardClaimed )
        WITH CORRESPONDING #( keys )
        RESULT DATA(quest_logs).

      LOOP AT quest_logs INTO DATA(quest_log).
        IF quest_log-QuestStatus <> 'COMPLETED' OR quest_log-RewardClaimed = abap_true.
          " Rewards can only be claimed once, and only after the quest is completed.
          APPEND VALUE #( %tky = quest_log-%tky ) TO failed-adventurerquest.
          APPEND VALUE #(
            %tky = quest_log-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = 'Reward can only be claimed once after quest completion.' ) )
            TO reported-adventurerquest.
          CONTINUE.
        ENDIF.

        " Mark the reward as claimed.
        MODIFY ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
          ENTITY AdventurerQuest
          UPDATE FIELDS ( RewardClaimed )
          WITH VALUE #( ( %tky = quest_log-%tky RewardClaimed = abap_true ) ).
      ENDLOOP.

      " Return updated quest log data after the claim action.
      READ ENTITIES OF ZI_RPG_AdventurerQuest IN LOCAL MODE
        ENTITY AdventurerQuest
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(updated_logs).

      result = VALUE #( FOR updated_log IN updated_logs
        ( %tky = updated_log-%tky %param = updated_log ) ).
    ENDMETHOD.
  ENDCLASS.
