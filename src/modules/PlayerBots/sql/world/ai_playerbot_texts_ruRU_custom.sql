-- Custom ruRU localization for PlayerBots user-facing messages.
-- Safe to run repeatedly. Commands and strategy names remain English.
SET NAMES utf8;

INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'loot_bags_full','There is some loot but I do not have free bag space, so not looting',0,0,'','','','','','','','Есть добыча, но в сумках нет свободного места, поэтому я её не подбираю.' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='loot_bags_full');
UPDATE ai_playerbot_texts SET text_loc8='Есть добыча, но в сумках нет свободного места, поэтому я её не подбираю.' WHERE name='loot_bags_full';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'loot_quest_bags_full','Can not loot quest item, my bags are full',0,0,'','','','','','','','Не могу подобрать квестовый предмет: в сумках нет свободного места.' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='loot_quest_bags_full');
UPDATE ai_playerbot_texts SET text_loc8='Не могу подобрать квестовый предмет: в сумках нет свободного места.' WHERE name='loot_quest_bags_full';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'loot_blocked','%unit is blocking %object, need to kill it or I will not loot',0,0,'','','','','','','','%unit мешает добраться до %object. Сначала нужно убить его, иначе я не смогу подобрать добычу.' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='loot_blocked');
UPDATE ai_playerbot_texts SET text_loc8='%unit мешает добраться до %object. Сначала нужно убить его, иначе я не смогу подобрать добычу.' WHERE name='loot_blocked';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'gather_blocked','%unit is blocking %object, need to kill it or I will not gather',0,0,'','','','','','','','%unit мешает добраться до %object. Сначала нужно убить его, иначе я не смогу собрать ресурс.' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='gather_blocked');
UPDATE ai_playerbot_texts SET text_loc8='%unit мешает добраться до %object. Сначала нужно убить его, иначе я не смогу собрать ресурс.' WHERE name='gather_blocked';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'wait_travel_combat','I''m heading to your location but I''m in combat',0,0,'','','','','','','','Я иду к тебе, но сейчас нахожусь в бою.' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='wait_travel_combat');
UPDATE ai_playerbot_texts SET text_loc8='Я иду к тебе, но сейчас нахожусь в бою.' WHERE name='wait_travel_combat';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'stay_flying','I can not stay, I''m flying!',0,0,'','','','','','','','Я не могу остановиться — я в полёте!' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='stay_flying');
UPDATE ai_playerbot_texts SET text_loc8='Я не могу остановиться — я в полёте!' WHERE name='stay_flying';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'follow_too_far','I won''t follow: too far away',0,0,'','','','','','','','Я не могу следовать за тобой: слишком далеко.' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='follow_too_far');
UPDATE ai_playerbot_texts SET text_loc8='Я не могу следовать за тобой: слишком далеко.' WHERE name='follow_too_far';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'wait_for_me','Wait for me',0,0,'','','','','','','','Подожди меня!' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='wait_for_me');
UPDATE ai_playerbot_texts SET text_loc8='Подожди меня!' WHERE name='wait_for_me';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'ready_no_ammo','Out of ammo!',0,0,'','','','','','','','У меня закончились боеприпасы!' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='ready_no_ammo');
UPDATE ai_playerbot_texts SET text_loc8='У меня закончились боеприпасы!' WHERE name='ready_no_ammo';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'ready_no_pet','No pet!',0,0,'','','','','','','','У меня нет питомца!' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='ready_no_pet');
UPDATE ai_playerbot_texts SET text_loc8='У меня нет питомца!' WHERE name='ready_no_pet';
INSERT INTO ai_playerbot_texts (name,text,say_type,reply_type,text_loc1,text_loc2,text_loc3,text_loc4,text_loc5,text_loc6,text_loc7,text_loc8) SELECT 'ready_pet_unhappy','Pet is unhappy!',0,0,'','','','','','','','Мой питомец недоволен!' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM ai_playerbot_texts WHERE name='ready_pet_unhappy');
UPDATE ai_playerbot_texts SET text_loc8='Мой питомец недоволен!' WHERE name='ready_pet_unhappy';
UPDATE ai_playerbot_texts SET text_loc8='Я принял задание %quest.' WHERE name='quest_accepted';
UPDATE ai_playerbot_texts SET text_loc8='Не могу принять %quest: в сумках нет свободного места.' WHERE name='quest_error_bag_full';
UPDATE ai_playerbot_texts SET text_loc8='%quest ещё не выполнено.' WHERE name='quest_status_incomplete';
UPDATE ai_playerbot_texts SET text_loc8='%quest доступно для принятия.' WHERE name='quest_status_available';
UPDATE ai_playerbot_texts SET text_loc8='%quest провалено.' WHERE name='quest_status_failed';
UPDATE ai_playerbot_texts SET text_loc8='Я не могу выполнить %quest.' WHERE name='quest_status_unable_to_complete';
UPDATE ai_playerbot_texts SET text_loc8='%quest выполнено.' WHERE name='quest_status_completed';
UPDATE ai_playerbot_texts SET text_loc8='Я уже выполнил %quest.' WHERE name='quest_error_completed';
UPDATE ai_playerbot_texts SET text_loc8='У меня уже есть %quest.' WHERE name='quest_error_have_quest';
UPDATE ai_playerbot_texts SET text_loc8='Я не могу принять %quest из-за требований задания.' WHERE name='quest_error_cant_take';
UPDATE ai_playerbot_texts SET text_loc8='Не могу принять %quest: журнал заданий заполнен.' WHERE name='quest_error_log_full';
