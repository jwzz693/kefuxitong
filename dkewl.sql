-- =====================================================
-- 完整数据库导出
-- 数据库: ceshi
-- 导出时间: 2026-03-02 13:14:49
-- =====================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+08:00";
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================
-- 存储过程
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `addBet`$$
CREATE PROCEDURE `addBet`(`_uid` INT, `_amount` FLOAT, `_username` VARCHAR(16) CHARACTER SET utf8)
begin
	declare parentId1 int;      
	declare parentId2 int;      
	declare pname varchar(16) character set utf8;  



	declare CommissionBase float(10,2);                
	declare CommissionParentAmount float(10,2);        
	declare CommissionParentAmount2 float(10,2);       



	declare cur Decimal(12,4);
	declare _commisioned tinyint(1);
	select bet into cur from ssc_member_bet where uid=_uid and date=date_format(now(),'%Y%m%d');
	
	if cur is null THEN
		INSERT into ssc_member_bet(uid, username, date, bet, commisioned) values(_uid, _username, date_format(now(),'%Y%m%d'), _amount, 0);
	end if;
	if cur is not null THEN
		update ssc_member_bet set bet=bet+_amount where uid=_uid and date=date_format(now(),'%Y%m%d');
	end if;

	select bet into cur from ssc_member_bet where uid=_uid and date=date_format(now(),'%Y%m%d');
	select commisioned into _commisioned from ssc_member_bet where uid=_uid and date=date_format(now(),'%Y%m%d');
	select `value` into CommissionBase from ssc_params where name='conCommissionBase' limit 1;

	if cur >= CommissionBase and _commisioned=0 then
		select `value` into CommissionParentAmount from ssc_params where name='conCommissionParentAmount' limit 1;
		select `value` into CommissionParentAmount2 from ssc_params where name='conCommissionParentAmount2' limit 1;

		select `parentId` into parentId1 from ssc_members where uid=_uid;
		if parentId1 is not null and CommissionParentAmount>0 THEN
			call setCoin(CommissionParentAmount, 0, parentId1, 53, 0, concat('[', _username, ']消费佣金'), 0, '', '');
			select `parentId` into parentId2 from ssc_members where uid=parentId1;
			if parentId2 is not null and CommissionParentAmount2>0 THEN
				select `username` into pname from ssc_members where uid=parentId1;
				call setCoin(CommissionParentAmount2, 0, parentId2, 53, 0, concat('[', pname,'->', _username, ']消费佣金'), 0, '', '');
			end if;
			update ssc_member_bet set commisioned=1 where uid=_uid and date=date_format(now(),'%Y%m%d');
		end if;
	end if;
end$$

DROP PROCEDURE IF EXISTS `addRecharge`$$
CREATE PROCEDURE `addRecharge`(`_uid` INT, `_username` VARCHAR(16) CHARACTER SET utf8)
begin
	declare parentId1 int;      
	declare parentId2 int;      
	declare pname varchar(16) character set utf8;  



	declare _rechargeCommissionAmount float(10,2);                
	declare _rechargeCommission float(10,2);        
	declare _rechargeCommission2 float(10,2);       



	declare _commisioned TINYINT(1);     

	declare cur float(10,2);
	select sum(amount) into cur from ssc_member_recharge where state!=0 and isDelete=0 and uid=_uid and actionTime BETWEEN UNIX_TIMESTAMP(DATE(NOW())) and UNIX_TIMESTAMP(NOW());
	
	select `value` into _rechargeCommissionAmount from ssc_params where name='rechargeCommissionAmount' limit 1;
	select rechargeCommisioned into _commisioned from ssc_member_bet where uid=_uid and date=date_format(now(),'%Y%m%d');

	if cur is not null and cur >=_rechargeCommissionAmount and _commisioned=0 THEN
		select `value` into _rechargeCommission from ssc_params where name='rechargeCommission' limit 1;
		select `value` into _rechargeCommission2 from ssc_params where name='rechargeCommission2' limit 1;

		select `parentId` into parentId1 from ssc_members where uid=_uid;
		if parentId1 is not null and _rechargeCommission>0 THEN
			call setCoin(_rechargeCommission, 0, parentId1, 53, 0, concat('[', _username, ']充值佣金'), 0, '', '');
			select `parentId` into parentId2 from ssc_members where uid=parentId1;
			if parentId2 is not null and _rechargeCommission2>0 THEN
				select `username` into pname from ssc_members where uid=parentId1;
				call setCoin(_rechargeCommission2, 0, parentId2, 53, 0, concat('[', pname,'->', _username, ']充值佣金'), 0, '', '');
			end if;
			update ssc_member_bet set rechargeCommisioned=1 where uid=_uid and date=date_format(now(),'%Y%m%d');
		end if;
	end if;
end$$

DROP PROCEDURE IF EXISTS `addScore`$$
CREATE PROCEDURE `addScore`(`_uid` INT, `_amount` FLOAT)
begin
	
	declare bonus float;
	select `value` into bonus from ssc_params where name='scoreProp' limit 1;
	
	set bonus=bonus*_amount;
	
	if bonus then
		update ssc_members u, ssc_params p set u.score = u.score+bonus, u.scoreTotal=u.scoreTotal+bonus where u.`uid`=_uid;
	end if;
	
end$$

DROP PROCEDURE IF EXISTS `auto_clearData`$$
CREATE PROCEDURE `auto_clearData`()
begin

	declare endDate int;
	set endDate = UNIX_TIMESTAMP(now())-7*24*3600;

	
	delete from ssc_data where time < endDate;
	
	delete from ssc_member_session where accessTime < endDate;
	
	delete from ssc_bets where kjTime < endDate and lotteryNo <> '';
	

	delete from ssc_admin_log where actionTime < endDate;

end$$

DROP PROCEDURE IF EXISTS `betcount`$$
CREATE PROCEDURE `betcount`(`_date` INT(8), `_type` TINYINT(3), `_uid` INT(10))
begin
  
	declare _pri int(11) DEFAULT 0; 
	declare _betCount int(5) DEFAULT 0;
	declare _betAmount double(15,4) DEFAULT 0.0000;
	declare _betAmountb double(15,4) DEFAULT 0.0000;
	declare _zjAmount double(15,4) DEFAULT 0.0000;
	declare _rebateMoney double(15,4) DEFAULT 0.0000;
	declare _username VARCHAR(16) DEFAULT null;
	declare _gudongId int(10) DEFAULT 0; 
	declare _zparentId int(10) DEFAULT 0; 
	declare _parentId int(10) DEFAULT 0; 

	select uid into _uid from ssc_members where isDelete=0 and `uid`=_uid;
	if _uid then

	select id into _pri from ssc_count where `date`=_date and `uid`=_uid and `type`=_type  LIMIT 1;

	if _pri=0 or _pri is null THEN
		insert into ssc_count (`date`, `uid`, `type`) values(_date, _uid, _type);
		select id into _pri from ssc_count where date=_date and `uid`=_uid and `type`=_type LIMIT 1;
	end if;




	select count(*) into _betCount from ssc_bets where isDelete=0 and `uid`=_uid and `lotteryNo` !='' and `type` =_type and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;
	

	select sum(totalMoney) into _betAmount from ssc_bets where isDelete=0 and `uid` =_uid and `lotteryNo` !='' and `type` =_type and `betInfo` !='' and `totalNums` >1 and `totalMoney` >0 and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;

	select sum(money) into _betAmountb from ssc_bets where isDelete=0 and `uid` =_uid and `lotteryNo` !='' and `type` =_type and `totalNums` =1 and `totalMoney` =0 and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;


	select sum(bonus) into _zjAmount from ssc_bets where isDelete=0 and `uid` =_uid and `lotteryNo` !='' and `type` =_type and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;

	select sum(rebateMoney) into _rebateMoney from ssc_bets where isDelete=0 and `uid` =_uid and `lotteryNo` !='' and `type` =_type and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;
	

	select username into _username from ssc_members where isDelete=0 and `uid` =_uid;
	select gudongId into _gudongId from ssc_members where isDelete=0 and `uid` =_uid;
	select zparentId into _zparentId from ssc_members where isDelete=0 and `uid` =_uid;	
	select parentId into _parentId from ssc_members where isDelete=0 and `uid` =_uid;



	if _betCount is null THEN
		set _betCount = 0;
	end if;

	if _betAmount is null THEN
		set _betAmount = 0;
	end if;
	if _betAmountb is null THEN
		set _betAmountb = 0;
	end if;
	if _zjAmount is null THEN
		set _zjAmount = 0;
	end if;
	if _rebateMoney is null THEN
		set _rebateMoney = 0;
	end if;
	
	set _betAmount = _betAmount + _betAmountb;

	update ssc_count set betCount=_betCount, betAmount=_betAmount, zjAmount=_zjAmount, rebateMoney=_rebateMoney, username=_username, uid=_uid, gudongId=_gudongId, zparentId=_zparentId, parentId=_parentId where id=_pri;	

	end if;

end$$

DROP PROCEDURE IF EXISTS `betreport`$$
CREATE PROCEDURE `betreport`(`_date` INT(8), `_uid` INT(10))
begin
 
	declare _pri int(11) DEFAULT 0; 
	declare _betCount int(5) DEFAULT 0;
	declare _betAmount double(15,4) DEFAULT 0.0000;
	declare _betAmountb double(15,4) DEFAULT 0.0000;
	declare _zjAmount double(15,4) DEFAULT 0.0000;
	declare _rebateMoney double(15,4) DEFAULT 0.0000;
	declare _username VARCHAR(16) DEFAULT null;
	declare _gudongId int(10) DEFAULT 0; 
	declare _zparentId int(10) DEFAULT 0; 
	declare _parentId int(10) DEFAULT 0; 

	select uid into _uid from ssc_members where isDelete=0 and uid=_uid;
	if _uid then

	select id into _pri from ssc_report where date=_date and uid=_uid LIMIT 1;
	
	if _pri=0 or _pri is null THEN
		insert into ssc_report (date, uid) values(_date, _uid);
		select id into _pri from ssc_report where date=_date and uid=_uid LIMIT 1;
	end if;




	select count(*) into _betCount from ssc_bets where isDelete=0 and uid=_uid and lotteryNo!='' and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;

	select sum(totalMoney) into _betAmount from ssc_bets where isDelete=0 and uid=_uid and lotteryNo!='' and betInfo!='' and totalNums>1 and totalMoney>0 and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;

	select sum(money) into _betAmountb from ssc_bets where isDelete=0 and uid=_uid and lotteryNo!='' and totalNums=1 and totalMoney=0 and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;

	select sum(bonus) into _zjAmount from ssc_bets where isDelete=0 and uid=_uid and lotteryNo!='' and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;

	select sum(rebateMoney) into _rebateMoney from ssc_bets where isDelete=0 and uid=_uid and lotteryNo!='' and FROM_UNIXTIME(kjTime,'%Y%m%d') = _date;
	
	
	select username into _username from ssc_members where isDelete=0 and uid=_uid;
	select gudongId into _gudongId from ssc_members where isDelete=0 and uid=_uid;
	select zparentId into _zparentId from ssc_members where isDelete=0 and uid=_uid;	
	select parentId into _parentId from ssc_members where isDelete=0 and uid=_uid;



	if _betCount is null THEN
		set _betCount = 0;
	end if;

	if _betAmount is null THEN
		set _betAmount = 0;
	end if;
	if _betAmountb is null THEN
		set _betAmountb = 0;
	end if;
	if _zjAmount is null THEN
		set _zjAmount = 0;
	end if;
	if _rebateMoney is null THEN
		set _rebateMoney = 0;
	end if;
	
	set _betAmount = _betAmount + _betAmountb;

	update ssc_report set betCount=_betCount, betAmount=_betAmount, zjAmount=_zjAmount, rebateMoney=_rebateMoney, username=_username, uid=_uid, gudongId=_gudongId, zparentId=_zparentId, parentId=_parentId where id=_pri;
	end if;

