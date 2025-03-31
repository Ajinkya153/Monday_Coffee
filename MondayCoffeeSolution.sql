--MondayCoffee project

-- Table creation (Start with something which has no referencing to others.)

create table city
(
city_id int primary key,
city_name varchar(25),
population bigint,
estimated_rent numeric(10,2),
city_rank int

);

create table customers
(
customer_id	int primary key,
customer_name varchar(50),
city_id int,

foreign key (city_id) references city(city_id)
)
;

drop table if exists products;		
create table products
(
product_id int primary key,
product_name varchar(50),
price float

)
;

drop table if exists sales;	
create table sales
(
sale_id int,
sale_date date,
product_id int,
customer_id	int,
total float,
rating int,
foreign key (product_id) references products (product_id),
foreign key (customer_id) references customers (customer_id)

);

TRUNCATE TABLE sales, customers, city;

--Data exploration
select*from city;
select*from products;
select*from customers;
select*from sales;



-- Business problems
---- Q.1 Coffee Consumers Count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?

select city_name, 
population/1000000 as Total_Population, 
round((population*0.25/1000000),2) as market_size_million 
from city
order by population desc;

-- -- Q.2
-- Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

select
total as revenue,
extract(quarter from sale_date) as qtr,
extract(year from sale_date) as year

from sales
where 
extract(quarter from sale_date)=4
and
extract(year from sale_date) =2023
;

select
sum(total) as total_revenue

from sales
where 
extract(quarter from sale_date)=4
and
extract(year from sale_date) =2023
;

--city wise revenue
select
ct.city_name,
sum(total) as total_revenue

from sales as s
join customers as c
on s.customer_id =c.customer_id
join city as ct
on c.city_id=ct.city_id


where 
extract(quarter from s.sale_date)=4
and
extract(year from s.sale_date) =2023
group by 1 
order by 2 desc
;

-- Q.3
-- Sales Count for Each Product
-- How many units of each coffee product have been sold?

select 
s.product_id,
p.product_name,
count(s.product_id) as units_sold,
sum(s.total) as Total_revenue

from sales as s
join products as p
on s.product_id= p.product_id
group by 1,2
order by 1 asc;

--better way to avoid zero sales products too
SELECT 
  p.product_id,
  p.product_name,
  COUNT(s.product_id) AS units_sold,
  COALESCE(SUM(s.total), 0) AS total_revenue
FROM products AS p
LEFT JOIN sales AS s
  ON s.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY p.product_id ASC;

--- Q.4
-- Average Sales Amount per City
-- What is the average sales amount per customer in each city?

select customer_name,sum(total) as total_rev

from customers as c
left join sales as s
on c.customer_id=s.customer_id
group by 1
order by 2 desc
;


select
ct.city_name,
sum(total) as total_revenue,
count( distinct c.customer_id) as Cus,
round(sum(s.total)/count( distinct c.customer_id)) as Avr_sale_percity_percus

from sales as s
join customers as c
on s.customer_id =c.customer_id
join city as ct
on c.city_id=ct.city_id

group by 1 
order by 2 desc;

- -- Q.5
--For each city, tell me the current coffee market size (25% of Popl),
--how much we’ve already captured (via customers),
--and how much is still left to capture.

select city_name, 
round((population*0.25)) as Est_market_size
from city;

select city_id,
count(*) as current_customers
from customers
group by 1;

SELECT 
  ct.city_name,
  ROUND(ct.population * 0.25) AS estimated_market_size,
  COUNT(c.customer_id) AS current_customers,
  ROUND(ct.population * 0.25 * 0.01) AS target_customers,
  ROUND(
    COUNT(c.customer_id) * 100.0 / (ct.population * 0.25),
    3
  ) AS market_captured_percent
FROM city AS ct
LEFT JOIN customers AS c
  ON ct.city_id = c.city_id
GROUP BY ct.city_id, ct.city_name, ct.population
ORDER BY target_customers DESC;


---- -- Q6
-- Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?


