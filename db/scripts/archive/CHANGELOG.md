# Fitness procedures — change log for the fixes (2026-10-14)

Every one of the 112 stored procedures and 5 scalar functions was rewritten. The fixed definitions are in
`archive/procedures/` and `archive/functions/`; the pre-fix originals are in `archive/procedures-original/` and
`archive/functions-original/`. Each file carries the same `-- Changes:` header that appears below.

## Conventions applied everywhere

- `SET NOCOUNT ON`; writes also `SET XACT_ABORT ON`, run in a transaction with `TRY/CATCH` and re-`THROW` on error.
- Every table is schema-qualified (`dbo.`) with an alias; every result column has a unique name; no `SELECT *`.
- Inserts use explicit column lists and return the new key as `SELECT @NewId AS Id` (an `int`; the originals returned
  `@@IDENTITY`/`SCOPE_IDENTITY()` as `numeric(38,0)` — C# code doing `(decimal)cmd.ExecuteScalar()` needs `Convert.ToInt32`).
- Parameters match the column types: `date` for activity dates (`Date` columns only ever hold midnight), `datetime2(0)` for
  start/end times, `varchar(max)`/`nvarchar(max)` instead of the deprecated `text`/`ntext`.
- Date ranges are inclusive of the whole end date (`[Date] >= @StartDate AND [Date] < DATEADD(day, 1, @EndDate)`), and
  where a proc already treated NULL dates as "all time", each end of the range can now be left NULL independently.
- Unknown type codes, unknown lookup names and missing rows raise errors (`THROW 500xx`) instead of silently returning
  0, NULL or nothing. Error numbers: 50001 end before start, 50002 odometer order, 50003 unknown exercise type,
  50004 unknown route type, 50005 paging arguments, 50006 GPX type, 50007 divisors, 50008 distribution type,
  50009 activity type code, 50010 row not found.
- Original parameter names and order are unchanged, so positional callers still work; new parameters are appended
  with defaults.
- Kept by request: the gym-hours procedures still estimate hours from miles ÷ fixed speeds.

## Broken today — would fail when called (10)

- `GetMaintenanceByBikeId`
- `GetMaintenanceSubset`
- `InsertMissedMilesByType`
- `InsertRecreationalRide`
- `InsertRecreationalRun`
- `InsertRecreationalWalk`
- `InsertStationaryRide`
- `InsertTrainingRide`
- `InsertTrainingRun`
- `InsertTrainingWalk`

## Other bugs — wrong results or unwanted side effects (30)

- `ExceptionalMiles`
- `GetAverageGymHours`
- `GetExerciseHoursByDate`
- `GetMilesByDateByBike`
- `GetMilesByDateByRunType`
- `GetMilesByDateByShoe`
- `GetMilesByDateByShoeByRunType`
- `GetMilesByDateByShoeByWalkType`
- `GetMilesByDateByType`
- `GetMilesByDateByWalkType`
- `GetMilesByShoeByRunType`
- `GetPartById`
- `GetRideDistribution`
- `GetRunDistribution`
- `GetStationaryRideDistribution`
- `GetTreadmillRunDistribution`
- `GetWalkDistribution`
- `GetWindDistribution`
- `InsertMissedMiles`
- `InsertRecreationalRideGPX`
- `InsertRecreationalRunGPX`
- `InsertRecreationalWalkGPX`
- `InsertTrainingRideGPX`
- `InsertTrainingRunGPX`
- `InsertTrainingWalkGPX`
- `MinimumRideDate`
- `SelectAllRidesByTypeById`
- `ToDecimalHours`
- `UpdateBaseMiles`
- `UpdateRoute`

## Hardening / modernisation only (77)

`ClearRouteDirections`, `ClearRoutePictures`, `DeleteRoutePicture`, `GetAverageTemperature`, `GetAverageWindSpeed`, `GetBikeById`, `GetBikeByName`, `GetCircuitById`, `GetCircuitComponentById`, `GetCurrentBikePart`, `GetCurrentBikePartsById`, `GetLastEntries`, `GetMaintenanceCount`, `GetManufacturerById`, `GetMaxOdometerByBike`, `GetMilesByBikeByRideType`, `GetMilesByDateByBikeByRideType`, `GetMilesByDateByRideType`, `GetMissedMilesByDateByType`, `GetPartAge`, `GetPartCount`, `GetPartTypeById`, `GetPartTypeByName`, `GetRainDays`, `GetRecreationalMilesByYear`, `GetRecreationalMilesByYearByBike`, `GetRouteById`, `GetRouteDescriptionByRouteId`, `GetRouteDirectionsByRouteId`, `GetRoutePicturesByRouteId`, `GetShoeById`, `GetTotalGymHours`, `GetTrainingMilesByYear`, `GetTrainingMilesByYearByBike`, `GetTrueTotalMiles`, `GetWeightReadingsByDate`, `InsertBike`, `InsertBikeOnlyMiles`, `InsertBikePart`, `InsertCircuit`, `InsertCircuitComponent`, `InsertCircuitsComponents`, `InsertLiftingSession`, `InsertMaintenance`, `InsertManufacturer`, `InsertNonRideMiles`, `InsertPart`, `InsertPartType`, `InsertRoute`, `InsertRouteDescription`, `InsertRouteDirection`, `InsertRoutePicture`, `InsertShoe`, `InsertStairs`, `InsertTreadmillRun`, `InsertWeightReading`, `MaximumRideDate`, `OdometerReading`, `RemoveBikePart`, `SelectAllBikes`, `SelectAllCircuitComponents`, `SelectAllCircuits`, `SelectAllManufacturers`, `SelectAllPartTypes`, `SelectAllParts`, `SelectAllPartsSubset`, `SelectAllRidesByType`, `SelectAllRidesByTypeByDate`, `SelectAllRoutes`, `SelectAllRunsByTypeById`, `SelectAllShoes`, `SelectAllWalksByTypeById`, `SelectGPXByTypeById`, `UpdateBikeNotes`, `UpdatePart`, `UpdateRouteDescription`, `UpdateRoutePicture`

## Per-object detail

### ClearRouteDirections (procedure)

  Changes:
- Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.

### ClearRoutePictures (procedure)

  Changes:
- Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.

### DeleteRoutePicture (procedure)

  Changes:
- Schema-qualified; transaction + TRY/CATCH. Returns the number of rows removed as DeletedCount.

### ExceptionalMiles (function)

- BUG: the "all bikes, date range" branch tested `@StartDate <> null`, which is never true, so it always returned the all-time total. Replaced the four branches with one query using IS NULL logic.
- Date parameters are now `date`; the range is inclusive of the whole @EndDate day.
- Schema-qualified.

### GetAverageGymHours (procedure)

  Changes:
- BUG: divide-by-zero when @StartDate = @EndDate (weeks = 0, then days/7 = 0). A single-day range now counts as 1/7 week.
- Estimates and the weeks divisor are otherwise unchanged (DATEDIFF(week), falling back to days/7).
- Range parameters are `date`, end date inclusive; result column named AverageWeeklyHours (float, as before).

### GetAverageTemperature (procedure)

  Changes:
- Four lookups + IF collapsed into one AVG over training rides and training runs (same result, including 0 when empty).
- Range parameters are `date`, end date inclusive; result column named AverageTemperature.

### GetAverageWindSpeed (procedure)

  Changes:
- Four lookups + IF collapsed into one AVG over training rides and training runs (same result, including 0 when empty).
- Range parameters are `date`, end date inclusive; result column named AverageWindSpeed.

### GetBikeById (procedure)

  Changes:
- The Notes column came back unnamed (`COALESCE(Bike.Notes, '')` with no alias). Now aliased Notes.
- text columns cast to varchar(max) so callers get a modern type; AcquisitionDate added.
- Schema-qualified with table aliases.

### GetBikeByName (procedure)

  Changes:
- Unnamed Notes column now aliased; text cast to varchar(max); AcquisitionDate added; schema-qualified.

### GetCircuitById (procedure)

  Changes:
- ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.

### GetCircuitComponentById (procedure)

  Changes:
- ntext Notes cast to nvarchar(max) and NULL returned as ''; schema-qualified.

### GetCurrentBikePart (procedure)

  Changes:
- The same three-table join was written twice (outer query + MIN subquery). Rewritten as TOP (1) WITH TIES, which returns exactly the same rows. The PartType join is no longer needed (filter on Part.PartTypeId).
- Schema-qualified.

### GetCurrentBikePartsById (procedure)

  Changes:
- Two near-identical branches merged into one query; @BikeId = 0 still means "all bikes", and NULL now means the same (previously NULL returned no rows).
- The single-bike branch had no ORDER BY; both now order by BikeId, PartTypeName.
- text Notes cast to varchar(max); schema-qualified.

### GetExerciseHoursByDate (procedure)

  Changes:
- BUG: @LiftDivisor was int, so SUM(NumberOfSets) / @LiftDivisor was integer division (truncated). Now decimal.
- Zero, negative or NULL divisors raise an error instead of a divide-by-zero.
- SET NOCOUNT and the DECLAREs sat outside BEGIN...END; restructured.
- Range parameters are `date`, end date inclusive; result column named ExerciseHours.

### GetLastEntries (procedure)

  Changes:
- SELECT * replaced by explicit columns; schema-qualified.
- Stairs added ("Last Stair Session") -- it was the only activity table missing from the list.

### GetMaintenanceByBikeId (procedure)

  Changes:
- BUG (broken today): filtered the MaintenanceLog view with `[Bike] = @BikeId`, but [Bike] is the bike *name*, so every call failed converting the name to int. Now queries the base tables and filters on Maintenance.BikeId.
- The [Bike] column was selected twice; column names no longer contain spaces.
- text Notes cast to varchar(max); ORDER BY Odometer, Id.

### GetMaintenanceCount (procedure)

  Changes:
- Result column named MaintenanceCount; schema-qualified.

### GetMaintenanceSubset (procedure)

  Changes:
- BUG (broken today): same `[Bike] = @BikeId` name-vs-id comparison as GetMaintenanceByBikeId. Now filters on Maintenance.BikeId against the base tables.
- ROW_NUMBER CTE + SELECT * replaced by OFFSET/FETCH with explicit columns and a deterministic order.
- Column names without spaces ([Operation Date] -> OperationDate, [Part Type] -> PartType, [Action Taken] -> ActionTaken); Id added; the helper RowNumber column is no longer returned.
- @StartIndex is still 1-based; invalid or NULL paging arguments raise an error.

### GetManufacturerById (procedure)

  Changes:
- Notes added (cast from text); schema-qualified.

### GetMaxOdometerByBike (procedure)

  Changes:
- Logic unchanged (despite the name it sums logged miles from all five odometer sources for the bike).
- One SELECT; result column named TotalLoggedMiles; schema-qualified.

### GetMilesByBikeByRideType (procedure)

  Changes:
- Five IF blocks replaced by one SELECT with CASE per source; an unknown @RideType raises an error (previously returned 0 after adding three NULLs).
- Kept: the result is clamped at 0 (StationaryRide has no End > Start constraint, so trainer sums can be negative).
- Result column named Miles. Ride types (unchanged): 1 training, 2 recreational, 3 training + this bike's trainer, 4 this bike's trainer, 5 trainer rides with no bike (ignores @BikeId).

### GetMilesByDateByBike (procedure)

  Changes:
- BUG: miles in a range were OdometerReading(@EndDate) - OdometerReading(@StartDate). OdometerReading includes everything dated <= its argument, so every ride ON @StartDate was excluded. The start reading is now the last reading *before* @StartDate, or -- if the bike has no earlier reading -- the lowest StartOdometer inside the range.
- Bike-only and trainer miles subtracted with the same inclusive range (previously ExceptionalMiles + a BETWEEN).
- @StartDate and @EndDate are independently optional (both NULL = all-time, as before).
- The clamp to 0 is kept: an odometer replacement can make a range negative.
- Result column named Miles; schema-qualified.

### GetMilesByDateByBikeByRideType (procedure)

  Changes:
- Five IF blocks replaced by one SELECT with CASE per source; unknown @RideType raises an error; clamp at 0 kept.
- NULL @StartDate / @EndDate now mean "open-ended" (previously a NULL produced 0); end date inclusive.
- Result column named Miles. Ride types as in GetMilesByBikeByRideType.

### GetMilesByDateByRideType (procedure)

  Changes:
- Four IF blocks (each with its own NULL-date branch) replaced by one SELECT; unknown @RideType raises an error; clamp at 0 kept. @StartDate and @EndDate are independently optional; end date inclusive.
- Result column named Miles. Ride types (unchanged): 1 training, 2 recreational, 3 training + trainer (with a bike), 4 trainer (with a bike).

### GetMilesByDateByRunType (procedure)

  Changes:
- BUG: totals were stored in `int` variables, so every decimal Distance sum was truncated to whole miles. Now returns decimal(12,4).
- Unknown @RunType raises an error (previously returned 0); optional, inclusive date range; result column named Miles.
  Run types (unchanged): 1 training, 2 recreational.

### GetMilesByDateByShoe (procedure)

  Changes:
- BUG: two `GRANT EXECUTE` statements were pasted inside the body (no GO) and ran on every call. Removed.
- BUG: int variables truncated every decimal Distance sum, and stair miles used integer division (SUM(ElevationGain) / 5280), so anything under a full vertical mile counted as 0. Now decimal arithmetic.
- Two duplicated branches (with / without dates) merged; @StartDate and @EndDate are independently optional.
- Result column named Miles (decimal(12,4)).

### GetMilesByDateByShoeByRunType (procedure)

  Changes:
- BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
- Unknown type raises an error; clamp removed; optional, inclusive date range; result column named Miles.

### GetMilesByDateByShoeByWalkType (procedure)

  Changes:
- BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
- Unknown type raises an error; clamp removed; optional, inclusive date range; result column named Miles.
- Parameter name @RunType kept for compatibility (it is the walk type: 1 training, 2 recreational).

### GetMilesByDateByType (procedure)

  Changes:
- BUG: type 5 (treadmill) assigned the treadmill total to both the "training" and "recreational" variables and then added them -- treadmill miles were doubled. Fixed.
- BUG: int variables truncated decimal run/walk/treadmill Distance sums. Now decimal(12,4).
- BUG (types 1 and 11): the range start used OdometerReading(@StartDate), which excluded rides on @StartDate (see GetMilesByDateByBike). Same start-reading fix applied per bike.
- The per-bike cursor (declared twice in one proc) replaced by a single set-based query.
- Type 5 previously ignored the "NULL dates = all-time" convention; every type now honours it. With @EndDate NULL the odometer reading is taken as of today (as before) and all other sums are open-ended (as before).
- Unknown @Type raises an error. Result column named Miles.
  Types (unchanged): 1 rides excluding trainer, 11 rides including trainer, 2 runs, 3 walks, 4 all stationary rides, 12 stationary rides with no bike, 5 treadmill runs.

### GetMilesByDateByWalkType (procedure)

  Changes:
- BUG: int variables truncated decimal Distance sums to whole miles. Now returns decimal(12,4).
- Unknown type raises an error; optional, inclusive date range; result column named Miles.
- Parameter name @RunType kept for compatibility (it is the walk type: 1 training, 2 recreational).

### GetMilesByShoeByRunType (procedure)

  Changes:
- BUG: a `GRANT EXECUTE ON [dbo].[GetMilesByBikeByRideType] ...` (wrong object) was pasted inside the body after a commented-out END, so it ran on every call. Removed.
- BUG: int variables truncated decimal Distance sums. Now decimal(12,4).
- Unknown type raises an error; result column named Miles.

### GetMissedMilesByDateByType (procedure)

  Changes:
- @StartDate and @EndDate are independently optional (end inclusive); two branches merged.
- An unknown @TypeName raises an error instead of silently returning 0.
- Result column named Miles; schema-qualified.

### GetPartAge (procedure)

  Changes:
- The bike's current odometer is now dbo.OdometerReading (all five odometer sources). The original looked only at training and recreational rides, so trainer, non-ride and bike-only miles were ignored.
- Duplicate result column names (two columns called Name) fixed: ManufacturerName, PartName.
- New MilesOnPart column (OdometerReading - PartOdometer). The OdometerReading column keeps its original name.
- Duplicated join/subquery replaced by TOP (1) WITH TIES; schema-qualified.

### GetPartById (procedure)

  Changes:
- BUG: LEFT JOIN to BikePart returned one row per installation, so a part fitted more than once came back as several rows. Now returns exactly one row with the most recent installation (StartDate, EndDate, BikeId).
- text Notes cast to varchar(max); schema-qualified.

### GetPartCount (procedure)

  Changes:
- Result column named PartCount; schema-qualified.

### GetPartTypeById (procedure)

  Changes:
- Schema-qualified.

### GetPartTypeByName (procedure)

  Changes:
- Schema-qualified.

### GetRainDays (procedure)

  Changes:
- bit column compared to 1 instead of the string 'True'.
- Range parameters are `date`, end date inclusive; result column named RainActivities (it counts activities, not days).

### GetRecreationalMilesByYear (procedure)

  Changes:
- YEAR([Date]) = @Year (non-SARGable) replaced by a date range; @Year NULL also means "all years".
- Result column named Miles; schema-qualified.

### GetRecreationalMilesByYearByBike (procedure)

  Changes:
- YEAR([Date]) = @Year replaced by a date range; two branches merged; result column named Miles.

### GetRideDistribution (procedure)

  Changes:
- BUG: grouped by MONTH(Date) only, so a multi-year range merged every January together. Now grouped by year and month.
- Column names without spaces: Year, MonthNumber, MonthName, Rides | Miles.
- An unknown @Type raises an error. Range parameters are `date`, end date inclusive.

### GetRouteById (procedure)

  Changes:
- text Notes cast to varchar(max), NULL returned as ''; schema-qualified.

### GetRouteDescriptionByRouteId (procedure)

  Changes:
- text Description cast to varchar(max); schema-qualified.

### GetRouteDirectionsByRouteId (procedure)

  Changes:
- CAST(... AS nvarchar) without a length replaced by an explicit length; schema-qualified.

### GetRoutePicturesByRouteId (procedure)

  Changes:
- text ImageDescription cast to varchar(max); ORDER BY Id; schema-qualified.

### GetRunDistribution (procedure)

  Changes:
- BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
- Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.

### GetShoeById (procedure)

  Changes:
- Typo'd alias ShoeAquisitionDate corrected to ShoeAcquisitionDate.
- ntext Notes cast to nvarchar(max); schema-qualified.

### GetStationaryRideDistribution (procedure)

  Changes:
- BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
- Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.

### GetTotalGymHours (procedure)

  Changes:
- Estimates kept exactly as before (by request): ride miles / 20, run miles / 7.6, sets / 8, stairs / 2400.
- Six SET statements collapsed into one SELECT; range parameters are `date`, end date inclusive.
- Result column named TotalHours (float, as before); schema-qualified.

### GetTrainingMilesByYear (procedure)

  Changes:
- YEAR([Date]) = @Year replaced by a date range; two branches merged; result column named Miles.

### GetTrainingMilesByYearByBike (procedure)

  Changes:
- YEAR([Date]) = @Year replaced by a date range; two branches merged; result column named Miles.

### GetTreadmillRunDistribution (procedure)

  Changes:
- BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
- Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.

### GetTrueTotalMiles (procedure)

  Changes:
- Logic unchanged (training + recreational odometer miles + every bike's BaseMiles); one SELECT, column TotalMiles.

### GetWalkDistribution (procedure)

  Changes:
- BUG: grouped by MONTH(Date) only (multi-year ranges merged). Now grouped by year and month.
- The count column was mislabelled 'Runs'; now Walks.
- Column names without spaces; unknown @Type raises an error; `date` parameters, end date inclusive.

### GetWeightReadingsByDate (procedure)

  Changes:
- The NULL-defaulting IF statements sat outside BEGIN...END and before SET NOCOUNT ON. Restructured.
- NULL dates now mean "open-ended" directly in the WHERE clause (no extra MIN() lookup); end date is inclusive.
- Parameters are `date`; ORDER BY Date; Notes added; schema-qualified.

### GetWindDistribution (procedure)

  Changes:
- BUG: UNION ALL of two GROUP BYs returned each direction twice (once for rides, once for runs). Now one row per direction with the combined count.
- WindDirection returned trimmed (186 stored values carry a trailing space, e.g. 'W '). Cosmetic only: SQL Server already ignores trailing spaces when grouping, so this does not change the counts.
- Count column renamed Activities (it counts activities, not days); ordered by direction.

### InsertBike (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- @Name is varchar(50) to match the column (was nvarchar, implicit conversion); @Notes varchar(max) (was ntext into a text column).
- @AcquisitionDate is `date`; transaction + TRY/CATCH.

### InsertBikeOnlyMiles (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- Explicit column list; transaction + TRY/CATCH.
- Rejects EndOdometer < StartOdometer (no table constraint enforces it).
- @Date is `date`; now returns the new Id (previously returned nothing).

### InsertBikePart (procedure)

  Changes:
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- @StartDate is `date`; transaction + TRY/CATCH.

### InsertCircuit (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- @Notes nvarchar(max) instead of ntext; transaction + TRY/CATCH.

### InsertCircuitComponent (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- @Notes nvarchar(max) instead of ntext; transaction + TRY/CATCH.

### InsertCircuitsComponents (procedure)

  Changes:
- Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).

### InsertLiftingSession (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- @Date `date`; @Notes nvarchar(max); transaction + TRY/CATCH.

### InsertMaintenance (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- Explicit column list; @Date `date`; @Notes varchar(max); transaction + TRY/CATCH.

### InsertManufacturer (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.

### InsertMissedMiles (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG: @Miles was `int`, so fractional missed miles were truncated before reaching the decimal(18,2) column.
- Explicit column list; @Date `date`; transaction + TRY/CATCH; now returns the new Id.

### InsertMissedMilesByType (procedure)

  Changes:
- BUG (broken today): INSERT without a column list supplied 3 values for 4 columns (Notes missing). Explicit column list now.
- New optional @Notes parameter.
- @TypeName nvarchar(50) to match ExerciseType.Name (was varchar); an unknown type name now raises an error instead of attempting to insert a NULL ExerciseTypeId.
- @Date `date`; transaction + TRY/CATCH; returns the new Id.

### InsertNonRideMiles (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- Explicit column list; transaction + TRY/CATCH.
- Rejects EndOdometer < StartOdometer.
- @Date is `date` (matches the column); now returns the new Id.

### InsertPart (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.

### InsertPartType (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.

### InsertRecreationalRide (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG (broken today): INSERT without a column list supplied 23 values for 25 columns. Explicit column list now.
- New optional parameters @Distance and @GpxJsonId.
- Ride and bike times computed with DATEDIFF(second); rejects EndTime/BikeEndTime earlier than StartTime.
- @MaxSpeed decimal(9,4) to match the column; @Date `date`; times datetime2(0); @Notes varchar(max).
- Transaction + TRY/CATCH; returns Id.

### InsertRecreationalRideGPX (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran on every call and failed for callers without GRANT rights. Removed.
- Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
- Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).