end$$

DROP PROCEDURE IF EXISTS `cancelBet`$$
CREATE PROCEDURE `cancelBet`(`_zhuiHao` VARCHAR(255))
begin

	declare amount float;
	declare _uid int;
	declare _id int;
	declare _type int;
	
	declare info varchar(255) character set utf8;
	declare liqType int default 5;
	
	declare done int default 0;
	declare cur cursor for
	select id, money, `uid`, `type` from ssc_bets where serializeId=_zhuiHao and lotteryNo='' and isDelete=0;
	declare continue HANDLER for not found set done=1;
	
	open cur;
		repeat
			fetch cur into _id, amount, _uid, _type;
			if not done then
				update ssc_bets set isDelete=1 where id=_id;
				set info='追号撤单';
				call setCoin(amount, 0, _uid, liqType, _type, info, _id, '', '');
			end if;
		until done end repeat;
	close cur;

end$$

DROP PROCEDURE IF EXISTS `clearData`$$
CREATE PROCEDURE `clearData`(`dateInt` INT(11))
begin

	declare endDate int;
	set endDate = dateInt;
	

	
	delete from ssc_bets where kjTime < endDate and lotteryNo <> '';
	
	delete from ssc_coin_log where actionTime < endDate;
	
	delete from ssc_admin_log where actionTime < endDate;
	
	delete from ssc_member_session where accessTime < endDate;
	
	delete from ssc_member_cash where actionTime < endDate and state <> 1;
	
	delete from ssc_member_recharge where actionTime < endDate and state <> 0;
	delete from ssc_member_recharge where actionTime < endDate-24*3600 and state = 0;
		
	
end$$

DROP PROCEDURE IF EXISTS `clearData2`$$
CREATE PROCEDURE `clearData2`(`dateInt` INT(11))
begin

	declare endDate int;
	set endDate = dateInt;

	
	delete from ssc_data where time < endDate;

end$$

DROP PROCEDURE IF EXISTS `clearData3`$$
CREATE PROCEDURE `clearData3`(`dateInt` INT(11))
begin

	declare endDate int;
	set endDate = dateInt;
	
	
	delete from ssc_coin_log where actionTime < endDate;
		
	
end$$

DROP PROCEDURE IF EXISTS `clearData4`$$
CREATE PROCEDURE `clearData4`(`dateInt` INT(11))
begin

	declare endDate int;
	set endDate = dateInt;
	
	

	delete from ssc_admin_log where actionTime < endDate;
	
end$$

DROP PROCEDURE IF EXISTS `clearData5`$$
CREATE PROCEDURE `clearData5`(`dateInt` INT(11))
begin

	declare endDate int;
	set endDate = dateInt;
	
	
	delete from ssc_member_session where accessTime < endDate;
	
end$$

DROP PROCEDURE IF EXISTS `clearData6`$$
CREATE PROCEDURE `clearData6`(`dateInt` INT(11))
begin

	declare endDate int;
	set endDate = dateInt;
	
	
	delete from ssc_member_cash where actionTime < endDate and state <> 1;
	
end$$

DROP PROCEDURE IF EXISTS `clearData7`$$
CREATE PROCEDURE `clearData7`(`dateInt` INT(11))
begin

	declare endDate int;
	set endDate = dateInt;
	
	

	delete from ssc_member_recharge where actionTime < endDate and state <> 0;
	delete from ssc_member_recharge where actionTime < endDate-24*3600 and state = 0;
	
end$$

DROP PROCEDURE IF EXISTS `conComAll`$$
CREATE PROCEDURE `conComAll`(`baseAmount` FLOAT, `parentAmount` FLOAT, `parentLevel` INT)
begin

	declare conUid int;
	declare conUserName varchar(255);
	declare tjAmount float;
	declare done int default 0;	
	declare dateTime int default unix_timestamp(curdate());

	declare cur cursor for
	select b.uid, b.username, sum(b.`mode` * b.actionNum * b.beiShu) _tjAmount from ssc_bets b where b.kjTime>=dateTime and b.uid not in(select distinct l.extfield0 from ssc_coin_log l where l.liqType=53 and l.actionTime>=dateTime and l.extfield2=parentLevel) group by b.uid having _tjAmount>=baseAmount;
	declare continue HANDLER for not found set done=1;

	
	
	open cur;
		repeat fetch cur into conUid, conUserName, tjAmount;
		
		if not done then
			call conComSingle(conUid, parentAmount, parentLevel);
		end if;
		until done end repeat;
	close cur;

end$$

DROP PROCEDURE IF EXISTS `conComSingle`$$
CREATE PROCEDURE `conComSingle`(`conUid` INT, `parentAmount` FLOAT, `parentLevel` INT)
begin

	declare parentId int;
	declare superParentId int;
	declare conUserName varchar(255) character set utf8;
	declare p_username varchar(255) character set utf8;

	declare liqType int default 53;
	declare info varchar(255) character set utf8;

	declare done int default 0;
	declare cur cursor for
	select p.uid, p.parentId, p.username, u.username from ssc_members p, ssc_members u where u.parentId=p.uid and u.`uid`=conUid; 
	declare continue HANDLER for not found set done=1;

	open cur;
		repeat fetch cur into parentId, superParentId, p_username, conUserName;
		
		if not done then
			if parentLevel=1 then
				if parentId and parentAmount then
					set info=concat('下级[', conUserName, ']消费佣金');
					call setCoin(parentAmount, 0, parentId, liqType, 0, info, conUid, conUserName, parentLevel);
				end if;
			end if;
			
			if parentLevel=2 then
				if superParentId and parentAmount then
					set info=concat('下级[', conUserName, '<=', p_username, ']消费佣金');
					call setCoin(parentAmount, 0, superParentId, liqType, 0, info, conUid, conUserName, parentLevel);
				end if;
			end if;
		end if;
		until done end repeat;
	close cur;

end$$

DROP PROCEDURE IF EXISTS `consumptionCommission`$$
CREATE PROCEDURE `consumptionCommission`()
begin

	declare baseAmount float;
	declare baseAmount2 float;
	declare parentAmount float;
	declare superParentAmount float;

	call readConComSet(baseAmount, baseAmount2, parentAmount, superParentAmount);
	

	if baseAmount>0 then
		call conComAll(baseAmount, parentAmount, 1);
	end if;
	if baseAmount2>0 then
		call conComAll(baseAmount2, superParentAmount, 2);
	end if;

end$$

DROP PROCEDURE IF EXISTS `delUser`$$
CREATE PROCEDURE `delUser`(`_uid` INT)
begin
	
	delete from ssc_bets where `uid`=_uid;
	
	delete from ssc_coin_log where `uid`=_uid;
	
	delete from ssc_admin_log where `uid`=_uid;
	
	delete from ssc_member_session where `uid`=_uid;
	
	delete from ssc_member_cash where `uid`=_uid;
	
	delete from ssc_member_recharge where `uid`=_uid;
	
	delete from ssc_member_bank where `uid`=_uid;
	
	delete from ssc_members where `uid`=_uid;
end$$

DROP PROCEDURE IF EXISTS `delUser2`$$
CREATE PROCEDURE `delUser2`(`_uid` INT)
begin
	
	delete from ssc_bets where `uid`=_uid;
	
	delete from ssc_coin_log where `uid`=_uid;
	

	delete from ssc_admin_log where `uid`=_uid;
	
	delete from ssc_member_session where `uid`=_uid;
	
	delete from ssc_member_cash where `uid`=_uid;
	

	delete from ssc_member_recharge where `uid`=_uid;
	
	delete from ssc_member_bank where `uid`=_uid;
	
	delete from ssc_members where `uid`=_uid;
	
	delete from ssc_links where `uid`=_uid;
end$$

DROP PROCEDURE IF EXISTS `delUsers`$$
CREATE PROCEDURE `delUsers`(`_coin` FLOAT(10,2), `_date` INT)
begin
	declare uid_del int;
	
	declare done int default 0;
	declare cur cursor for
	select distinct u.uid from ssc_members u, ssc_member_session s where u.uid=s.uid and (u.coin+u.fcoin)<_coin and s.accessTime<_date and not exists(select u1.`uid` from ssc_members u1 where u1.parentId=u.`uid`)
union 
select distinct u2.uid from ssc_members u2 where (u2.coin+u2.fcoin)<_coin and u2.regTime<_date and not exists (select s1.uid from ssc_member_session s1 where s1.uid=u2.uid);
	declare continue HANDLER for not found set done = 1;

	open cur;
		repeat
			fetch cur into uid_del;
			if not done then 
				call delUser(uid_del);
			end if;
		until done end repeat;
	close cur;
end$$

DROP PROCEDURE IF EXISTS `getQzInfo`$$
CREATE PROCEDURE `getQzInfo`(`_uid` INT, INOUT `_fanDian` FLOAT, INOUT `_parentId` INT)
begin

	declare done int default 0;
	declare cur cursor for
	select fanDian, parentId from ssc_members where `uid`=_uid;
	declare continue HANDLER for not found set done = 1;

	open cur;
		fetch cur into _fanDian, _parentId;
	close cur;
	
	
end$$

DROP PROCEDURE IF EXISTS `guestclear`$$
CREATE PROCEDURE `guestclear`()
begin

	declare endDate int;
	set endDate = UNIX_TIMESTAMP(now())-1*24*3600;

	
	delete from ssc_member_session where accessTime < endDate and username like 'guest_%';
	
	delete from ssc_guestbets where kjTime < endDate;
	
	delete from ssc_guestcoin_log where actionTime < endDate;
	
	delete from ssc_guestmembers where regTime < endDate;

end$$