select *
from 
(
select  ct.city_name,
p.product_name, 
count(*) as units_sold,
  dense_RANK() OVER (
    PARTITION BY ct.city_name ORDER BY COUNT(*) DESC) AS R

from sales as s
join products as p
on s.product_id=p.product_id
join customers as c
on s.customer_id=c.customer_id
join city as ct
on c.city_id=ct.city_id

group by 2,1

) as t1


where R<=3
;


--- Q.7
-- Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?


SELECT 
  ct.city_name,
  COUNT(distinct c.customer_id) AS unique_customers
  
FROM city AS ct
LEFT JOIN customers AS c
  ON ct.city_id = c.city_id
join sales as s
on c.customer_id=s.customer_id
where
s.product_id BETWEEN 1 AND 14
group by 1;

-- 
-- -- Q.8
-- Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer

with city_table
as
(
select
ct.city_name,
sum(total) as total_revenue,
count( distinct c.customer_id) as Cus,
round(sum(s.total)/count( distinct c.customer_id)) as Avr_sale_percity_percus

from sales as s
join customers as c
on s.customer_id =c.customer_id
join city as ct
on c.city_id=ct.city_id

group by 1 
order by 2 desc
),

city_rent as
(
select city_name, 
estimated_rent
from city
)


select 
cr.city_name, 
cr.estimated_rent,
ctt.cus,
ctt.Avr_sale_percity_percus,
round(cr.estimated_rent/ctt.cus) as avr_rent_per_cus



from city_rent as cr
join city_table as ctt
on cr.city_name=ctt.city_name
order by 4 desc


---- Q.9
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city
WITH monthly_sale AS (
  SELECT
    ct.city_name,
    EXTRACT(MONTH FROM s.sale_date) AS month,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    SUM(s.total) AS total_sale
  FROM sales AS s
  JOIN customers AS c ON s.customer_id = c.customer_id
  JOIN city AS ct ON c.city_id = ct.city_id
  GROUP BY ct.city_name, year, month
),

growth_calc AS (
  SELECT
    city_name,
    month,
    year,
    total_sale AS cr_month_sale,
    COALESCE(
      LAG(total_sale, 1) OVER (
        PARTITION BY city_name 
        ORDER BY year, month
      ), 0
    ) AS last_month_sale,

    ROUND(
      (
        100.0 * (total_sale - COALESCE(LAG(total_sale, 1) OVER (PARTITION BY city_name ORDER BY year, month), 0)) /
        NULLIF(COALESCE(LAG(total_sale, 1) OVER (PARTITION BY city_name ORDER BY year, month), 0), 0)
      )::NUMERIC,
      2
    ) AS growth_percent
  FROM monthly_sale
)

SELECT *
FROM growth_calc
WHERE growth_percent IS NOT NULL
ORDER BY city_name, year, month;

---- Q.10
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer

with city_table
as
(
select
ct.city_name,
sum(total) as total_revenue,
count( distinct c.customer_id) as Cus,
round(sum(s.total)/count( distinct c.customer_id)) as Avr_sale_percity_percus

from sales as s
join customers as c
on s.customer_id =c.customer_id
join city as ct
on c.city_id=ct.city_id

group by 1 
order by 2 desc
),

city_rent as
(
select 
city_name, 
estimated_rent,
round(population*0.25) as Est_coffee_consumer,
round((population*0.25*0.01)) as Target_1pc_marketshare
from city
)


select 
cr.city_name, 
cr.estimated_rent,
ctt.cus,
cr.Target_1pc_marketshare,
ctt.Avr_sale_percity_percus,
round(cr.estimated_rent/ctt.cus) as avr_rent_per_cus,
round((cr.Target_1pc_marketshare*ctt.Avr_sale_percity_percus)/1000000) as Max_Potential_Revenue


from city_rent as cr
join city_table as ctt
on cr.city_name=ctt.city_name
order by 7 desc


--FINAL RECOMMENDATIONS--
-- 1) DELHI - Highest Potential in Sales 
-- 2) Pune- Espected to have decent potential with highest Profitability due to lower costs
-- 3) Chennai- Offers a balance of high potential and affordable rent