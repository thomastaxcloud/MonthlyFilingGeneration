# MonthlyFilingGeneration

Each Month on the 3rd and 10th (next business day if weekend) run the generatefilingsandserdocuyment2Pre.sql.  This will create the filings for all of our merchants

Once this process is complete, run fulmissedmerchants.sql to create the appropriate zero filings needed for filing zeros (where appropriate) to the streamline states

Any updates to this script should be checked in here so this can serve as the code repoitory