### InsertRecreationalRun (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG (broken today): INSERT without a column list supplied 21 values for 22 columns. Explicit column list now.
- New optional parameter @GpxJsonId.
- @Distance and @MaxSpeed decimal(9,4) to match the columns.
- Run and path times computed with DATEDIFF(second); rejects EndTime/PathEndTime earlier than StartTime.
- @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.

### InsertRecreationalRunGPX (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran on every call and failed for callers without GRANT rights. Removed.
- Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
- Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).

### InsertRecreationalWalk (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG (broken today): INSERT without a column list supplied 21 values for 22 columns. Explicit column list now.
- New optional parameter @GpxJsonId.
- @Distance and @MaxSpeed decimal(9,4) to match the columns.
- Walk and path times computed with DATEDIFF(second); rejects EndTime/PathEndTime earlier than StartTime.
- @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.

### InsertRecreationalWalkGPX (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran on every call and failed for callers without GRANT rights. Removed.
- Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
- Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).

### InsertRoute (procedure)

  Changes:
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- An unknown @TypeId (RouteType.EnumId) now raises an error instead of inserting a NULL TypeId.
- Explicit column list; @Notes varchar(max); transaction + TRY/CATCH.
- Kept: @TypeId is the RouteType *EnumId* and is mapped to RouteType.Id. UpdateRoute now does the same.

