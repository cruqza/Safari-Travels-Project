create schema safari_connect;

create table safari_connect.booking_safari_staging(
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
departure_time text,
seat_class text,
seats_booked text,
fare_per_seat text,
total_fare text, 
payment_method text,
booking_status text,
trip_rating text);

set search_path to booking_safari_staging;
show search_path;

-- ==================================================================
/*cleaning dirty data problems.
 * 1. normalizing passenger names from uppercase and lowercase and removing the extra
 * whitespace
 * */
update safari_connect.booking_safari_staging
set passenger_name = trim(initcap(passenger_name))
where passenger_name is not null;

/*Fixing phone number dashes and replacing the +254 with 0 */


update safari_connect.booking_safari_staging
set passenger_phone = (case 
		when trim(passenger_phone) = '' then null
		when passenger_phone like '%-%' then regexp_replace(passenger_phone, '[^0-9]', '', 'g')
		WHEN passenger_phone LIKE '+254%' THEN '0' || SUBSTRING(passenger_phone, 5)
		else REGEXP_REPLACE(passenger_phone, '[^0-9]', '', 'g')
	end)
where passenger_phone is not null;

-- normalizing the date formats.
update safari_connect.booking_safari_staging
set departure_date = (
    CASE
        -- DD/MM/YYYY
        WHEN departure_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(departure_date, 'DD/MM/YYYY')
        -- YYYY-MM-DD
        WHEN departure_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN TO_DATE(departure_date, 'YYYY-MM-DD')
        -- DD-MM-YY
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{2}$'
            THEN TO_DATE(departure_date, 'DD-MM-YY')
        -- MM-DD-YYYY where middle number is > 12
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{4}$'
             AND SPLIT_PART(departure_date, '-', 2)::INT > 12
            THEN TO_DATE(departure_date, 'MM-DD-YYYY')
        -- DD-MM-YYYY where middle number is <= 12
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{4}$'
             AND SPLIT_PART(departure_date, '-', 2)::INT <= 12
            THEN TO_DATE(departure_date, 'DD-MM-YYYY')
        ELSE NULL
    end)
where departure_date is not null;

alter table safari_connect.booking_safari_staging
alter departure_date type text;

-- passenger gender normalization
update safari_connect.booking_safari_staging
set passenger_gender = (case
							when upper(trim(passenger_gender)) in ('M', 'MALE') then 'Male'
							when upper(trim(passenger_gender)) in ('F', 'FEMALE') then 'Female'
							else passenger_gender
						end)
where passenger_gender is not null;

select distinct(passenger_gender) from safari_connect.booking_safari_staging;

-- passenger city normalization
--update safari_connect.booking_safari_staging
--set passenger_city = Trim(initcap(passenger_city))
--where passenger_city is not null;

update safari_connect.booking_safari_staging
set passenger_city = (
						case
							when trim(passenger_city) = '' then null
							else passenger_city
						end
						)
where passenger_city is not null;
select distinct(passenger_city) from safari_connect.booking_staging;

-- payment method casing
update safari_connect.booking_safari_staging
set payment_method = (case 
					 	when initcap(trim(payment_method)) = 'Card' then 'Card'
					 	when payment_method ilike '%esa' then 'M-Pesa'
					 	when initcap(trim(payment_method)) = 'Cash' then 'Cash'
					 	when trim(payment_method) = '' then null
					 	else payment_method
					 end)
where payment_method is not null;
select distinct(payment_method) from safari_connect.booking_safari_staging;

-- booking status normalizied
update safari_connect.booking_safari_staging
set booking_status = (
				case 
		when upper(trim(booking_status)) = 'CANCELLED' then 'Cancelled'
		when upper(trim(booking_status)) = 'NO SHOW' then 'No Show'
		when upper(trim(booking_status)) = 'COMPLETED' then 'Completed'
		else booking_status 
			end)
where booking_status is not null;
select distinct(booking_status) from safari_connect.booking_safari_staging;

-- normalize the total fare
update safari_connect.booking_safari_staging
set total_fare = (regexp_replace(total_fare, '[^0-9]', '', 'g')
)
where total_fare is not null;

alter table safari_connect.booking_safari_staging
alter column total_fare type text;

-- normalize the fare per seat
update safari_connect.booking_safari_staging
set fare_per_seat = (regexp_replace(fare_per_seat , '[^0-9]', '', 'g')
)
where fare_per_seat is not null;

alter table safari_connect.booking_safari_staging
alter column fare_per_seat type text;

-- seat_class normalization
update safari_connect.booking_safari_staging 
set seat_class = (case 
		when upper(trim(seat_class)) in ('BUS', 'BUSINESS', 'BUSINESS CLASS') then 'Business'
		when upper(trim(seat_class)) in ('ECO', 'ECONOMY CLASS', 'ECONOMY') then 'Economy'
		else null
	end)
where seat_class is not null;


--- update the driver's name
update safari_connect.booking_safari_staging
set driver_name = initcap(trim(driver_name))
where driver_name is not null;

-- trip rating (0 or 6)

update safari_connect.booking_safari_staging
set trip_rating = (case 
						when trip_rating in ('0', '6', '7') then null 
						else trip_rating
					end)
where trip_rating is not null;

-- delete negative booked seats -1
delete from safari_connect.booking_safari_staging
where seats_booked::int < 0;

-- delete exact duplicate removal
DELETE FROM safari_connect.booking_safari_staging 
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM safari_connect.booking_safari_staging 
    GROUP BY booking_id
);

-- vehicle type
update safari_connect.booking_safari_staging
set vehicle_type = initcap(vehicle_type)
where vehicle_type is not null;
select distinct(vehicle_type) from safari_connect.booking_safari_staging;


select * from safari_connect.booking_safari_staging;


