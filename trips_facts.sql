truncate table booking.fact_trips restart identity;

/*
Here we create a facts table using cleaned data(I did put my formulas in the columns that make the table)
here the output is clean
Step 1- create booking.fact_trips table giving the columns their data fields
step 2 - inserting the data, the data is cleaned during input so the output will be of clean data
*/
create table if not exists booking.fact_trips(
	trip_id VARCHAR(50) primary key,
	customer_id INT  references  booking.dim_customers(customer_id),
	driver_id INT  references booking.dim_drivers(driver_id),
	vehicle_id INT references fleet.dim_vehicles(vehicle_id),
	trip_date date,
	Pickup_area VARCHAR(50),
	pickup_time time,
	dropoff_area VARCHAR(50),
	distance_km NUMERIC(10,1),
	fare_amount numeric,
	payment_method VARCHAR(50),
	status VARCHAR(50),
	customer_rating NUMERIC
);

insert into booking.fact_trips 
select 
 	t.trip_id,
	dc.customer_id,
	dd.driver_id,
	dv.vehicle_id,
	--trip date formula
	CASE 
        WHEN t.trip_date ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(t.trip_date, 'YYYY-MM-DD')
        WHEN t.trip_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(t.trip_date, 'DD/MM/YYYY')
        WHEN t.trip_date ~ '^\d{2}/\d{2}/\d{2}$' THEN TO_DATE(t.trip_date, 'DD/MM/YY')
        WHEN t.trip_date ~ '^\d{2}-\d{2}-\d{4}$' THEN TO_DATE(t.trip_date, 'MM-DD-YYYY')
        ELSE NULL 
    END,
    --pickup area
    nullif(trim(initcap(t.pickup_area)), ''),
   --pickup time exp
    case 
		when t.pickup_time is null then null
		when TRIM(t.pickup_time) in ('null', '') then null
		else TRIM(t.pickup_time):: TIME 
	end,
	--dropoff_area
	NULLIF(TRIM(INITCAP(t.dropoff_area)), ''),
	--nullif(trim(initcap(t.dropoff_area)), ''),
	--distancein_km
	nullif(trim(regexp_replace(t.distance_km, '[^0-9.]', '', 'g')), ''):: numeric,
	--fare_amount
	nullif(TRIM(regexp_replace(t.fare_amount, '[^0-9.]', '', 'g')), ''):: numeric(10,2),
	--payment_method
	nullif(trim(initcap(t.payment_method)), ''),
	--status
	nullif(trim(initcap(t.status)), ''),
	--customer_rating
	case
		when t.customer_rating is null then NULL
		when lower(TRIM(t.customer_rating)) IN ('null', 'n/a', 'na', '') THEN null
		when cast(trim(t.customer_rating) as numeric) > 5 then NULL
		else trim(t.customer_rating):: numeric 
	end as customer_rating
from booking_system_staging.trips_staging t
LEFT join booking.dim_customers dc
	on nullif(TRIM(REGEXP_REPLACE(dc.customer_phone, '[^0-9]', '', 'g')), '') = nullif(TRIM(REGEXP_REPLACE(t.customer_phone, '[^0-9]', '', 'g')), '')
left join booking.dim_drivers dd
	on 	nullif(TRIM(REGEXP_REPLACE(dd.driver_phone, '[^0-9]', '', 'g')), '') = nullif(TRIM(REGEXP_REPLACE(t.driver_phone, '[^0-9]', '', 'g')), '')
left join fleet.dim_vehicles dv
	on nullif(trim(UPPER(t.vehicle_plate)), '') = nullif(trim(UPPER(dv.vehicle_plate)), '')
where t.trip_id is not null
on conflict(trip_id) do nothing;

    
/*
here i did some due diligence to confirm whether output is as desired

*/

select * from booking.fact_trips;

select trip_id, customer_id, driver_id
from booking.fact_trips ft 
where ft.trip_id = '344';

SELECT 
    trip_id, 
    COUNT(*) AS total_occurrences,
    COUNT(*) - 1 AS duplicate_count
FROM booking_system_staging.trips_staging
WHERE trip_id IS NOT NULL
GROUP BY trip_id
HAVING COUNT(*) > 1
ORDER BY total_occurrences DESC;


--============================================================================================================================
/*Booking-Side Questions
B1. Which 5 drivers have completed the most trips? 
What does "completed" mean here, and which table tells you that
*/

WITH TotalDriverTrips AS (
    SELECT 
        driver_id,
        COUNT(*) AS completed_trips,
        DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS driver_rank
    FROM 
        booking.fact_trips
    WHERE 
        status = 'Completed'
    GROUP BY 
        driver_id
)
SELECT 
    driver_id,
    completed_trips,
    driver_rank
FROM 
    TotalDriverTrips
WHERE 
    driver_rank <= 5
ORDER BY 
    driver_rank ASC;