### InsertRouteDescription (procedure)

  Changes:
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- Explicit column list; @Description varchar(max) instead of text; transaction + TRY/CATCH.

### InsertRouteDirection (procedure)

  Changes:
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- @DirectionDescription nvarchar(max) to match the column (was text -> implicit conversion); @DirectionMileMarker decimal(18,1) to match the column.
- Explicit column list; transaction + TRY/CATCH.

### InsertRoutePicture (procedure)

  Changes:
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- Explicit column list; @ImageDescription varchar(max) (column is NOT NULL text, so the empty-string default is kept).
- Transaction + TRY/CATCH.

### InsertShoe (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- Explicit column list; dates are `date`; @Notes nvarchar(max); transaction + TRY/CATCH.

### InsertStairs (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- Explicit column list; stair time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
- @Date `date`; times datetime2(0); @Notes nvarchar(max); transaction + TRY/CATCH.
- Now returns the new Id (previously returned nothing).

### InsertStationaryRide (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG (broken today): INSERT without a column list supplied 13 values for 14 columns. Explicit column list now.
- New optional parameter @Distance.
- Ride time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(); @Date `date`; times datetime2(0); @Notes nvarchar(max).
- Transaction + TRY/CATCH; returns Id.

### InsertTrainingRide (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG (broken today): INSERT without a column list supplied 20 values for 24 columns, so every call failed. Now uses an explicit column list.
- New optional parameters for the columns added since the proc was written: @Distance, @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
- Ride time computed from DATEDIFF(second) instead of DATEPART on datetime subtraction (no 24 h wrap, works with datetime2).
- Rejects EndTime earlier than StartTime.
- @MaxSpeed widened to decimal(9,4) to match the column (was decimal(5,2)); @Date is `date`; times are datetime2(0); @Notes is varchar(max) (column is text; parameter type no longer deprecated).
- Transaction + TRY/CATCH; returns the new Id as an int column named Id.

