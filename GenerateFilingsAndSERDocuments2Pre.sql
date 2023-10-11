-- select getdate()
-- select convert(time, getdate())

declare @periodStart int = 20230901
declare @cutoffDate datetime2 = '2023-10-11 06:00:00'
declare @Msg varchar(max)
declare @processingStateAbbr varchar(2), @processingStatesLeft int
declare @processingMerchantId int, @processingMerchantsLeft int

declare @states table (stateAbbr varchar(2), processed bit)
--insert @states (stateAbbr, processed) values ('PR', null)
insert @states select Abbr, null from FedTax.dbo.States order by FIPSCode -- and FIPSCode < 6 order by FIPSCode --and FIPSCode < 42

declare @merchants table (merchantId int, processed bit default null)

if @@ROWCOUNT > 0
	BEGIN

	while (select Count(*) from @states where processed is null) > 0
		BEGIN

		select top 1 @processingStateAbbr = stateAbbr from @states where processed is null

		SET @Msg='STARTING ' + @processingStateAbbr + ' at ' + CONVERT(varchar(16), GETDATE(), 121) + ' EDT '
		RAISERROR (@Msg, 0, 1) WITH NOWAIT

		begin transaction

		delete @merchants
		--insert into @merchants (merchantId) values (56674)
		--insert into @merchants (merchantId) values (56748)
		insert into @merchants (merchantId) exec fedtax.dbo.spGetMerchant4Filing @periodStart, null, @processingStateAbbr
		
		if @@ROWCOUNT > 0
			BEGIN
	
			WHILE (SELECT Count(*) from @merchants where processed is null) > 0
				BEGIN
					SELECT Top 1 @processingMerchantId = merchantId from @merchants where processed is null
	
					SET @Msg='STARTING ' + CAST(@processingMerchantId as varchar(20)) + ' at ' + CONVERT(varchar(16), GETDATE(), 121) + ' EDT '
					RAISERROR (@Msg, 0, 1) WITH NOWAIT

					exec FedTax.dbo.spCreateFilingForMerchantState2 @processingMerchantId, @periodStart, @processingStateAbbr, @cutoffDate, 1
					--exec Reports.dbo.spCreateFilingForMerchantState2 @processingMerchantId, @periodStart, @processingStateAbbr, '2021-12-11', 1

					if (@processingStateAbbr = 'CO')
						exec Reports.dbo.spCreateFilingForMerchantForColorado @processingMerchantId, @PeriodStart, '08', 1		
						
					exec FedTax.dbo.spGenerateStateSERSummaryPre2 @processingStateAbbr, @periodStart, @processingMerchantId

					UPDATE @merchants SET processed=1 where merchantId = @processingMerchantId
					SELECT @processingMerchantsLeft=Count(*) from @merchants where processed is null

					SET @Msg='COMPLETED ' + CAST(@processingMerchantId as varchar(20)) + ' at ' + CONVERT(varchar(16), GETDATE(), 121) + ' EDT ' + CAST(@processingMerchantsLeft as varchar(20)) + ' left.'
					RAISERROR (@Msg, 0, 1) WITH NOWAIT

				END
			END

		commit transaction

		update @states set processed = 1 where stateAbbr = @processingStateAbbr
		select @processingStatesLeft = Count(*) from @states where processed is null
		
		SET @Msg='COMPLETED ' + @processingStateAbbr + ' at ' + CONVERT(varchar(16), GETDATE(), 121) + ' EDT ' + CAST(@processingStatesLeft as varchar(20)) + ' left.'
		RAISERROR (@Msg, 0, 1) WITH NOWAIT

	END

	/*
	select *
		from (
			select *, (select count(*) from locations l where deletedon = 99991231 and l.merchantid = rr.merchantid and StateFIPSCode = (
				select fipscode from States s where s.Abbr = rr.ShipToState)) as locations,
			dbo.fncollecting(merchantid, shiptostate, @periodStart) as iscollecting
		from (
			select *, (select count(filingid) from filings f with (nolock) where merchantid = (select merchantid from urls u where u.id = r.urlid) and f.StateFIPSCode = (select fipscode from States s where s.Abbr = r.ShipToState) and periodstart = @periodStart and DisabledTimestamp is null )as filingcount,
			(select merchantid from urls where id = r.URLID) as merchantid, (select cartid from urls where id = r.URLID) as cartid
		from (
		select urlid, count(*) as transactioncount, ShipToState
	from transactions t with (nolock)
	where CapturedTimestamp >= '2022-03-01' and CapturedTimestamp < '2022-04-01' and IsLive =1 and CreatedTimestamp < @cutoffDate
	group by urlid, shiptostate
	) r
	) rr
	where rr.filingcount = 0 and cartid <> 25
	) rrr
	where rrr.locations >0 or rrr.iscollecting >0 order by MerchantID, ShipToState
	*/

END
