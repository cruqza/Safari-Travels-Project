create table safari_connect.safari_staging(
booking_id text,
passenger_name text,
passenger_phone text,
passenger_gender text,
passenger_city text,
route_code text,
route_from text,
route_to text,
vehicle_plate text,
vehicle_type text,
driver_name text,
driver_rating text,
departure_date text,
departure_time time,
seat_class text,
seats_booked text,
fare_per_seat text,
total_fare text,
payment_method text,
booking_status text,
trip_rating text);


select * from safari_connect.safari_staging ;

--=================================================================================


--normalization of the passanger_name
update safari_connect.safari_staging
set passenger_name = trim(initcap(passenger_name))
where passenger_name is not null;

--cleaning the phone number
-- the fromula below also gives a normalized phone number use it for study

--update safari_connect.safari_staging
--set passenger_phone = (CASE 
--    -- Checks if it starts with +254
--	when passenger_phone like '%-%' then regexp_replace (passenger_phone, '[^0-9]', '', 'g')
--    WHEN passenger_phone LIKE '+254%' then '0' || SUBSTRING(passenger_phone, 5)
--    -- Checks if it starts with 254
--    WHEN passenger_phone LIKE '254%' then '0' || SUBSTRING(passenger_phone, 4)
--    when trim(passenger_phone) = '' then null
--    ELSE passenger_phone
--end);

UPDATE safari_connect.safari_staging
SET passenger_phone = (
    CASE 
        -- 1. Handle empty or blank spaces first
        WHEN passenger_phone IS NULL OR TRIM(passenger_phone) = '' THEN NULL
        
        -- 2. Clean hyphens/spaces and process country code in one pass
        ELSE (
            CASE 
                -- Strip hyphens/spaces first, then look at the resulting clean number
                WHEN REGEXP_REPLACE(passenger_phone, '[^0-9+]', '', 'g') LIKE '+254%' 
                    THEN '0' || SUBSTRING(REGEXP_REPLACE(passenger_phone, '[^0-9]', '', 'g') FROM 4)
                    
                WHEN REGEXP_REPLACE(passenger_phone, '[^0-9]', '', 'g') LIKE '254%' 
                    THEN '0' || SUBSTRING(REGEXP_REPLACE(passenger_phone, '[^0-9]', '', 'g') FROM 4)
                
                -- If it doesn't have a 254 prefix, just return the stripped digits
                ELSE REGEXP_REPLACE(passenger_phone, '[^0-9]', '', 'g')
            END
        )
    END
);


--passenger_city incosistencies normalization

UPDATE safari_connect.safari_staging 
SET passenger_city = ( 
    CASE
        -- 1. Check for empty strings or strings with just spaces first
        WHEN TRIM(passenger_city) = '' OR passenger_city IS NULL THEN 'Unknown'
        -- 2. Standardize formatting for valid city names
        ELSE TRIM(INITCAP(passenger_city))
    END
);

	



--gender incosistencies

UPDATE safari_connect.safari_staging 
set passenger_gender = (
	case
		 WHEN UPPER(TRIM(passenger_gender)) IN ('M', 'MALE') THEN 'Male'
		 when upper(trim(passenger_gender)) in ('F', 'FEMALE') then 'Female'
		 when trim(passenger_gender) = '' or trim(passenger_gender) is null then 'Unknown'
		else TRIM(INITCAP(passenger_gender))
	end);

 
--seat class abreviations
 
 
update safari_connect.safari_staging
	set seat_class = (case
		when upper(trim(seat_class)) in ('ECO', 'ECONOMY','ECONOMY CLASS') then 'Economy'
		when upper(trim(seat_class)) in ('BUS', 'BUSINESS', 'BUSINESS CLASS') then 'Business'
	else seat_class
end);

--Normalizing the total_fare column

update safari_connect.safari_staging
set total_fare = (regexp_replace(total_fare, '[^0-9]', '', 'g') ::numeric )
where total_fare is not null;


update safari_connect.safari_staging
set fare_per_seat = (regexp_replace(fare_per_seat, '[^0-9]', '', 'g') ::numeric )
where fare_per_seat is not null;

ALTER TABLE safari_connect.safari_staging 
ALTER COLUMN fare_per_seat TYPE NUMERIC USING fare_per_seat::NUMERIC;


update safari_connect.safari_staging
set driver_name = initcap(TRIM(driver_name))
where driver_name is not null;

--payment method casing normalization

select distinct(payment_method) from safari_connect.safari_staging;
with refined_pm as (
select 
	 case 
	 	when initcap(trim(payment_method)) = 'Card' then 'Card'
	 	when payment_method ilike '%esa' then 'M-Pesa'
	 	when initcap(trim(payment_method)) = 'Cash' then 'Cash'
	 	when trim(payment_method) = '' then null
	 	else payment_method
	 end as refined_payment_method
from safari_connect.safari_staging)
select distinct(refined_payment_method) from refined_pm;

update safari_connect.safari_staging
set payment_method = (case 
					 	when initcap(trim(payment_method)) = 'Card' then 'Card'
					 	when payment_method ilike '%esa' then 'M-Pesa'
					 	when initcap(trim(payment_method)) = 'Cash' then 'Cash'
					 	when trim(payment_method) = '' then null
					 	else payment_method
					 end);


update safari_connect.safari_staging
set booking_status = (
						case
							when initcap(trim(booking_status)) = 'Completed' then 'Completed'
							when initcap(trim(booking_status)) = 'No Show' then 'No Show'
							when initcap(trim(booking_status)) = 'Cancelled' then 'Cancelled'
							else booking_status
						end
						)
where booking_status is not null;

--Normalizing the date column

-- Fix DD/MM/YYYY
UPDATE safari_connect.safari_staging
SET departure_date = TO_DATE(departure_date,'DD/MM/YYYY')::TEXT
WHERE departure_date LIKE '%/%';

-- Fix DD-MM-YY (length = 8)
UPDATE safari_connect.safari_staging
SET departure_date = TO_DATE(departure_date,'DD-MM-YY')::TEXT
WHERE departure_date LIKE '%-%' AND LENGTH(departure_date) = 8;

-- Fix MM-DD-YYYY (length=10, day part > 12 confirms it's MM-DD not DD-MM)
UPDATE safari_connect.safari_staging
SET departure_date = TO_DATE(departure_date,'MM-DD-YYYY')::TEXT
WHERE departure_date LIKE '%-%'
  AND LENGTH(departure_date) = 10
  AND SPLIT_PART(departure_date,'-',2)::INTEGER > 12;


-- trip rating (0 or 6)

update safari_connect.safari_staging
set trip_rating = (case 
						when trip_rating in ('0', '6', '7') then null 
						else trip_rating
					end)
where trip_rating is not null;

-- delete negative booked seats -1
delete from safari_connect.safari_staging
where seats_booked::int < 0;

-- delete exact duplicate removal
DELETE FROM safari_connect.safari_staging
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM safari_connect.safari_staging
    GROUP BY booking_id
);

-- vehicle type
update safari_connect.safari_staging
set vehicle_type = initcap(vehicle_type)
where vehicle_type is not null;


select distinct(vehicle_type) from safari_connect.safari_staging;
select count(distinct(departure_date)) from safari_connect.safari_staging;

select * from safari_connect.safari_staging;