### InsertTrainingRideGPX (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran on every call and failed for callers without GRANT rights. Removed.
- Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
- Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).

### InsertTrainingRun (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG (broken today): INSERT without a column list supplied 18 values for 21 columns. Explicit column list now.
- New optional parameters @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
- @Distance decimal(9,4) and @MaxSpeed decimal(9,4) to match the columns (were decimal(18,2) / decimal(5,2)).
- Run time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
- @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.

### InsertTrainingRunGPX (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran on every call and failed for callers without GRANT rights. Removed.
- Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
- Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).

### InsertTrainingWalk (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG (broken today): INSERT without a column list supplied 18 values for 21 columns. Explicit column list now.
- New optional parameters @NumberOfAttempts, @NumberOfSuccesses, @GpxJsonId.
- @Distance and @MaxSpeed decimal(9,4) to match the columns.
- Walk time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
- @Date `date`; times datetime2(0); @Notes varchar(max); transaction + TRY/CATCH; returns Id.

### InsertTrainingWalkGPX (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- BUG: a `GRANT EXECUTE ... TO [FitnessLogger]` had been pasted into the procedure body (no GO), so it re-ran on every call and failed for callers without GRANT rights. Removed.
- Explicit column list; @Notes nvarchar(max) (column is ntext; was declared text).
- Transaction + TRY/CATCH; now returns the new Id (previously returned nothing).