DROP PROCEDURE IF EXISTS `guestkanJiang`$$
CREATE PROCEDURE `guestkanJiang`(`_betId` INT, `_zjCount` INT, `_kjData` VARCHAR(255) CHARACTER SET utf8, `_kset` VARCHAR(255) CHARACTER SET utf8)
begin
	
	declare `uid` int;									
	declare userid int;
	declare parentId int;								
	declare zparentId int;
	declare gudongId int;
	declare username varchar(32) character set utf8;	

	

	
	declare serializeId varchar(64);
	declare actionData longtext character set utf8;
	declare actionNo varchar(255);
	declare `type` int;
	declare playedId int;
	
	declare isDelete int;
	declare odds float;     
	declare _rebate float default 0;
	declare _rebatemoney float default 0;
	declare fanDian float;		
	
	declare amount float;					
	declare zjAmount float default 0;		
	declare _fanDianAmount float default 0;	

	
	declare liqType int;
	declare info varchar(255) character set utf8;
	
	declare _parentId int;		

	declare _zparentId int;		

	declare _gudongId int;		

	declare _fanDian float;		
	
	declare totalnums SMALLINT default 0;
	declare totalmoney float default 0;
	declare betinfo varchar(64) character set utf8;
	declare Groupname varchar(32) character set utf8;
	
	declare _kjTime int(11) DEFAULT 0;
	
	declare done int default 0;
	declare cur cursor for
	select b.`uid`, u.parentId, u.zparentId, u.gudongId, u.username, b.serializeId, b.actionData, b.actionNo, FROM_UNIXTIME(b.kjTime,'%Y%m%d') _kjTime, b.`type`, b.playedId, b.isDelete, b.fanDian, u.fanDian, b.odds, b.rebate, b.money, b.totalNums, b.totalMoney, b.betInfo, b.Groupname  from ssc_guestbets b, ssc_guestmembers u where b.`uid`=u.`uid` and b.id=_betId;
	declare continue handler for sqlstate '02000' set done = 1;
	
	open cur;
		repeat
			fetch cur into `uid`, parentId, zparentId, gudongId, username, serializeId, actionData, actionNo, _kjTime, `type`, playedId, isDelete, fanDian, _fanDian, odds, _rebate, amount, totalnums, totalmoney, betinfo, Groupname;
		until done end repeat;
	close cur;
	

	start transaction;
	if md5(_kset)='47df5dd3fc251a6115761119c90b964a' then
	
		

		if isDelete=0 then
		
			set userid=`uid`;
			
			set _parentId=parentId;
			set _zparentId=zparentId;
			set _gudongId=gudongId;
			
			set fanDian=_fanDian;
			
			
			if _zjCount then
				
				
				set liqType=6;
				set info='中奖奖金';
				if _zjCount = -1 then
					if totalnums>1 and totalmoney>0 and betinfo<>'' then
						set amount=totalmoney;
					end if;
					set zjAmount= amount; 

				elseif Groupname='三军' then
					set zjAmount= amount * odds + amount * (_zjCount - 1); 
				else
					set zjAmount= _zjCount * amount * odds; 
				end if;
				call guestsetCoin(zjAmount, 0, `uid`, liqType, `type`, info, _betId, serializeId, '');
				
			end if;	
	
			if _zjCount = -1 then
				set _zjCount = 0;
			end if;				
			

			if totalnums>1 and totalmoney>0 and betinfo<>'' then
				set amount=totalmoney;
			end if;

			

			if _rebate>0 and  _rebate<0.5 THEN
			set liqType=105;
			set info='退水资金';
			set _rebatemoney = amount * _rebate;
			call guestsetCoin(_rebatemoney, 0, `uid`, liqType, `type`, info, _betId, serializeId, '');
			end if;

			update ssc_guestbets set lotteryNo=_kjData, zjCount=_zjCount, bonus=zjAmount, rebateMoney=_rebatemoney where id=_betId;

			if CONVERT(DATE_FORMAT(now(),'%H%i'), SIGNED)>=100 and CONVERT(DATE_FORMAT(now(),'%H%i'), SIGNED)<105 then
			call guestclear();
			end if;
		end if;
	end if;
	
	commit;
	
end$$

DROP PROCEDURE IF EXISTS `guestsetCoin`$$
CREATE PROCEDURE `guestsetCoin`(`_coin` FLOAT, `_fcoin` FLOAT, `_uid` INT, `_liqType` INT, `_type` INT, `_info` VARCHAR(255) CHARACTER SET utf8, `_extfield0` INT, `_extfield1` VARCHAR(255) CHARACTER SET utf8, `_extfield2` VARCHAR(255) CHARACTER SET utf8)
begin
	
	
	DECLARE currentTime INT DEFAULT UNIX_TIMESTAMP();
	DECLARE _userCoin FLOAT;
	DECLARE _count INT  DEFAULT 0;
	
	IF _coin IS NULL THEN
		SET _coin=0;
	END IF;
	IF _fcoin IS NULL THEN
		SET _fcoin=0;
	END IF;
	

	SELECT COUNT(1) INTO _count FROM ssc_guestcoin_log WHERE  extfield0=_extfield0  AND info='中奖奖金'  AND `uid`=_uid;
	IF  _count<1 THEN
	UPDATE ssc_guestmembers SET coin = coin + _coin, fcoin = fcoin + _fcoin WHERE `uid` = _uid;
	SELECT coin INTO _userCoin FROM ssc_guestmembers WHERE `uid`=_uid;
	
	INSERT INTO ssc_guestcoin_log(coin, fcoin, userCoin, `uid`, actionTime, liqType, `type`, info, extfield0, extfield1, extfield2) VALUES(_coin, _fcoin, _userCoin, _uid, currentTime, _liqType, _type, _info, _extfield0, _extfield1, _extfield2);
	END IF;
	

end$$

DROP PROCEDURE IF EXISTS `isFirstRechargeCom`$$
CREATE PROCEDURE `isFirstRechargeCom`(`_uid` INT, OUT `flag` INT)
begin
	
	declare dateTime int default unix_timestamp(curdate());
	select id into flag from ssc_member_recharge where rechargeTime>dateTime and `uid`=_uid;
	
end$$

DROP PROCEDURE IF EXISTS `kanJiang`$$
CREATE PROCEDURE `kanJiang`(`_betId` INT, `_zjCount` INT, `_kjData` VARCHAR(255) CHARACTER SET utf8, `_kset` VARCHAR(255) CHARACTER SET utf8)
begin
	
	declare `uid` int;									
	declare qz_uid int;									
	declare qz_username varchar(32) character set utf8;	
	declare qz_fcoin varchar(32);						
	
	declare parentId int;								
	declare username varchar(32) character set utf8;	
	
	
	declare actionNum int;
	declare serializeId varchar(64);
	declare actionData longtext character set utf8;
	declare actionNo varchar(255);
	declare `type` int;
	declare playedId int;
	
	declare isDelete int;
	
	declare fanDian float;		
	declare `mode` float;		
	declare beiShu int;			
	declare zhuiHao int;		
	declare zhuiHaoMode int;	
	declare bonusProp float;	
	
	declare amount float;					
	declare zjAmount float default 0;		
	declare _fanDianAmount float default 0;	
	declare chouShuiAmount float default 0;	
	
	declare liqType int;
	declare info varchar(255) character set utf8;
	
	declare _parentId int;		
	declare _fanDian float;		
	declare qz_fanDian float;	

	
	declare done int default 0;
	declare cur cursor for
	select b.`uid`, u.parentId, u.username, b.qz_uid, b.qz_username, b.qz_fcoin, b.actionNum, b.serializeId, b.actionData, b.actionNo, b.`type`, b.playedId, b.isDelete, b.fanDian, u.fanDian, b.`mode`, b.beiShu, b.zhuiHao, b.zhuiHaoMode, b.bonusProp, b.actionNum*b.`mode`*b.beiShu amount from ssc_bets b, ssc_members u where b.`uid`=u.`uid` and b.id=_betId;
	declare continue handler for sqlstate '02000' set done = 1;
	
	open cur;
		repeat
			fetch cur into `uid`, parentId, username, qz_uid, qz_username, qz_fcoin, actionNum, serializeId, actionData, actionNo, `type`, playedId, isDelete, fanDian, _fanDian, `mode`, beiShu, zhuiHao, zhuiHaoMode, bonusProp, amount;
		until done end repeat;
	close cur;
	
	

	
	start transaction;
	if md5(_kset)='47df5dd3fc251a6115761119c90b964a' then
		
		
		if isDelete=0 then
			
			
			
			
			
			
			
			call addScore(`uid`, amount);
		
			
			
			if fanDian then
				set liqType=2;
				set info='返点';
				set _fanDianAmount=amount * fanDian/100;
				call setCoin(_fanDianAmount, 0, `uid`, liqType, `type`, info, _betId, '', '');
			end if;
			
			
			set _parentId=parentId;
			
			set fanDian=_fanDian;
			
			while _parentId do
				call setUpFanDian(amount, _fanDian, _parentId, `type`, _betId, `uid`, username);
			end while;
			set _fanDianAmount = _fanDianAmount + amount * ( _fanDian - fanDian)/100;
			
			
			
			if qz_uid then
				
				
				call getQzInfo(qz_uid, _fanDian, _parentId);
				
				set qz_fanDian=_fanDian;
				
				while _parentId do
					call setUpChouShui(amount, _fanDian, _parentId, `type`, _betId, qz_uid, qz_username);
					
				end while;
				
				
				set chouShuiAmount=amount * ( _fanDian - qz_fanDian + 3) / 100;
				
			end if;
			
			
			
			
			
			if _zjCount then
				
				
				set liqType=6;
				set info='中奖奖金';
				set zjAmount=bonusProp * _zjCount * beiShu * `mode`/2;
				call setCoin(zjAmount, 0, `uid`, liqType, `type`, info, _betId, '', '');
	
			end if;
			
			
			update ssc_bets set lotteryNo=_kjData, zjCount=_zjCount, bonus=zjAmount, fanDianAmount=_fanDianAmount, qz_chouShui=chouShuiAmount where id=_betId;

			
			if _zjCount and zhuiHao=1 and zhuiHaoMode=1 then
				
				
				
				call cancelBet(serializeId);
			end if;
			
			
			if qz_uid then
				set liqType=10;
				set info='解冻抢庄冻结资金';
				call setCoin(qz_fcoin, - qz_fcoin, qz_uid, liqType, `type`, info, _betId, '', '');
				
				set liqType=11;
				set info='收单';
				call setCoin(amount, 0, qz_uid, liqType, `type`, info, _betId, '', '');
				
				if _fanDianAmount then
					set liqType=103;
					set info='支付返点';
					call setCoin(-_fanDianAmount, 0, qz_uid, liqType, `type`, info, _betId, '', '');
				end if;
				
				if chouShuiAmount then
					set liqType=104;
					set info='支付抽水';
					call setCoin(-chouShuiAmount, 0, qz_uid, liqType, `type`, info, _betId, '', '');
				end if;
				
				if zjAmount then
					set liqType=105;
					set info='赔付中奖金额';
					call setCoin(-zjAmount, 0, qz_uid, liqType, `type`, info, _betId, '', '');
				end if;
	
			end if;

		end if;
	end if;

	
	commit;
	
end$$

DROP PROCEDURE IF EXISTS `paid`$$
CREATE PROCEDURE `paid`(IN `_item` INT, IN `_type` INT)
begin
update g_crowd_record_28 set paidtask=paidtask+1,paidtype=_type where crowdid=_item and status=0;

end$$

DROP PROCEDURE IF EXISTS `paid_details`$$
CREATE PROCEDURE `paid_details`(IN `_item` INT, IN `_type` INT)
BEGIN

declare _title,_msg,_tmptitle,_editor,_user VARCHAR(800);
declare _valid,done,num,_now,_vid,_cid int(10) default 0;
declare _amt,_amount,_earnratio,_profit,_share,_pay,_target,_selfbuy double(10,2) default 0;

select crowder,amount,cid into _user,_amount,_cid from g_crowd_record_28 where itemid=_item;

select vid,share,buyerpay,target,selfbuy,title into _vid,_share,_pay,_target, _selfbuy,_tmptitle from g_crowd_28 where itemid=_cid;
set _profit=(_pay-_target)*_share/100;
set _editor='system';
set _amt=_amount;

if _type=1 then
    set _amount=(_amt/_target)*_profit+_amt; 
    set _earnratio=(_amount-_amt)*100/_amt; 
else
    
    
    set _earnratio=_selfbuy; 
    set _amount=_amt*(1+_selfbuy/100); 
