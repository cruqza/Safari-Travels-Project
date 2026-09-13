set search_path to safari_connect;


/*--Analyzing business questions
Route Analysis Which routes earn the most? Which are most popular?
Which is most efficient per seat sold?	
--===========What the CEO wants to see================================
Specific route codes with KES figures.
A clear top route and a clear underperformer.
*/

select
vct.route_code ,
vct.route_from , vct.route_to ,
sum(vct.seats_booked) as seatsbooked,
round(sum(vct.total_fare),2) as totalrevenue,
round(avg(vct.trip_rating ),2) as avgrating
from v_clean_trips vct
group by vct.route_from ,vct.route_to, vct.route_code
order by totalrevenue desc ;




/*1. ROUTE ANALYSIS
* a) Which routes earn the most?
* b) Which are most popular?
* c) Which is most efficient per seat sold?
*/
 
select * from safari_connect.v_clean_trips;
 
-- ===============================================================================================================================
-- a) Which routes earn the most?
 
select
route_code,
route_from,
route_to,
sum(total_fare) as totalrevenue_
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by totalrevenue_ desc;
 
-- including the seats booked
select
route_code,
sum(seats_booked) as totalseats_booked_,
sum(total_fare) as totalrevenue_
from safari_connect.v_clean_trips
group by route_code
order by totalrevenue_ desc;
 
-- b) Which are most popular?
-- what defines a popular route? no. of seats booked per route? or rating? i doubt. bookings per route?
 
select
	route_code,
	route_from,
	route_to,
	count(booking_id) as total_bookings,
	sum(seats_booked) as totalseats
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by totalseats desc;

-- Nairobi-Thika has most passengers hence its most popular route
 
 
-- c) Which is most efficient per seat sold?
-- which route makes the most money on average from each seat it sells?
-- revenue/seats
 
select
route_code,
route_from,
route_to,
sum(seats_booked) as seatssold,
sum(total_fare) as totalrevenue,
round((sum(total_fare) / sum(seats_booked)), 2) as revenue_per_seat
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by revenue_per_seat desc;


--====Qestion 2===========================================
/*Driver Performance
 1) Who are the best drivers? 
2) Does driver rating affect passenger satisfaction?	
3) Named drivers with revenue and rating figures. 
4) A promotion recommendation with data behind it
 */ 

-- 1) Who are the best drivers?

select driver_name,
	sum(total_fare) as total_driver_revenue,
	AVG(driver_rating) as avg_driver_rating
from safari_connect.v_clean_trips
group by driver_name 
order by avg_driver_rating desc;
--limit 3;

--
--WITH driver_totals AS (
--    SELECT
--        driver_name,
--        vehicle_type,
--        COUNT(*) AS total_trips,
--        SUM(total_fare) AS total_revenue,
--        ROUND(AVG(trip_rating),2) AS avg_passenger_rating
--    FROM safari_connect.v_clean_trips
--    GROUP BY driver_name, vehicle_type
--)
--SELECT
--    driver_name, vehicle_type, total_trips, total_revenue, avg_passenger_rating,
--    RANK() OVER (ORDER BY total_revenue DESC)  AS overall_rank,
--    RANK() OVER (PARTITION BY vehicle_type ORDER BY total_revenue DESC) AS vehicle_rank
--FROM driver_totals
--ORDER BY overall_rank;



--2) Does driver rating affect passenger satisfaction?

-- Driver rating doesn't affect passenger satisfaction

select
	driver_name,
	sum(fare_per_seat) as totalrevenue,
	round(avg(driver_rating),2) as avgdriver_rating,
	ROUND(AVG(trip_rating),2) as avgtrip_rating,
	corr(trip_rating, driver_rating) as corre_rating
from safari_connect.v_clean_trips
group by driver_name
order by avgtrip_rating desc;	



-- ==========================================================================================================
/* Revenue Trends
* 3a) How is revenue changing month by month?
* 3b) How is revenue changing month by month?
*
* Month-over-month change with % growth. A trend direction - growing or declining?
*/
 
-- 3a) How is revenue changing month by month?

with monthly_revenue as (
select
	travel_month,
	sum(total_fare) as total_revenue
from safari_connect.v_clean_trips
group by 1)
select
	travel_month,
	total_revenue,
	lag(total_revenue) over (order by travel_month) as prevmonth_revenue
from monthly_revenue
order by travel_month;



with monthly_revenue as (
	select
	travel_month,
	sum(total_fare) as total_revenue
from safari_connect.v_clean_trips
group by 1)
select
	travel_month,
	total_revenue,
	lag(total_revenue) over (order by travel_month) as prevmonth_revenue,
	round(100.0 * (total_revenue - lag(total_revenue) over (order by travel_month))
	/lag(total_revenue) over (order by travel_month), 2) as mom_pct_change
from monthly_revenue
order by travel_month;

--=========================================================================
-- What are our best and worst months

SELECT 
    travel_month,
    month_label,
    COUNT(booking_id) AS total_trips,
    SUM(total_fare) AS total_revenue,
    ROUND(AVG(total_fare), 2) AS average_booking_value
FROM safari_connect.v_clean_trips
GROUP BY travel_month, month_label
ORDER BY total_revenue 
DESC;