### InsertTreadmillRun (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- Explicit column list (worked today only because the table hasn't changed).
- @Distance decimal(9,4) to match the column; run time computed with DATEDIFF(second); rejects EndTime earlier than StartTime.
- @Date `date`; times datetime2(0); @Notes nvarchar(max); transaction + TRY/CATCH.
- Now returns the new Id (previously returned nothing).

### InsertWeightReading (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- SELECT @@IDENTITY replaced by SCOPE_IDENTITY(), returned as an int column named Id.
- @Date `date` (UNIQUE_Date is on this column, so a time portion previously let two readings on one day slip in).
- @Notes nvarchar(max); transaction + TRY/CATCH.

### MaximumRideDate (function)

  Changes:
- Two lookups + IF collapsed into one query over both ride tables.
- Date parameters are now `date`; range inclusive of the whole @EndDate day.
- Kept: returns @StartDate when the bike has no rides in the range; return type still datetime.

### MinimumRideDate (function)

  Changes:
- Two lookups + IF collapsed into one query over both ride tables.
- Date parameters are now `date`; range inclusive of the whole @EndDate day.
- BUG: each table's MIN was defaulted to @StartDate before the two were compared, so when only one of the two ride tables had rides in the range the function returned @StartDate instead of the real earliest ride. Fixed.
- Kept: returns @StartDate when the bike has no rides in the range at all; return type still datetime.

