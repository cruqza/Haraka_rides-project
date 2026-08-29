
create schema fleet;

set search_path to fleet;
--===========================================================================================================================

create table fleet.dim_vehicles(
	vehicle_id serial primary key,
	vehicle_plate VARCHAR(20) not null unique,
	vehicle_make VARCHAR(50) not null,
	vehicle_model VARCHAR(50) not null 
);

--===========================================================================================================================


insert into fleet.dim_vehicles (vehicle_plate, vehicle_make, vehicle_model)
select distinct 
	nullif(
	trim(UPPER(vehicle_plate)), ''
	) as vehicle_plate,
	nullif(trim(initcap(vehicle_make)), '') as vehicle_make,
	nullif(trim(initcap(vehicle_model)), '') as vehivle_model
from fleet_system_staging.fleet_staging
where vehicle_plate is not null
and trim(vehicle_plate) not in ('', 'null', 'n/a', 'NULL', 'N/A');




select * from fleet.dim_vehicles;

--======================================================================================================================--
/*4. Do the same for fuel_logs and maintenance_logs in the fleet schema, 
splitting the merged event log back into two proper tables based on event_type.
--here we are creating the fuel logs
*/
 
create table if not exists fleet.fuel_logs(
	log_id serial primary key,
	vehicle_plate text,
	event_type text,
	event_date text,
	liters text,
	fuel_cost text,
	station_name text
);

--we then insert the details in the fuel.logs table from the fleet.stanging

insert into fleet.fuel_logs(vehicle_plate, event_type, event_date, liters, fuel_cost, station_name)
select distinct 
	nullif(
	trim(UPPER(vehicle_plate)), ''
	) as vehicle_plate,
	nullif(trim(initcap(event_type)), '') as event_type,
	CASE 
        WHEN event_date ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(event_date, 'YYYY-MM-DD')
        WHEN event_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(event_date, 'DD/MM/YYYY')
        WHEN event_date ~ '^\d{2}/\d{2}/\d{2}$' THEN TO_DATE(event_date, 'DD/MM/YY')
        WHEN event_date ~ '^\d{2}-\d{2}-\d{4}$' THEN TO_DATE(event_date, 'MM-DD-YYYY')
        ELSE NULL 
    END,
    nullif(trim(regexp_replace(liters, '[^0-9.]', '', 'g')), ''):: numeric,
    nullif(TRIM(regexp_replace(fuel_cost, '[^0-9.]', '', 'g')), ''):: numeric(10,2),
    nullif(trim(initcap(station_name)), '') as station_name
from fleet_system_staging.fleet_staging
where event_type = 'Fuel';

select * from fleet.fuel_logs;

--======================================================================================================================
--we then create a maintenance log table from fleet.stanging

create table if not exists fleet.maintenance_logs(
	log_id serial primary key,
	vehicle_plate text,
	event_date text,
	event_type text,
	maintenance_cost text,
	mechanic_name text,
	next_service_due text,
	service_type text
);

--we then insert table from the fleet_staging table

insert into fleet.maintenance_logs(vehicle_plate, event_date, event_type, maintenance_cost, 
		mechanic_name, next_service_due, service_type)
select 
	nullif(trim(UPPER(vehicle_plate)), '') as vehicle_plate,
	CASE 
        WHEN event_date ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(event_date, 'YYYY-MM-DD')
        WHEN event_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(event_date, 'DD/MM/YYYY')
        WHEN event_date ~ '^\d{2}/\d{2}/\d{2}$' THEN TO_DATE(event_date, 'DD/MM/YY')
        WHEN event_date ~ '^\d{2}-\d{2}-\d{4}$' THEN TO_DATE(event_date, 'MM-DD-YYYY')
        ELSE NULL 
    END,
    nullif(trim(initcap(event_type)), '') as event_type,
    nullif(TRIM(regexp_replace(maintenance_cost, '[^0-9.]', '', 'g')), ''):: numeric(10,2),
    nullif(trim(initcap(mechanic_name)), '') as mechanic_name,
    CASE 
        WHEN next_service_due ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(next_service_due, 'YYYY-MM-DD')
        WHEN next_service_due ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(next_service_due, 'DD/MM/YYYY')
        WHEN next_service_due ~ '^\d{2}/\d{2}/\d{2}$' THEN TO_DATE(next_service_due, 'DD/MM/YY')
        WHEN next_service_due ~ '^\d{2}-\d{2}-\d{4}$' THEN TO_DATE(next_service_due, 'MM-DD-YYYY')
        ELSE NULL 
    END,
    nullif(trim(initcap(service_type)), '') as service_type
from fleet_system_staging.fleet_staging
where event_type = 'Maintenance';



select * from fleet.maintenance_logs;
--======================================================================================================================
select * from fleet.fuel_logs;
select * from fleet.maintenance_logs;
select * from fleet.dim_vehicles;