-- 3B - running total of revenue
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', departure_date) AS month,
        SUM(total_fare) AS monthly_revenue
    FROM safari_connect.v_clean_trips
    GROUP BY 1
)
SELECT
    month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM monthly_revenue
ORDER BY month;


--======================================================================================================
-- What are our best and worst months
select travel_month, sum(total_fare) as montotal_fare
from safari_connect.v_clean_trips
group by 1
order by montotal_fare desc
limit 1;

select travel_month, sum(total_fare) as montotal_fare
from safari_connect.v_clean_trips
group by 1
order by montotal_fare
limit 1;

select * FROM safari_connect.v_clean_trips;

SELECT
    DATE_TRUNC('month', departure_date) AS month,
    SUM(CASE
        WHEN route_code = 'RT001' THEN total_fare
        ELSE 0
    END) AS rt001_revenue,
    SUM(CASE
        WHEN route_code = 'RT002' THEN total_fare
        ELSE 0
    END) AS rt002_revenue,
    SUM(CASE
        WHEN route_code = 'RT003' THEN total_fare
        ELSE 0
    END) AS rt003_revenue
FROM safari_connect.v_clean_trips
GROUP BY 1
ORDER BY month;

--==================================================================================

--4a) Passenger Insights Where do passengers come from? 

select route_from, count(booking_id  ) as no_of_pass
FROM safari_connect.v_clean_trips
group by 1
order by no_of_pass  desc;

--4b) What seat class do they prefer? Are they satisfied?	
select seat_class, count(seat_class) as seat_count
FROM safari_connect.v_clean_trips
group by 1
order by seat_count  desc;


--4c) Top cities with numbers. Satisfaction breakdown. 

select passenger_city, 
		count(*) as total_bookings, 
		sum(seats_booked) as total_seats,
		sum(total_fare) as total_revenue,
		avg(fare_per_seat) as  avg_fare
from safari_connect.v_clean_trips
group by 1
order by total_bookings desc 
limit 3;


--4d) Gender and class split.
select	
	passenger_gender,
	seat_class, 
	count(seat_class) as passenger_class
FROM safari_connect.v_clean_trips
group by 1, 2
order by seat_class desc;
--Alternatively
SELECT
    passenger_gender,
    -- Bookings
    SUM(CASE
        WHEN seat_class = 'Economy' THEN 1
        ELSE 0
    END) AS total_economy,
    SUM(CASE
        WHEN seat_class = 'Business' THEN 1
        ELSE 0
    END) AS total_business,
    -- Revenue
    SUM(CASE
        WHEN seat_class = 'Economy' THEN total_fare
        ELSE 0
    END) AS economy_revenue,
    SUM(CASE
        WHEN seat_class = 'Business' THEN total_fare
        ELSE 0
    END) AS business_revenue
FROM safari_connect.v_clean_trips
GROUP BY passenger_gender;

/*Cancellations What is the cancellation rate per route? 
How much revenue did cancellations cost us?	
A KES figure for lost revenue. 
The worst route for cancellations. A policy recommendation.
*/
--5a) Cancellations What is the cancellation rate per route?
select route_code, count(booking_status) as cancelled_count
FROM safari_connect.v_clean_trips
where booking_status = 'Cancelled'
group by 1
order  by cancelled_count ;

SELECT
    route_code,
    route_from || ' → ' || route_to                           AS route,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN booking_status = 'No Show'  THEN 1 ELSE 0 END) AS no_show,
    ROUND(SUM(CASE WHEN booking_status = 'Cancelled'
             THEN 1 ELSE 0 END) * 100.0 / nullif(COUNT(*), 0)) AS cancel_rate_pct
FROM safari_connect.bookings
GROUP BY route_code, route_from, route_to
ORDER BY cancel_rate_pct DESC;


--Cancellations What is the cancellation rate per route? 
--How much revenue did cancellations cost us?	
--A KES figure for lost revenue. The worst route for cancellations.
--A policy recommendation.

select 
	concat(route_from, ' -> ', route_to) as route_name,
	fare_per_seat,
	count(booking_id) as total_seats_booked,
	count(case
		when booking_status = 'Cancelled' then 1 
	end
	) as No_of_cancelled_booking,
	(count(case when booking_status = 'Cancelled' then 1 end) * 100) / nullif(count(booking_id),0)as cancellation_rate,
	sum(case
		when booking_status = 'Cancelled' then (fare_per_seat * seats_booked )
		else 0
	end
	) as revenue_lost
from safari_connect.v_clean_trips
group by route_name, fare_per_seat
--GROUP BY route_from, route_to
ORDER BY revenue_lost DESC;


--Operational Patterns What are our busiest days and times? When should we add more vehicles?
select
	extract (dow from departure_date) as day_num,
	to_char(departure_date, 'Day') as day_name,
	count(booking_id) as total_booking,
	sum(total_fare) as total_revenue
from safari_connect.v_clean_trips 
group by extract (dow from departure_date), to_char(departure_date, 'Day')
order by total_revenue desc;

-- 6B - busiest depature times
select departure_time, 
sum(seats_booked) as total_seats,
row_number() over(order by sum(seats_booked) desc)
from safari_connect.v_clean_trips
group by 1;



select booking_status,
 	count(case when booking_status = 'cancelled' then 1 else 0 End)
from safari_connect.v_clean_trips
group by booking_status ;
	



select * from safari_connect.v_clean_trips;