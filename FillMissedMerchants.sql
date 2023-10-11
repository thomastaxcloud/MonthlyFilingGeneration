

--select * from FedTax.dbo.fnGetSSUTAMerchantIDsForMonthForState (20211101, '05', 0)
--select MerchantID from FedTax.dbo.Filings where PeriodStart = 20211101 and StateFIPSCode = '05' and DisabledTimestamp is null
--select * from FedTax.dbo.Filings where PeriodStart = 20211101 and StateFIPSCode = '05' and MerchantID = 37746
--select * from FedTax.dbo.SERDocuments2Pre where PeriodStart = 20211101 and StateFIPSCode = '05' and MerchantID = 37746
--select * from FedTax.dbo.SERDocuments2 where PeriodStart = 20211101 and StateFIPSCode = '05' and MerchantID = 37746

	DECLARE @periodStart int = 20230901
	DECLARE @periodStartDate datetime2 = '2023-09-01'
	DECLARE @periodEndDate datetime2 = '2023-10-01'
	DECLARE @processingStates table (stateAbbr varchar(2), stateFIPs char(2), processed bit)
	DECLARE @processingStateAbbr char(2)
	DECLARE @processingStateFIPs char(2)
	--DECLARE @merchantsWithTransactions table (merchantID int)
	DECLARE @processingMerchants table (merchantID int, processed bit, discard bit)
	DECLARE @processingMerchantID int

	insert @processingStates (stateAbbr, stateFIPs, processed)
		select Abbr, FIPSCode, 0 as processed from FedTax.dbo.States where IsSSUTA = 1 --and FIPSCode = '05'

	--select * from @processingStates

	WHILE (SELECT COUNT(*) FROM @processingStates where processed = 0) > 0
	BEGIN

		SELECT top 1 @processingStateAbbr=stateAbbr, @processingStateFIPs = stateFIPs from @processingStates where processed = 0

		--delete @merchantsWithTransactions
		--insert @merchantsWithTransactions
		--	select MerchantID from Reports.dbo.TransactionsWide with (nolock) where ((CapturedTimestamp >= @periodStartDate and CapturedTimestamp < @periodEndDate) or (ReturnedTimestamp >= @periodStartDate and ReturnedTimestamp < )) and IsLive = 1 and CartItemIndex is null and ShipToState = @processingStateAbbr group by MerchantID

		delete @processingMerchants
		insert @processingMerchants (merchantID, processed, discard)
		select MerchantID as MerchantID, 0 as processed, 0 as discard from FedTax.dbo.fnGetSSUTAMerchantIDsForMonthForState (@periodStart, @processingStateFIPs, 0)

		delete @processingMerchants where MerchantID = 39023 -- 23FS is special because we really don't want to create a $0 SER for them

		--select * from @processingMerchants
		--select MerchantID, 0, 0 from FedTax.dbo.fnGetSSUTAMerchantIDsForMonthForState (20230201, '05', 0)

		/*
		begin transaction

		WHILE (SELECT COUNT(*) FROM @processingMerchants where processed is null) > 0
		BEGIN
			SELECT top 1 @processingMerchantID=MerchantID from @processingMerchants where processed is null order by merchantID desc
		
			if (SELECT COUNT(*) FROM FedTax.dbo.Filings where PeriodStart = @periodStart and StateFIPSCode = @processingStateFIPs and MerchantID = @processingMerchantID) = 0
			begin
				exec FedTax.dbo.spCreateFilingForMerchantState2 @processingMerchantID, @periodStart, @processingStateAbbr, null, 1
				--exec Reports.dbo.spCreateFilingForMerchantState2 @processingMerchantID, @periodStart, null, null, 1
				print 'Process Filing -- ' + cast(@periodStart as varchar) + ' ' + @processingStateAbbr + ' ' + cast(@processingMerchantID as varchar)
			end
			else
			begin
				update @processingMerchants set discard = 1 where merchantID=@processingMerchantID
				print 'Discard Filing -- ' + cast(@periodStart as varchar) + ' ' + @processingStateAbbr + ' ' + cast(@processingMerchantID as varchar)		
			end
		
			update @processingMerchants set processed = 1 where merchantID=@processingMerchantID
		END

		commit transaction

		delete @processingMerchants where discard = 1
		update @processingMerchants set processed = null
		*/

		begin transaction

		WHILE (SELECT COUNT(*) FROM @processingMerchants where processed = 0) > 0
		BEGIN

			SELECT top 1 @processingMerchantID=MerchantID from @processingMerchants where processed = 0 order by merchantID desc
			if (SELECT COUNT(*) FROM FedTax.dbo.SERDocuments2Pre where PeriodStart = @periodStart and StateFIPSCode = @processingStateFIPs and MerchantID = @processingMerchantID and DisabledTimestamp is null) = 0
			begin
				exec FedTax.dbo.spGenerateStateSERSummaryPre3 @processingStateFIPS, @periodStart, @processingMerchantID

				if (@processingStateAbbr = 'CO')
					exec Reports.dbo.spCreateFilingForMerchantForColorado @processingMerchantID,@PeriodStart,'08',1

				print 'Zero SER -- ' + cast(@periodStart as varchar) + ' ' + @processingStateAbbr + ' ' + cast(@processingMerchantID as varchar)
			end
			else
				print 'Skipping SER -- ' + cast(@periodStart as varchar) + ' ' + @processingStateAbbr + ' ' + cast(@processingMerchantID as varchar)			
			
			update @processingMerchants set processed=1 where merchantID=@processingMerchantID

		END

		commit transaction

		UPDATE @processingStates SET processed=1 WHERE stateAbbr=@processingStateAbbr
	END