### OdometerReading (function)

  Changes:
- Five variables + a table variable replaced by one MAX over a VALUES list (the function is now eligible for scalar UDF inlining once the database is at compatibility level 150+).
- @Date is now `date` (callers passing GETDATE() still get "everything up to today").
- Same five sources as before: training, recreational and stationary rides, non-ride and bike-only miles.

### RemoveBikePart (procedure)

  Changes:
- @EndDate is `date`; raises an error if the BikePart row does not exist; transaction + TRY/CATCH.

### SelectAllBikes (procedure)

  Changes:
- Unnamed Notes column now aliased; text cast to varchar(max); AcquisitionDate added; schema-qualified.
- Deterministic ORDER BY BikeName.

### SelectAllCircuitComponents (procedure)

  Changes:
- Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY ExerciseName; schema-qualified.

### SelectAllCircuits (procedure)

  Changes:
- Unnamed Notes column now aliased; ntext cast to nvarchar(max); ORDER BY Name; schema-qualified.

### SelectAllManufacturers (procedure)

  Changes:
- ORDER BY Name; schema-qualified.

### SelectAllPartTypes (procedure)

  Changes:
- ORDER BY Name; schema-qualified.

### SelectAllParts (procedure)

  Changes:
- text Notes cast to varchar(max); Part.Id added as tiebreaker in ORDER BY; schema-qualified.