end if;
if _amount>0 then

    UPDATE g_member SET money=money+_amount,message=message+1 WHERE username=_user;
    select money into _now from g_member where  username=_user;
    INSERT INTO g_finance_record (username,bank,amount,balance,addtime,reason,note,editor,mid,item_id) 
        VALUES (_user,'平台账户获得',_amount,_now,UNIX_TIMESTAMP(now()),'项目回款','','admin',28,_item);
    set _title=concat('项目回款收益-',_tmptitle);
    set _msg=concat(concat('您参与的项目-',_tmptitle,'-已回款，获得收益'),_amount,'元');
    insert into g_message(title,typeid,content,touser,addtime,status) values(_title,4,_msg,_user,UNIX_TIMESTAMP(now()),3);
    insert into g_crowd_share(title,msg,cid,vid,addtime,username,deposit,ratio,earn,earnratio) 
                values(_title,_msg,_item,_vid,UNIX_TIMESTAMP(now()),_user,_amt,_amt/_target,_amount,_earnratio);
end if;
END$$

DROP PROCEDURE IF EXISTS `paid_old`$$
CREATE PROCEDURE `paid_old`(IN `_item` INT, IN `_type` INT)
BEGIN

declare _title,_msg,_tmptitle,_editor,_user VARCHAR(800);
declare _valid,done,num,_now,_vid,_cid int(10) default 0;
declare _amt,_amount,_earnratio,_profit,_share,_pay,_target,_selfbuy double(10,2) default 0;

declare members cursor for select crowder,sum(amount)as amount from g_crowd_record_28 where crowdid=_item and status=0 GROUP BY crowder;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

select vid,share,buyerpay,target,selfbuy,title into _vid,_share,_pay,_target, _selfbuy,_tmptitle from g_crowd_28 where itemid=_item;
select count(DISTINCT(crowder)),cid into _valid,_cid  from g_crowd_record_28 where crowdid=_item and status=0;
set _profit=(_pay-_target)*_share/100;
set _editor='system';


open members;
REPEAT
    FETCH members into _user,_amt;
    set num=num+1;

    if _type=1 then
    set _amount=(_amt/_target)*_profit+_amt; 
    set _earnratio=(_amount-_amt)*100/_amt; 
    else
    
    
    set _earnratio=_selfbuy; 
    set _amount=_amt*(1+_selfbuy/100); 
    end if;
    if num<=_valid and _amount>0 then

    UPDATE g_member SET money=money+_amt,message=message+1 WHERE username=_user;
    select money into _now from g_member where  username=_user;
    INSERT INTO g_finance_record (username,bank,amount,balance,addtime,reason,note,editor,mid,item_id) 
        VALUES (_user,'平台账户获得',_amount,_now,UNIX_TIMESTAMP(now()),'项目回款','','admin',28,_item);
    set _title=concat('项目回款收益-',_tmptitle);
    set _msg=concat(concat('您参与的项目-',_tmptitle,'-已回款，获得收益'),_amount,'元');
    insert into g_message(title,typeid,content,touser,addtime,status) values(_title,4,_msg,_user,UNIX_TIMESTAMP(now()),3);
    insert into g_crowd_share(title,msg,cid,vid,addtime,username,deposit,ratio,earn,earnratio) 
                values(_title,_msg,_item,_vid,UNIX_TIMESTAMP(now()),_user,_amt,_amt/_target,_amount,_earnratio);
    end if;

UNTIL done END REPEAT;
close members;
update g_crowd_28 set typeid=5 where itemid=_cid;
END$$

DROP PROCEDURE IF EXISTS `pro_count`$$
CREATE PROCEDURE `pro_count`(`_date` VARCHAR(20))
begin
	
	declare fromTime int;
	declare toTime int;
	
	if not _date then
		set _date=date_add(curdate(), interval -1 day);
	end if;
	
	set toTime=unix_timestamp(_date);
	set fromTime=toTime-24*3600;
	
	insert into ssc_count(`type`, playedId, `date`, betCount, betAmount, zjAmount)
	select `type`, playedId, _date, sum(money), sum(bonus) from ssc_bets where kjTime between fromTime and toTime and isDelete=0 group by type, playedId
	on duplicate key update betCount=values(betCount), betAmount=values(betAmount), zjAmount=values(zjAmount);


end$$

DROP PROCEDURE IF EXISTS `pro_pay`$$
CREATE PROCEDURE `pro_pay`()
begin

	declare _m_id int;					
	declare _addmoney float(10,2);		

	declare _h_fee float(10,2);		

	declare _rechargeTime varchar(20);	

	declare _rechargeId varchar(64);		

	declare _info varchar(64) character set utf8;	
	
	declare _uid int;
	declare _coin float;
	declare _fcoin float;
	
	declare _r_id int;
	declare _amount float;
	
	declare currentTime int default unix_timestamp();
	declare _liqType int default 1;
	declare info varchar(64) character set utf8 default '自动到账';
	declare done int default 0;
	
	declare isFirstRecharge int;
	
	declare cur cursor for
	select m.id, m.addmoney, m.h_fee, m.o_time, m.u_id, m.memo,		u.`uid`, u.coin, u.fcoin,		r.id, r.amount from ssc_members u, my18_pay m, ssc_member_recharge r where u.`uid`=r.`uid` and r.rechargeId=m.u_id and m.`state`=0 and r.`state`=0 and r.isDelete=0;
	declare continue HANDLER for not found set done = 1;

	start transaction;
		open cur;
			repeat
				fetch cur into _m_id, _addmoney, _h_fee, _rechargeTime, _rechargeId, _info, _uid, _coin, _fcoin, _r_id, _amount;
				
				if not done then
					
					
						call setCoin(_addmoney, 0, _uid, _liqType, 0, info, _r_id, _rechargeId, '');
						if _h_fee>0 then
							call setCoin(_h_fee, 0, _uid, _liqType, 0, '充值手续费', _r_id, _rechargeId, '');
						end if;
						update ssc_member_recharge set rechargeAmount=_addmoney+_h_fee, coin=_coin, fcoin=_fcoin, rechargeTime=currentTime, `state`=2, `info`=info where id=_r_id;
						update my18_pay set `state`=1 where id=_m_id;
						
						

						call isFirstRechargeCom(_uid, isFirstRecharge);
						if isFirstRecharge then
							call setRechargeCom(_addmoney, _uid, _r_id, _rechargeId);
						end if;
					
						
					
				end if;
				
			until done end repeat;
		close cur;
	commit;
	
	
end$$

DELIMITER ;

-- =====================================================
-- 表结构: phone_msg
-- =====================================================
DROP TABLE IF EXISTS `phone_msg`;
CREATE TABLE `phone_msg` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `truename` varchar(50) NOT NULL DEFAULT '0',
  `contact` varchar(128) NOT NULL DEFAULT '',
  `content` text NOT NULL,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `services` varchar(255) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_admin
-- =====================================================
DROP TABLE IF EXISTS `wolive_admin`;
CREATE TABLE `wolive_admin` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `addtime` int(11) NOT NULL DEFAULT '0',
  `is_delete` smallint(6) NOT NULL DEFAULT '0',
  `app_max_count` int(11) NOT NULL DEFAULT '0',
  `permission` longtext,
  `remark` varchar(255) NOT NULL DEFAULT '',
  `expire_time` int(11) NOT NULL DEFAULT '0' COMMENT '账户有效期至，0表示永久',
  `mobile` varchar(255) NOT NULL DEFAULT '' COMMENT '手机号',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

INSERT INTO `wolive_admin` (`id`, `username`, `password`, `addtime`, `is_delete`, `app_max_count`, `permission`, `remark`, `expire_time`, `mobile`) VALUES ('1', 'admin', '02dd66813c74ea878176e00c6f171f03', '0', '0', '0', NULL, '', '0', '');

-- =====================================================
-- 表结构: wolive_admin_log
-- =====================================================
DROP TABLE IF EXISTS `wolive_admin_log`;
CREATE TABLE `wolive_admin_log` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `uid` int(11) DEFAULT NULL COMMENT '管理员ID',
  `info` text COMMENT '操作结果',
  `ip` varchar(20) NOT NULL DEFAULT '' COMMENT '操作IP',
  `user_agent` text NOT NULL COMMENT 'User-Agent',
  `create_time` int(11) DEFAULT NULL COMMENT '操作时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='管理员登录日志';

-- (跳过数据导出: wolive_admin_log - 运行时数据)

-- =====================================================
-- 表结构: wolive_admin_menu
-- =====================================================
DROP TABLE IF EXISTS `wolive_admin_menu`;
CREATE TABLE `wolive_admin_menu` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `pid` int(11) NOT NULL DEFAULT '0' COMMENT '父级ID',
  `title` varchar(50) DEFAULT NULL COMMENT '名称',
  `href` varchar(50) NOT NULL COMMENT '地址',
  `icon` varchar(50) DEFAULT NULL COMMENT '图标',
  `sort` tinyint(4) NOT NULL DEFAULT '99' COMMENT '排序',
  `type` tinyint(1) DEFAULT '1' COMMENT '菜单',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态',
  PRIMARY KEY (`id`),
  KEY `pid` (`pid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COMMENT='权限表';

INSERT INTO `wolive_admin_menu` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`) VALUES ('1', '0', '主页', '/backend/index/home', 'layui-icon layui-icon-home', '1', '1', '1');
INSERT INTO `wolive_admin_menu` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`) VALUES ('2', '0', '登录日志', '/backend/log/index', 'layui-icon layui-icon-layouts', '3', '1', '1');
INSERT INTO `wolive_admin_menu` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`) VALUES ('3', '0', '商户管理', '', 'layui-icon layui-icon-username', '1', '0', '1');
INSERT INTO `wolive_admin_menu` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`) VALUES ('4', '3', '商户列表', '/backend/busines/index', '', '99', '1', '1');
INSERT INTO `wolive_admin_menu` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`) VALUES ('5', '3', '客服列表', '/backend/services/index', NULL, '99', '1', '1');
INSERT INTO `wolive_admin_menu` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`) VALUES ('6', '0', '存储设置', '/backend/storage/index', 'layui-icon layui-icon-set-fill', '2', '1', '1');

-- =====================================================
-- 表结构: wolive_admin_permission
-- =====================================================
DROP TABLE IF EXISTS `wolive_admin_permission`;
CREATE TABLE `wolive_admin_permission` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `pid` int(11) NOT NULL DEFAULT '0' COMMENT '父级ID',
  `title` varchar(50) DEFAULT NULL COMMENT '名称',
  `href` varchar(50) NOT NULL COMMENT '地址',
  `icon` varchar(50) DEFAULT NULL COMMENT '图标',
  `sort` tinyint(4) NOT NULL DEFAULT '99' COMMENT '排序',
  `type` tinyint(1) DEFAULT '1' COMMENT '菜单',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '状态',
  `is_admin` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否管理员',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `pid` (`pid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='权限表';

INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('1', '0', '主页', '/service/index/home', 'layui-icon layui-icon-home', '1', '1', '1', '0');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('2', '0', '客服管理', '', 'layui-icon layui-icon-username', '2', '0', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('3', '2', '客服列表', '/service/services/index', NULL, '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('4', '2', '客服分组', '/service/groups/index', NULL, '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('5', '26', '评价列表', '/service/comments/index', 'layui-icon layui-icon-praise', '5', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('6', '28', '评价设置', '/service/comments/setting', 'layui-icon layui-icon-tabs', '6', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('7', '28', '常见问题设置', '/service/questions/index', 'layui-icon layui-icon-survey', '4', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('8', '0', '客户管理', '', 'layui-icon layui-icon-user', '3', '0', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('9', '8', '客户列表', '/service/visitors/index', NULL, '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('10', '8', '客户分组', '/service/vgroups/index', NULL, '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('11', '28', '问候语设置', '/service/setting/sentence', 'layui-icon layui-icon-release', '6', '1', '1', '0');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('12', '26', '消息记录', '/service/history/index', 'layui-icon layui-icon-form', '7', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('13', '0', '客服工作台', '/service/chat/index', 'layui-icon layui-icon-service', '1', '1', '1', '0');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('14', '28', '机器人知识库', '/service/robots/index', 'layui-icon layui-icon-service', '4', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('15', '0', '对接配置', '', 'layui-icon layui-icon-unlink', '8', '0', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('16', '15', '接入配置', '/service/setting/access', NULL, '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('17', '15', '接入方式', '/service/setting/course', NULL, '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('18', '0', '系统设置', '/service/setting/index', 'layui-icon layui-icon-set', '1', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('23', '26', '登录日志', '/service/log/index', 'layui-icon layui-icon-layouts', '8', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('24', '26', '数据统计', '/service/log/data', 'layui-icon layui-icon-senior', '8', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('25', '28', '违禁词设置', '/service/banwords/index', 'layui-icon layui-icon-face-cry', '4', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('26', '0', '统计管理', '', 'layui-icon layui-icon-senior', '9', '0', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('27', '0', '留言管理', '/service/vgroups/msglist', 'layui-icon layui-icon-release', '9', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('28', '0', '常用设置', '', 'layui-icon layui-icon-survey', '4', '0', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('29', '0', '客户电话', '/service/vgroups/phonelist', 'layui-icon layui-icon-cellphone', '10', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('30', '28', '广告管理', '/service/settingnow/index', 'layui-icon layui-icon-face-cry', '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('31', '0', '实名认证', '/service/certification/index.html', 'layui-icon layui-icon-auz', '12', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('32', '0', '使用教程', '/index/jc.html', 'layui-icon layui-icon-file-b', '99', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('33', '28', '支付方式设置', '/service/payment/index', 'layui-icon layui-icon-rmb', '5', '1', '1', '1');
INSERT INTO `wolive_admin_permission` (`id`, `pid`, `title`, `href`, `icon`, `sort`, `type`, `status`, `is_admin`) VALUES ('34', '0', '流动广告', '/service/marquee_ad/index', 'layui-icon layui-icon-release', '5', '1', '1', '1');

-- =====================================================
-- 表结构: wolive_admin_token
-- =====================================================
DROP TABLE IF EXISTS `wolive_admin_token`;
CREATE TABLE `wolive_admin_token` (
  `token` varchar(50) NOT NULL COMMENT 'Token',
  `user_id` int(11) unsigned NOT NULL DEFAULT '0',
  `createtime` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '创建时间',
  `expiretime` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '过期时间',
  PRIMARY KEY (`token`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='Token表';

-- (跳过数据导出: wolive_admin_token - 运行时数据)

-- =====================================================
-- 表结构: wolive_attachment_data
-- =====================================================
DROP TABLE IF EXISTS `wolive_attachment_data`;
CREATE TABLE `wolive_attachment_data` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT '附件id',
  `service_id` int(10) unsigned NOT NULL DEFAULT '0',
  `admin_id` int(10) unsigned NOT NULL DEFAULT '0',
  `filename` varchar(255) NOT NULL DEFAULT '' COMMENT '原文件名',
  `fileext` varchar(20) NOT NULL COMMENT '文件扩展名',
  `filesize` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '文件大小',
  `url` varchar(600) NOT NULL DEFAULT '',
  `filemd5` varchar(64) NOT NULL DEFAULT '',
  `inputtime` int(10) unsigned NOT NULL COMMENT '入库时间',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `inputtime` (`inputtime`) USING BTREE,
  KEY `fileext` (`fileext`) USING BTREE,
  KEY `uid` (`service_id`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='附件归档表';

INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('1', '1', '0', '1240.png', 'png', '1144967', '/upload/images/1/6276697069be51651927408.png', '7a0774c08e757bbed617c346c1e8ee6b', '1651927408');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('2', '15', '0', '_Upload_Task_thumb_62652e7b1653d.jpg', 'jpg', '63429', '/upload/images/8/6286f3de313b21653011422.jpg', 'afb3cbfa409c91af9429a6e2b2af6e78', '1653011422');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('3', '1', '0', '下载.png', 'png', '3865', '/upload/images/1/62a1f949e33811654782281.png', 'dc5e7710579d74450ab2b6bfd6090810', '1654782281');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('4', '1', '0', '下载.png', 'png', '3814', '/upload/images/1/6358957a7a8521666749818.png', 'aaf8345eebccff58f587324aadd2eae9', '1666749818');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('5', '1', '0', 'ewm.png', 'png', '3866', '/upload/images/1/6403ebe3068251677978595.png', '09b165db64ea04e65052edd1eafcc4cd', '1677978595');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('6', '1', '0', '下载.png', 'png', '3866', '/upload/images/1/640c937f94e261678545791.png', '09b165db64ea04e65052edd1eafcc4cd', '1678545791');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('7', '54', '0', 'G2GJV9(B7N47D3{D_LTKW)5.png', 'png', '275213', '/upload/images/45/6416862b4e8a81679197739.png', '44c241bd6cd27d7f5c791603b27bc065', '1679197739');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('8', '54', '0', 'G2GJV9(B7N47D3{D_LTKW)5.png', 'png', '275213', '/upload/images/45/64168c10b34dc1679199248.png', '44c241bd6cd27d7f5c791603b27bc065', '1679199248');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('9', '46', '0', '63f81ef089074.jpeg', 'jpeg', '102199', 'https://ddhudong.oss-cn-beijing.aliyuncs.com/upload/images/37/3820be27d8e700d193ff33a27c29293b08b470fe.jpeg', '74fede3aa5d483c2014c61a84e7f8998', '1679711869');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('10', '1', '0', 'app1.png', 'png', '6343', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/1e0585aece55032ac56c4140314958801f9c6b8a.png', '3dbbdd376e47dbd8809314801ca4e683', '1679727426');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('11', '46', '0', 'ai_service .png', 'png', '3782', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/0671ea1d6d930a87c054e90deb25499aa24b52ae.png', '72018229ab1cad2bbb87ad1736e89631', '1679742994');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('12', '1', '0', 'app1.png', 'png', '6343', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/ce059e847a5e4db69839a1c0382d5f8a5360428a.png', '3dbbdd376e47dbd8809314801ca4e683', '1679811074');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('13', '1', '0', 'app1.png', 'png', '6343', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/e788b526f1fbf4dbee4f900a83173a18317e25e8.png', '3dbbdd376e47dbd8809314801ca4e683', '1679811111');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('14', '46', '0', 'guanli.png', 'png', '101667', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/a519efda28e01a6f118707934381bb4aecb10614.png', 'fc2ddf33ac93ddf3286cab4b1bba3abd', '1680011463');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('15', '46', '0', 'bg.jpg', 'jpg', '83439', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/7d8d57320f0fb5a3ee23baa5a48915b5381b054c.jpg', '63e79852b6f557713cd69fdca6871281', '1680011478');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('16', '46', '0', 'nav2s.png', 'png', '50149', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/6843a34f756c8e683f096e8d9cf8976766dc7c06.png', 'da263399f5247796dc5b01273a57b8f0', '1680011532');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('17', '1', '0', 'logo666.png', 'png', '5001', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/463c6c71670a22a41932bf706974b23596f0d040.png', '1d2432850192a7721cfb0e4688f98bda', '1680011949');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('18', '46', '0', 'nav3.png', 'png', '19381', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/1081c7aaece52f126409a82480d05d495dd0f8bc.png', '49de0f5b963604be1ba26fc65e7b97b2', '1680019251');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('19', '46', '0', 'nav2s.png', 'png', '50149', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/304e223c5cf68316119588891c20129c7da12535.png', 'da263399f5247796dc5b01273a57b8f0', '1680019702');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('20', '46', '0', 'gou.png', 'png', '71368', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/ea5b2634bcbd92e1b3fe79a6853a1d5b97fdfa9c.png', 'd37852471b222f86a57292bccc859230', '1680019786');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('21', '46', '0', 'nav3s.png', 'png', '59654', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/97a2f71fa1cc086e8c4cffbf5899687864fea816.png', '66e2e69a731c16a4549249babf3cfa5a', '1680019816');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('22', '1', '0', '1-1Z6061G352K8.jpg', 'jpg', '120055', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/4fede6f373a64c145df3135882b48b98b00de9b4.jpg', '14e11d26f65633bf489e8cda8462bd6e', '1680019864');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('23', '1', '0', '1-1Z6061G352K8.jpg', 'jpg', '120055', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/22f4ef37a2efafcb705f3275f34f1d40852022ea.jpg', '14e11d26f65633bf489e8cda8462bd6e', '1680019913');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('24', '46', '0', 'j.png', 'png', '72235', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/f6b7187905b27a3af0d54411a9d196e338e46a7a.png', '5c0eea9f58ddeba7ccd684c65c35c108', '1680019945');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('25', '1', '0', 'logo.jpg', 'jpg', '14753', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/b8cb3603056ca89a87f81dfcdb17cfe603d93e28.jpg', '55b5f09729c8c5993782b2f845afa97c', '1680020264');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('26', '46', '0', '1-1Z43015093aV.jpg', 'jpg', '141616', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/9c5a3ac09f9c58582f8ee8e84fade9d64211ace4.jpg', '85d37ba95c62d0ed45d3058d610b6a93', '1680020426');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('27', '46', '0', 'b5.jpg', 'jpg', '107481', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/37/3fdbe1e9b0e56f8fcc884405e3854cdfc3c9789c.jpg', '1c3b5c3a8f6dd80647d62e2f88277c0d', '1680020456');
INSERT INTO `wolive_attachment_data` (`id`, `service_id`, `admin_id`, `filename`, `fileext`, `filesize`, `url`, `filemd5`, `inputtime`) VALUES ('28', '1', '0', '下载 (1).png', 'png', '3901', 'https://aiyuankfcc.oss-cn-beijing.aliyuncs.com/upload/images/1/f55e39eb08ed1da0bb9656ba104c571a371d5c07.png', '25a15e817a3b145f47841cd1942c9f09', '1680486196');

-- =====================================================
-- 表结构: wolive_banword
-- =====================================================
DROP TABLE IF EXISTS `wolive_banword`;
CREATE TABLE `wolive_banword` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `keyword` varchar(255) NOT NULL DEFAULT '' COMMENT '关键词',
  `lang` char(50) NOT NULL DEFAULT 'cn',
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1' COMMENT '1显示 0不显示',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

INSERT INTO `wolive_banword` (`id`, `business_id`, `keyword`, `lang`, `status`) VALUES ('3', '1', '&lt;script&gt;', 'cn', '1');
INSERT INTO `wolive_banword` (`id`, `business_id`, `keyword`, `lang`, `status`) VALUES ('4', '1', '&lt;a&gt;', 'cn', '1');
INSERT INTO `wolive_banword` (`id`, `business_id`, `keyword`, `lang`, `status`) VALUES ('5', '1', '&lt;', 'cn', '1');

-- =====================================================
-- 表结构: wolive_business
-- =====================================================
DROP TABLE IF EXISTS `wolive_business`;
CREATE TABLE `wolive_business` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `business_name` varchar(100) NOT NULL COMMENT '商家标识符',
  `logo` varchar(255) NOT NULL DEFAULT '',
  `pctab` int(11) NOT NULL DEFAULT '0' COMMENT 'tab标签',
  `copyright` varchar(255) NOT NULL DEFAULT '' COMMENT '底部版权信息',
  `admin_id` int(11) NOT NULL DEFAULT '0',
  `video_state` enum('close','open') NOT NULL DEFAULT 'close' COMMENT '是否开启视频',
  `voice_state` enum('close','open') NOT NULL DEFAULT 'open' COMMENT '是否开启提示音',
  `audio_state` enum('close','open') NOT NULL DEFAULT 'close' COMMENT '是否开启音频',
  `template_state` enum('close','open') NOT NULL DEFAULT 'close' COMMENT '是否开启模板消息',
  `distribution_rule` enum('auto','claim') DEFAULT 'auto' COMMENT 'claim:认领，auto:自动分配',
  `voice_address` varchar(255) NOT NULL DEFAULT '/upload/voice/default.mp3' COMMENT '提示音文件地址',
  `remark` varchar(255) NOT NULL DEFAULT '',
  `expire_time` int(11) NOT NULL DEFAULT '0',
  `max_count` int(11) NOT NULL DEFAULT '0',
  `push_url` varchar(255) NOT NULL DEFAULT '' COMMENT '推送url',
  `state` enum('close','open') NOT NULL DEFAULT 'open' COMMENT '''open'': 打开该商户 ，‘close’：禁止该商户',
  `is_recycle` tinyint(2) NOT NULL DEFAULT '0',
  `is_delete` tinyint(2) NOT NULL DEFAULT '0',
  `lang` char(50) DEFAULT 'cn',
  `bd_trans_appid` varchar(255) DEFAULT NULL COMMENT '百度翻译APPID',
  `bd_trans_secret` varchar(255) DEFAULT NULL COMMENT '百度翻译密钥',
  `google_trans_key` varchar(255) DEFAULT NULL COMMENT '谷歌翻译KEY',
  `auto_trans` tinyint(1) NOT NULL DEFAULT '0' COMMENT '发送客服是否自动翻译',
  `auto_ip` tinyint(1) NOT NULL DEFAULT '0' COMMENT '根据IP自动设置客户语言',
  `trans_type` tinyint(1) NOT NULL DEFAULT '0' COMMENT '翻译接口：百度0；谷歌1',
  `theme` char(50) NOT NULL DEFAULT '13c9cb' COMMENT '主题颜色',
  `chat_tpl` varchar(20) NOT NULL DEFAULT 'default' COMMENT '访客界面模板',
  `header` char(50) NOT NULL DEFAULT '13c9cb' COMMENT '悬浮条背景色',
  `aboutus` longtext,
  `img1` varchar(255) DEFAULT NULL,
  `img2` varchar(255) DEFAULT NULL,
  `img3` varchar(255) DEFAULT NULL,
  `img4` varchar(255) DEFAULT NULL,
  `img5` varchar(255) DEFAULT NULL,
  `img6` varchar(255) DEFAULT NULL,
  `img7` varchar(255) DEFAULT NULL,
  `img8` varchar(255) DEFAULT NULL,
  `certificationleft` varchar(255) NOT NULL COMMENT '身份证正面',
  `certificationright` varchar(255) NOT NULL COMMENT '身份证反面',
  `businesslicence` varchar(255) NOT NULL COMMENT '营业执照',
  `bussage` varchar(255) NOT NULL,
  `bussname` varchar(255) NOT NULL,
  `bussphone` varchar(255) NOT NULL,
  `busszfb` varchar(255) NOT NULL,
  `bussmaill` varchar(255) NOT NULL,
  `busszfbimg` varchar(255) NOT NULL,
  `is_shenhe` int(11) NOT NULL DEFAULT '0',
  `is_qiangzhi` int(11) NOT NULL DEFAULT '0',
  `shenhetime` date NOT NULL,
  `imgurl2` varchar(255) DEFAULT NULL,
  `imgurl3` varchar(255) DEFAULT NULL,
  `imgurl4` varchar(255) DEFAULT NULL,
  `imgurl5` varchar(255) DEFAULT NULL,
  `imgurl6` varchar(255) DEFAULT NULL,
  `ts1` varchar(255) NOT NULL,
  `ts2` varchar(255) NOT NULL,
  `ts3` varchar(255) NOT NULL,
  `baidu_map_key` varchar(200) NOT NULL COMMENT '百度地图秘钥',
  `location_state` enum('close','open') NOT NULL DEFAULT 'open' COMMENT '是否开启定位',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `bussiness` (`business_name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='商家表';

INSERT INTO `wolive_business` (`id`, `business_name`, `logo`, `pctab`, `copyright`, `admin_id`, `video_state`, `voice_state`, `audio_state`, `template_state`, `distribution_rule`, `voice_address`, `remark`, `expire_time`, `max_count`, `push_url`, `state`, `is_recycle`, `is_delete`, `lang`, `bd_trans_appid`, `bd_trans_secret`, `google_trans_key`, `auto_trans`, `auto_ip`, `trans_type`, `theme`, `chat_tpl`, `header`, `aboutus`, `img1`, `img2`, `img3`, `img4`, `img5`, `img6`, `img7`, `img8`, `certificationleft`, `certificationright`, `businesslicence`, `bussage`, `bussname`, `bussphone`, `busszfb`, `bussmaill`, `busszfbimg`, `is_shenhe`, `is_qiangzhi`, `shenhetime`, `imgurl2`, `imgurl3`, `imgurl4`, `imgurl5`, `imgurl6`, `ts1`, `ts2`, `ts3`, `baidu_map_key`, `location_state`) VALUES ('1', 'admin', '', '0', '', '0', 'open', 'open', 'close', 'close', 'auto', '/upload/voice/default.mp3', '', '0', '0', '', 'open', '0', '0', 'cn', '', '', '', '1', '1', '0', '0f9fa4', 'default', '0f9fa4', '&lt;p&gt;&lt;span style=&quot;color:#4f81bd&quot;&gt;&lt;span style=&quot;font-size: 18px;&quot;&gt;&lt;strong&gt;在线客服系统&lt;/strong&gt;&lt;/span&gt;&lt;/span&gt;&lt;/p&gt;&lt;p&gt;-------&lt;/p&gt;&lt;p&gt;&lt;span style=&quot;color: rgb(0, 0, 0);&quot;&gt;&lt;strong&gt;支持：文字 / 表情 / 语音 / 文件 / 位置等富媒体聊天方式。&lt;/strong&gt;&lt;/span&gt;&lt;/p&gt;&lt;p&gt;&lt;strong&gt;&lt;span style=&quot;color: rgb(192, 0, 0);&quot;&gt;支持：多国语言翻译，机器人术语，欢迎语回复，语音消息提醒，0延迟消息即时接收&lt;/span&gt;&lt;/strong&gt;&lt;strong&gt;&lt;span style=&quot;color: rgb(192, 0, 0);&quot;&gt;，微信消息模板对接，手机PC端同步聊天，广告位自定义，历史消息下载，在线留言功能等出色功能。&lt;/span&gt;&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;&lt;span style=&quot;color: rgb(0, 0, 0);&quot;&gt;--------&lt;/span&gt;&lt;/p&gt;&lt;p&gt;&lt;br/&gt;&lt;/p&gt;', '/upload/images/6403eed9a3e917830.png', '/upload/images/6403ef6d6c307246.png', '/upload/images/6403ef74e46255522.png', '/upload/images/6403ef8008c3f7898.png', '/upload/images/6403ef860abd14018.png', '/upload/images/6403ef21e956b4223.png', '', '', '/upload/images/69a4cdb63126f4527.jpeg', '/upload/images/69a4cdb8440362723.jpeg', '/upload/images/69a4cdba674e6599.jpeg', '18', 'HUANG JINGDAI', '09999788888', 'minyi', 'jwzz693@icloud.com', '/upload/images/69a4cdbd831aa9196.jpeg', '2', '0', '2026-03-02', 'https://www.baidu.com', 'https://www.baidu.com', 'https://www.baidu.com', 'https://www.baidu.com', 'https://www.baidu.com', '', '', '', '7BTnGhlneYhsMyRwnLfiw0n7qvMwkblm', 'open');
INSERT INTO `wolive_business` (`id`, `business_name`, `logo`, `pctab`, `copyright`, `admin_id`, `video_state`, `voice_state`, `audio_state`, `template_state`, `distribution_rule`, `voice_address`, `remark`, `expire_time`, `max_count`, `push_url`, `state`, `is_recycle`, `is_delete`, `lang`, `bd_trans_appid`, `bd_trans_secret`, `google_trans_key`, `auto_trans`, `auto_ip`, `trans_type`, `theme`, `chat_tpl`, `header`, `aboutus`, `img1`, `img2`, `img3`, `img4`, `img5`, `img6`, `img7`, `img8`, `certificationleft`, `certificationright`, `businesslicence`, `bussage`, `bussname`, `bussphone`, `busszfb`, `bussmaill`, `busszfbimg`, `is_shenhe`, `is_qiangzhi`, `shenhetime`, `imgurl2`, `imgurl3`, `imgurl4`, `imgurl5`, `imgurl6`, `ts1`, `ts2`, `ts3`, `baidu_map_key`, `location_state`) VALUES ('58', 'yuanfang', '', '0', '', '0', 'close', 'open', 'close', 'close', 'auto', '/upload/voice/default.mp3', '', '1932998400', '0', '', 'open', '0', '0', 'cn', NULL, NULL, NULL, '0', '0', '0', '13c9cb', 'default', '13c9cb', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '', '', '', '', '', '', '', '', '', '0', '0', '0000-00-00', NULL, NULL, NULL, NULL, NULL, '', '', '', '', 'open');

-- =====================================================
-- 表结构: wolive_chats
-- =====================================================
DROP TABLE IF EXISTS `wolive_chats`;
CREATE TABLE `wolive_chats` (
  `cid` int(11) NOT NULL AUTO_INCREMENT,
  `visiter_id` varchar(200) NOT NULL COMMENT '访客id',
  `service_id` int(11) NOT NULL COMMENT '客服id',
  `business_id` int(11) NOT NULL DEFAULT '0' COMMENT '商家id',
  `content` mediumtext NOT NULL COMMENT '内容',
  `timestamp` int(11) NOT NULL,
  `state` enum('readed','unread') NOT NULL DEFAULT 'unread' COMMENT 'unread 未读；readed 已读',
  `direction` enum('to_visiter','to_service') DEFAULT NULL,
  `unstr` varchar(50) NOT NULL DEFAULT '' COMMENT '前端唯一字符串用于撤销使用',
  `type` tinyint(1) NOT NULL DEFAULT '1',
  `content_trans` mediumtext NOT NULL COMMENT '译文',
  `is_read` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已读',
  PRIMARY KEY (`cid`) USING BTREE,
  KEY `visiter_id` (`visiter_id`) USING BTREE,
  KEY `service_id` (`service_id`) USING BTREE,
  KEY `business_id` (`business_id`) USING BTREE,
  KEY `unstr` (`unstr`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='消息表';

-- (跳过数据导出: wolive_chats - 运行时数据)

-- =====================================================
-- 表结构: wolive_comment
-- =====================================================
DROP TABLE IF EXISTS `wolive_comment`;
CREATE TABLE `wolive_comment` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `service_id` int(11) NOT NULL DEFAULT '0',
  `group_id` int(11) NOT NULL DEFAULT '0',
  `visiter_id` varchar(200) NOT NULL DEFAULT '',
  `visiter_name` varchar(255) NOT NULL DEFAULT '',
  `word_comment` text NOT NULL COMMENT '文字评价',
  `add_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_comment_detail
-- =====================================================
DROP TABLE IF EXISTS `wolive_comment_detail`;
CREATE TABLE `wolive_comment_detail` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `comment_id` int(11) unsigned NOT NULL,
  `title` varchar(32) NOT NULL DEFAULT '',
  `score` tinyint(4) NOT NULL DEFAULT '1' COMMENT '分数',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_comment_setting
-- =====================================================
DROP TABLE IF EXISTS `wolive_comment_setting`;
CREATE TABLE `wolive_comment_setting` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `title` varchar(128) NOT NULL DEFAULT '' COMMENT '评价说明',
  `comments` text NOT NULL COMMENT '评价条目',
  `word_switch` enum('close','open') NOT NULL DEFAULT 'close',
  `word_title` varchar(32) NOT NULL DEFAULT '',
  `add_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_group
-- =====================================================
DROP TABLE IF EXISTS `wolive_group`;
CREATE TABLE `wolive_group` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `groupname` varchar(255) DEFAULT NULL,
  `business_id` int(11) unsigned NOT NULL DEFAULT '0',
  `sort` int(11) unsigned NOT NULL DEFAULT '0' COMMENT '排序',
  `create_time` int(11) DEFAULT NULL COMMENT '操作时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

INSERT INTO `wolive_group` (`id`, `groupname`, `business_id`, `sort`, `create_time`) VALUES ('1', '售前1号', '1', '0', '1652615329');
INSERT INTO `wolive_group` (`id`, `groupname`, `business_id`, `sort`, `create_time`) VALUES ('2', '售后2号', '1', '1', '1652615341');
INSERT INTO `wolive_group` (`id`, `groupname`, `business_id`, `sort`, `create_time`) VALUES ('3', '技术3号', '1', '0', '1652615350');
INSERT INTO `wolive_group` (`id`, `groupname`, `business_id`, `sort`, `create_time`) VALUES ('4', '投诉4号', '1', '0', '1652615360');
INSERT INTO `wolive_group` (`id`, `groupname`, `business_id`, `sort`, `create_time`) VALUES ('20', '你好', '58', '0', '1772427255');

-- =====================================================
-- 表结构: wolive_marquee_ad
-- =====================================================
DROP TABLE IF EXISTS `wolive_marquee_ad`;
CREATE TABLE `wolive_marquee_ad` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `business_id` varchar(100) NOT NULL DEFAULT '',
  `content` varchar(500) NOT NULL DEFAULT '' COMMENT '广告文字内容',
  `link_url` varchar(500) NOT NULL DEFAULT '' COMMENT '点击跳转链接',
  `bg_color` varchar(100) NOT NULL DEFAULT 'linear-gradient(90deg, #667eea 0%, #764ba2 100%)' COMMENT '背景颜色',
  `text_color` varchar(30) NOT NULL DEFAULT '#ffffff' COMMENT '文字颜色',
  `speed` int(11) NOT NULL DEFAULT '30' COMMENT '滚动速度秒',
  `duration` int(11) NOT NULL DEFAULT '30' COMMENT '显示时长秒0为永久',
  `sort` int(11) NOT NULL DEFAULT '0' COMMENT '排序',
  `status` tinyint(4) NOT NULL DEFAULT '1' COMMENT '1启用0禁用',
  `is_global` tinyint(4) NOT NULL DEFAULT '0' COMMENT '1=全局自动显示 0=仅手动推送',
  `rotate_interval` int(11) NOT NULL DEFAULT '10' COMMENT '轮播间隔秒数',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_business` (`business_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COMMENT='流动广告表';

INSERT INTO `wolive_marquee_ad` (`id`, `business_id`, `content`, `link_url`, `bg_color`, `text_color`, `speed`, `duration`, `sort`, `status`, `is_global`, `rotate_interval`, `created_at`) VALUES ('2', '1', '12346', '', '#e74c3c', '#1f1e1e', '3', '0', '0', '1', '1', '10', '2026-03-02 10:01:07');
INSERT INTO `wolive_marquee_ad` (`id`, `business_id`, `content`, `link_url`, `bg_color`, `text_color`, `speed`, `duration`, `sort`, `status`, `is_global`, `rotate_interval`, `created_at`) VALUES ('3', '1', '好，您转了给我个详细截图。然后给我您的支付宝账号跟您的姓氏。', 'baidu.com', 'linear-gradient(90deg, #667eea 0%, #764ba2 100%)', '#ffffff', '3', '0', '1', '1', '1', '1', '2026-03-02 10:03:27');
INSERT INTO `wolive_marquee_ad` (`id`, `business_id`, `content`, `link_url`, `bg_color`, `text_color`, `speed`, `duration`, `sort`, `status`, `is_global`, `rotate_interval`, `created_at`) VALUES ('4', '1', '123456789', '', 'linear-gradient(90deg, #667eea 0%, #764ba2 100%)', '#ffffff', '4', '0', '0', '1', '1', '5', '2026-03-02 10:26:49');
INSERT INTO `wolive_marquee_ad` (`id`, `business_id`, `content`, `link_url`, `bg_color`, `text_color`, `speed`, `duration`, `sort`, `status`, `is_global`, `rotate_interval`, `created_at`) VALUES ('5', '58', '广告测试', '', 'linear-gradient(90deg, #667eea 0%, #764ba2 100%)', '#ffffff', '5', '0', '0', '1', '1', '3', '2026-03-02 10:39:50');
INSERT INTO `wolive_marquee_ad` (`id`, `business_id`, `content`, `link_url`, `bg_color`, `text_color`, `speed`, `duration`, `sort`, `status`, `is_global`, `rotate_interval`, `created_at`) VALUES ('6', '58', '继续G8啊你好测试', '', 'linear-gradient(90deg, #667eea 0%, #764ba2 100%)', '#ffffff', '5', '0', '0', '1', '1', '5', '2026-03-02 10:40:24');

-- =====================================================
-- 表结构: wolive_message
-- =====================================================
DROP TABLE IF EXISTS `wolive_message`;
CREATE TABLE `wolive_message` (
  `mid` int(11) NOT NULL AUTO_INCREMENT,
  `content` text NOT NULL COMMENT '留言内容',
  `name` varchar(255) NOT NULL COMMENT '留言人姓名',
  `moblie` varchar(255) NOT NULL COMMENT '留言人电话',
  `email` varchar(255) NOT NULL COMMENT '留言人邮箱',
  `business_id` int(11) DEFAULT '0',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`mid`) USING BTREE,
  KEY `timestamp` (`timestamp`) USING BTREE,
  KEY `web` (`business_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_msg
-- =====================================================
DROP TABLE IF EXISTS `wolive_msg`;
CREATE TABLE `wolive_msg` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `truename` varchar(50) NOT NULL DEFAULT '0',
  `contact` varchar(128) NOT NULL DEFAULT '',
  `content` text NOT NULL,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ip` varchar(255) NOT NULL,
  `services` varchar(255) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_option
-- =====================================================
DROP TABLE IF EXISTS `wolive_option`;
CREATE TABLE `wolive_option` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `group` varchar(255) NOT NULL DEFAULT '',
  `title` varchar(255) NOT NULL,
  `value` longtext NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `business_id` (`business_id`) USING BTREE,
  KEY `group` (`group`) USING BTREE,
  KEY `name` (`title`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_payment_method
-- =====================================================
DROP TABLE IF EXISTS `wolive_payment_method`;
CREATE TABLE `wolive_payment_method` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `method_name` varchar(64) NOT NULL DEFAULT '' COMMENT '支付方式名称',
  `account_info` varchar(255) NOT NULL DEFAULT '' COMMENT '收款账号/地址',
  `qrcode_url` varchar(512) NOT NULL DEFAULT '' COMMENT '收款二维码图片URL',
  `payment_link` varchar(500) DEFAULT '' COMMENT '支付跳转链接',
  `sort` int(11) NOT NULL DEFAULT '0' COMMENT '排序',
  `status` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1启用0禁用',
  `add_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_business` (`business_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

INSERT INTO `wolive_payment_method` (`id`, `business_id`, `method_name`, `account_info`, `qrcode_url`, `payment_link`, `sort`, `status`, `add_time`) VALUES ('2', '1', '支付宝', '13131125872', '/upload/images/1/payment/1772412620.jpeg', 'baidu.com', '0', '1', '2026-03-02 08:50:27');

-- =====================================================
-- 表结构: wolive_question
-- =====================================================
DROP TABLE IF EXISTS `wolive_question`;
CREATE TABLE `wolive_question` (
  `qid` int(11) NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `question` longtext NOT NULL,
  `keyword` varchar(12) NOT NULL DEFAULT '' COMMENT '关键词',
  `sort` int(11) NOT NULL DEFAULT '0',
  `answer` longtext NOT NULL,
  `answer_read` longtext NOT NULL,
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1' COMMENT '1显示 0不显示',
  `lang` char(50) NOT NULL DEFAULT 'cn',
  PRIMARY KEY (`qid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='常见问题表';

INSERT INTO `wolive_question` (`qid`, `business_id`, `question`, `keyword`, `sort`, `answer`, `answer_read`, `status`, `lang`) VALUES ('37', '1', 'USDT充值', 'USDT', '0', '<p>请稍等</p>', '', '1', 'cn');

-- =====================================================
-- 表结构: wolive_queue
-- =====================================================
DROP TABLE IF EXISTS `wolive_queue`;
CREATE TABLE `wolive_queue` (
  `qid` int(11) NOT NULL AUTO_INCREMENT,
  `visiter_id` varchar(200) NOT NULL COMMENT '访客id',
  `service_id` int(11) NOT NULL COMMENT '客服id',
  `groupid` int(11) DEFAULT '0' COMMENT '客服分类id',
  `business_id` int(11) NOT NULL DEFAULT '0',
  `state` enum('normal','complete','in_black_list') NOT NULL DEFAULT 'normal' COMMENT 'normal：正常接入,‘complete’:已经解决，‘in_black_list’:黑名单',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `remind_tpl` tinyint(2) NOT NULL DEFAULT '0' COMMENT '是否已发送模板消息',
  `remind_comment` tinyint(2) NOT NULL DEFAULT '0' COMMENT '是否已推送评价',
  PRIMARY KEY (`qid`) USING BTREE,
  KEY `se` (`service_id`) USING BTREE,
  KEY `vi` (`visiter_id`) USING BTREE,
  KEY `business` (`business_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='会话表(排队表)';

-- (跳过数据导出: wolive_queue - 运行时数据)

-- =====================================================
-- 表结构: wolive_reply
-- =====================================================
DROP TABLE IF EXISTS `wolive_reply`;
CREATE TABLE `wolive_reply` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `word` varchar(255) DEFAULT NULL,
  `service_id` int(11) DEFAULT NULL,
  `tag` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_rest_setting
-- =====================================================
DROP TABLE IF EXISTS `wolive_rest_setting`;
CREATE TABLE `wolive_rest_setting` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `state` enum('open','close') NOT NULL DEFAULT 'open',
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `week` varchar(32) NOT NULL DEFAULT '',
  `reply` varchar(255) NOT NULL DEFAULT '',
  `name_state` enum('open','close') NOT NULL DEFAULT 'open',
  `tel_state` enum('open','close') NOT NULL DEFAULT 'open',
  `add_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_robot
-- =====================================================
DROP TABLE IF EXISTS `wolive_robot`;
CREATE TABLE `wolive_robot` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `keyword` varchar(12) NOT NULL DEFAULT '' COMMENT '关键词',
  `sort` int(11) NOT NULL DEFAULT '0',
  `reply` longtext NOT NULL,
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1' COMMENT '1显示 0不显示',
  `lang` char(50) NOT NULL DEFAULT 'cn',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='常见问题表';

-- =====================================================
-- 表结构: wolive_sentence
-- =====================================================
DROP TABLE IF EXISTS `wolive_sentence`;
CREATE TABLE `wolive_sentence` (
  `sid` int(11) NOT NULL AUTO_INCREMENT,
  `content` text NOT NULL COMMENT '内容',
  `service_id` int(11) NOT NULL COMMENT '所属客服id',
  `state` enum('using','unuse') NOT NULL DEFAULT 'using' COMMENT 'unuse: 未使用 ，using：使用中',
  `lang` char(50) NOT NULL DEFAULT 'cn',
  PRIMARY KEY (`sid`) USING BTREE,
  KEY `se` (`service_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_service
-- =====================================================
DROP TABLE IF EXISTS `wolive_service`;
CREATE TABLE `wolive_service` (
  `service_id` int(11) NOT NULL AUTO_INCREMENT,
  `user_name` varchar(255) NOT NULL COMMENT '用户名',
  `nick_name` varchar(255) NOT NULL COMMENT '昵称',
  `password` varchar(255) NOT NULL COMMENT '密码',
  `groupid` varchar(225) DEFAULT '0' COMMENT '客服分类id',
  `phone` varchar(255) DEFAULT '' COMMENT '手机',
  `open_id` varchar(255) NOT NULL DEFAULT '',
  `email` varchar(255) DEFAULT '' COMMENT '邮箱',
  `business_id` int(11) NOT NULL DEFAULT '0',
  `avatar` varchar(1024) NOT NULL DEFAULT '/assets/images/admin/avatar-admin2.png' COMMENT '头像',
  `level` enum('super_manager','manager','service') NOT NULL DEFAULT 'service' COMMENT 'super_manager: 超级管理员，manager：商家管理员 ，service：普通客服',
  `parent_id` int(11) NOT NULL DEFAULT '0' COMMENT '所属商家管理员id',
  `offline_first` tinyint(2) NOT NULL DEFAULT '0',
  `state` enum('online','offline') NOT NULL DEFAULT 'offline' COMMENT 'online：在线，offline：离线',
  PRIMARY KEY (`service_id`) USING BTREE,
  UNIQUE KEY `user_name` (`user_name`) USING BTREE,
  KEY `pid` (`parent_id`) USING BTREE,
  KEY `web` (`business_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='后台客服表';

INSERT INTO `wolive_service` (`service_id`, `user_name`, `nick_name`, `password`, `groupid`, `phone`, `open_id`, `email`, `business_id`, `avatar`, `level`, `parent_id`, `offline_first`, `state`) VALUES ('1', 'admin', '专属客服小爱', 'd8f7c2d2775869fb69b8757edcf6ae4f', '1', '', '', '', '1', '/upload/images/1/1772408357.jpg', 'super_manager', '0', '1', 'offline');
INSERT INTO `wolive_service` (`service_id`, `user_name`, `nick_name`, `password`, `groupid`, `phone`, `open_id`, `email`, `business_id`, `avatar`, `level`, `parent_id`, `offline_first`, `state`) VALUES ('68', 'yuanfang', '真美', '4b752521ed42a2a89b744d6a2c3a5940', '20', '', '', '', '58', '/upload/images/58/1772427346.jpg', 'super_manager', '0', '1', 'online');

-- =====================================================
-- 表结构: wolive_storage
-- =====================================================
DROP TABLE IF EXISTS `wolive_storage`;
CREATE TABLE `wolive_storage` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` int(11) NOT NULL DEFAULT '0',
  `type` tinyint(1) NOT NULL DEFAULT '1' COMMENT '存储类型：1=本地，2=阿里云，3=腾讯云，4=七牛',
  `config` text CHARACTER SET utf8mb4,
  `status` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

INSERT INTO `wolive_storage` (`id`, `admin_id`, `type`, `config`, `status`) VALUES ('1', '1', '1', '{\"access_key\":\"LTAI5tEi5XTpC5C6THfVuWVF\",\"secret_key\":\"uDcQjrvenaXDgpmS2lV69CprrePp7l\",\"domain\":\"oss-cn-beijing.dmkf.com\",\"bucket\":\"dmkf\"}', '1');

-- =====================================================
-- 表结构: wolive_tablist
-- =====================================================
DROP TABLE IF EXISTS `wolive_tablist`;
CREATE TABLE `wolive_tablist` (
  `tid` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL COMMENT 'tab的名称',
  `content_read` text,
  `content` text NOT NULL,
  `business_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`tid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- =====================================================
-- 表结构: wolive_vgroup
-- =====================================================
DROP TABLE IF EXISTS `wolive_vgroup`;
CREATE TABLE `wolive_vgroup` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `service_id` int(11) NOT NULL DEFAULT '0',
  `group_name` varchar(128) NOT NULL DEFAULT '',
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `status` tinyint(4) NOT NULL DEFAULT '1',
  `bgcolor` char(7) NOT NULL DEFAULT '#707070',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

INSERT INTO `wolive_vgroup` (`id`, `business_id`, `service_id`, `group_name`, `create_time`, `status`, `bgcolor`) VALUES ('1', '1', '1', '最近联系', '2023-03-28 22:00:31', '1', '#707070');
INSERT INTO `wolive_vgroup` (`id`, `business_id`, `service_id`, `group_name`, `create_time`, `status`, `bgcolor`) VALUES ('2', '1', '1', '老用户', '2023-03-28 22:00:41', '1', '#707070');
INSERT INTO `wolive_vgroup` (`id`, `business_id`, `service_id`, `group_name`, `create_time`, `status`, `bgcolor`) VALUES ('3', '1', '1', '未下单', '2023-03-28 22:01:01', '1', '#707070');
INSERT INTO `wolive_vgroup` (`id`, `business_id`, `service_id`, `group_name`, `create_time`, `status`, `bgcolor`) VALUES ('6', '58', '68', '阴道', '2026-03-02 10:37:05', '1', '#707070');

-- =====================================================
-- 表结构: wolive_visiter
-- =====================================================
DROP TABLE IF EXISTS `wolive_visiter`;
CREATE TABLE `wolive_visiter` (
  `vid` int(11) NOT NULL AUTO_INCREMENT,
  `visiter_id` varchar(200) NOT NULL COMMENT '访客id',
  `visiter_name` varchar(255) NOT NULL COMMENT '访客名称',
  `channel` varchar(255) NOT NULL COMMENT '用户游客频道',
  `avatar` varchar(1024) NOT NULL COMMENT '头像',
  `name` varchar(255) NOT NULL DEFAULT '' COMMENT '用户自己填写的姓名',
  `tel` varchar(32) NOT NULL DEFAULT '' COMMENT '用户自己填写的电话',
  `login_times` int(11) NOT NULL DEFAULT '1' COMMENT '登录次数',
  `connect` text COMMENT '联系方式',
  `comment` text COMMENT '备注',
  `extends` text COMMENT '浏览器扩展',
  `ip` varchar(255) NOT NULL COMMENT '访客ip',
  `from_url` varchar(255) NOT NULL COMMENT '访客浏览地址',
  `msg_time` timestamp NULL DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '访问时间',
  `business_id` int(11) NOT NULL DEFAULT '0',
  `state` enum('online','offline') NOT NULL DEFAULT 'offline' COMMENT 'offline：离线，online：在线',
  `istop` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '1置顶展示0未置顶',
  `lang` char(255) NOT NULL DEFAULT 'cn',
  PRIMARY KEY (`vid`) USING BTREE,
  UNIQUE KEY `id` (`visiter_id`,`business_id`) USING BTREE,
  KEY `visiter` (`visiter_id`) USING BTREE,
  KEY `time` (`timestamp`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- (跳过数据导出: wolive_visiter - 运行时数据)

-- =====================================================
-- 表结构: wolive_visiter_vgroup
-- =====================================================
DROP TABLE IF EXISTS `wolive_visiter_vgroup`;
CREATE TABLE `wolive_visiter_vgroup` (
  `vid` int(11) NOT NULL,
  `business_id` int(11) NOT NULL DEFAULT '0',
  `service_id` int(11) NOT NULL DEFAULT '0',
  `group_id` int(11) NOT NULL DEFAULT '0',
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`vid`,`group_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT;

-- (跳过数据导出: wolive_visiter_vgroup - 运行时数据)

-- =====================================================
-- 表结构: wolive_wechat_platform
-- =====================================================
DROP TABLE IF EXISTS `wolive_wechat_platform`;
CREATE TABLE `wolive_wechat_platform` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL DEFAULT '0' COMMENT '客服系统id',
  `wx_id` varchar(60) NOT NULL DEFAULT '' COMMENT '公众号原始id',
  `app_id` varchar(255) NOT NULL DEFAULT '' COMMENT '公众号appid',
  `app_secret` varchar(255) NOT NULL DEFAULT '' COMMENT '公众号appsecret',
  `wx_token` varchar(120) NOT NULL DEFAULT '' COMMENT '公众号token',
  `wx_aeskey` varchar(120) NOT NULL DEFAULT '' COMMENT '消息加解密密钥(EncodingAESKey)',
  `visitor_tpl` varchar(255) NOT NULL DEFAULT '' COMMENT '新访客模板消息',
  `msg_tpl` varchar(255) NOT NULL DEFAULT '' COMMENT '新消息提示模板消息',
  `customer_tpl` varchar(255) NOT NULL DEFAULT '' COMMENT '访客模板消息',
  `isscribe` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '是否开启引导关注1开启0关闭',
  `desc` varchar(255) NOT NULL COMMENT '公共号说明、备注',
  `addtime` int(11) NOT NULL DEFAULT '0',
  `is_delete` smallint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `business_id` (`business_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='微信公众号';

INSERT INTO `wolive_wechat_platform` (`id`, `business_id`, `wx_id`, `app_id`, `app_secret`, `wx_token`, `wx_aeskey`, `visitor_tpl`, `msg_tpl`, `customer_tpl`, `isscribe`, `desc`, `addtime`, `is_delete`) VALUES ('13', '1', '', '', '', '', '', '', '', '', '0', '无', '1772418510', '0');

-- =====================================================
-- 表结构: wolive_weixin
-- =====================================================
DROP TABLE IF EXISTS `wolive_weixin`;
CREATE TABLE `wolive_weixin` (
  `wid` int(11) NOT NULL AUTO_INCREMENT,
  `business_id` int(11) NOT NULL COMMENT '商户ID',
  `app_id` varchar(64) NOT NULL DEFAULT '' COMMENT '公众号appid',
  `open_id` varchar(255) NOT NULL COMMENT '微信用户id',
  `subscribe` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '是否关注微信0未关注1已关注',
  `subscribe_time` int(11) NOT NULL DEFAULT '0' COMMENT '关注时间',
  PRIMARY KEY (`wid`) USING BTREE,
  KEY `business_id` (`business_id`) USING BTREE,
  KEY `app_id` (`app_id`) USING BTREE
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

SET FOREIGN_KEY_CHECKS = 1;