### SelectAllPartsSubset (procedure)

  Changes:
- ROW_NUMBER CTE + SELECT * replaced by OFFSET/FETCH with an explicit column list.
- Paging is now deterministic (Part.Id tiebreaker; the original ORDER BY could reorder ties between pages).
- @StartIndex is still 1-based; values below 1, a non-positive page size or NULLs raise an error.
- The helper RowNumber column is no longer returned.

### SelectAllRidesByType (procedure)

  Changes:
- Was a copy of SelectAllRidesByTypeByDate without the WHERE clause (3,600 characters duplicated, and the two had already drifted: one returned Notes raw, the other coalesced). Now delegates to SelectAllRidesByTypeByDate with no date limits, so both return exactly the same columns. See that procedure for the column changes.

### SelectAllRidesByTypeByDate (procedure)

  Changes:
- Result sets had duplicate column names (BikeId x2, RouteTypeId x2, ManufacturerId x2, Name used for several things), which ADO.NET renames to Name1, Name2... Every column now has one unique, prefixed name (BikeName, RouteName, RouteCity, BikeManufacturerName, ...).
- Training rides now include the columns added since the proc was written: Distance, MaxSpeed, NumberOfAttempts, NumberOfSuccesses, GpxJsonId. Recreational rides include Distance and GpxJsonId.
- text/ntext columns cast to (n)varchar(max); WindDirection trimmed; ORDER BY Date, StartTime.
- @StartDate and @EndDate are independently optional (end inclusive); an unknown @RideType raises an error.
  Ride types (unchanged): 1 training, 2 recreational.

### SelectAllRidesByTypeById (procedure)

  Changes:
- BUG: type 3 (stationary) used `LEFT JOIN Bike ... INNER JOIN BikeType ... INNER JOIN Manufacturer`; the inner joins cancelled the outer join, so a trainer ride with no bike (BikeId NULL) returned no row. All bike joins are LEFT JOINs for type 3 now.
- Duplicate column names removed (same naming as SelectAllRidesByTypeByDate); Distance / GpxJsonId / attempt columns included; text/ntext cast; WindDirection trimmed.
- An unknown @RideType raises an error.
  Ride types (unchanged): 1 training, 2 recreational, 3 stationary.

### SelectAllRoutes (procedure)

  Changes:
- text Notes cast to varchar(max), NULL returned as ''; ORDER BY Name; schema-qualified.

### SelectAllRunsByTypeById (procedure)

  Changes:
- Duplicate column names removed (ShoeId x2, RouteId x2, RouteTypeId x2, ManufacturerId x2); prefixed names (ShoeName, RouteName, ShoeManufacturerName, ...).
- Training runs now include MaxSpeed, NumberOfAttempts, NumberOfSuccesses and GpxJsonId; recreational runs GpxJsonId.
- text/ntext cast; WindDirection trimmed; an unknown @RunType raises an error.
  Run types (unchanged): 1 training, 2 recreational, 3 treadmill.

### SelectAllShoes (procedure)

  Changes:
- Typo'd alias ShoeAquisitionDate corrected to ShoeAcquisitionDate.
- ntext Notes cast to nvarchar(max); ORDER BY ShoeName; schema-qualified.

### SelectAllWalksByTypeById (procedure)

  Changes:
- Duplicate column names removed; prefixed names (ShoeName, RouteName, ShoeManufacturerName, ...).
- Training walks now include MaxSpeed, NumberOfAttempts, NumberOfSuccesses and GpxJsonId; recreational walks GpxJsonId.
- text/ntext cast; WindDirection trimmed; an unknown @WalkType raises an error.
  Walk types (unchanged): 1 training, 2 recreational.

### SelectGPXByTypeById (procedure)

  Changes:
- The activity id column now has one name for every type (ActivityId) so callers can read any type the same way.
- An unknown @Type raises an error instead of silently returning no result set.
- Schema-qualified.
  Type codes (unchanged): 1 TrainingRide, 2 TrainingRun, 6 RecreationalRide, 7 RecreationalRun, 8 TrainingWalk, 9 RecreationalWalk.

### ToDecimalHours (function)

  Changes:
- BUG: `RETURNS decimal` with no scale is decimal(18,0), so 1 h 30 m returned 2 instead of 1.5. Now returns decimal(9,4).

### UpdateBaseMiles (procedure)

  Changes:
- BUG: read BaseMiles into a variable, then wrote variable + @Miles back -- not atomic, so two concurrent calls could lose an update. Now a single `SET BaseMiles = BaseMiles + @Miles`.
- Raises an error if the bike does not exist; transaction + TRY/CATCH.

### UpdateBikeNotes (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- @Notes was nvarchar(255) writing into a text column (silent truncation at 255, implicit conversion). Now varchar(max).
- Raises an error if the bike does not exist; transaction + TRY/CATCH.

### UpdatePart (procedure)

  Changes:
- @Notes now defaults to NULL (was '').
- @Notes was nvarchar(255) writing into a text column (silent truncation at 255). Now varchar(max).
- Raises an error if the part does not exist; transaction + TRY/CATCH.

### UpdateRoute (procedure)

  Changes:
- BUG: InsertRoute maps its type argument through RouteType.EnumId, but UpdateRoute wrote @RouteType straight into Route.TypeId. Both now map through EnumId. (Harmless with today's data, where Id = EnumId for both route types, but the two procs disagreed about what the parameter meant.)
- Raises an error if the route or route type does not exist.
- @Notes varchar(max); transaction + TRY/CATCH.

### UpdateRouteDescription (procedure)

  Changes:
- @Description varchar(max) instead of text.
- Raises an error if the route has no description row (previously a silent no-op); transaction + TRY/CATCH.

### UpdateRoutePicture (procedure)

  Changes:
- @ImageDescription varchar(max) instead of text.
- Raises an error if the picture does not exist; transaction + TRY/CATCH.

