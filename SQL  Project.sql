--                                     STEP 1 - CREATING DATABASE "amazon"


create database amazon;
use amazon;

-- CREATING STAGING TABLE

create table staging_table
(
Invoice_id varchar(255),
Branch varchar(255),
City varchar(255),
Customer_type varchar(255),
Gender varchar(255),
Product_line varchar(255),
Unit_price double,
Quantity double,
VAT double,
Total double,
Date varchar(255),
Time varchar(255),
Payment_method varchar(255),
COGS double,
Gross_margin_Percentage double,
Gross_Income double,
Rating double
);

load data infile "C:/ProgramData/MySQL/MySQL Server 8.0/Data/Amazon.csv"
into table staging_table
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;
 
 
--                                                STEP 2 -  DATA WRANGLING


--  i. CHECKING NULL VALUES ACROSS ALL COLUMNS
select 
sum(case when invoice_id is null then 1 else 0 end) as null_invoice_id,
sum(case when branch is null then 1 else 0 end) as null_branch,
sum(case when city is null then 1 else 0 end) as null_city,
sum(case when customer_type is null then 1 else 0 end) as null_customer_type,
sum(case when gender is null then 1 else 0 end) as null_gender,
sum(case when product_line is null then 1 else 0 end) as null_product_line,
sum(case when unit_price is null then 1 else 0 end) as null_unit_price,
sum(case when quantity is null then 1 else 0 end) as null_quantity,
sum(case when vat is null then 1 else 0 end) as null_vat,
sum(case when total is null then 1 else 0 end) as null_total,
sum(case when date is null then 1 else 0 end) as null_date,
sum(case when time is null then 1 else 0 end) as null_time,
sum(case when payment_method is null then 1 else 0 end) as null_payment_method,
sum(case when cogs is null then 1 else 0 end) as null_cogs,
sum(case when gross_margin_percentage is null then 1 else 0 end) as null_gross_margin_percentage,
sum(case when gross_income is null then 1 else 0 end) as null_gross_income,
sum(case when rating is null then 1 else 0 end) as null_rating
from staging_table;

-- ii. CHECKING DEPLICATE VALUES
select Invoice_id, Branch, City, Customer_Type, Gender, Product_Line, 
       Unit_Price, Quantity, VAT, Total, Date, Time, Payment_Method, 
	   COGS, Gross_Margin_Percentage, Gross_Income, Rating, count(*) 
from staging_table
group by Invoice_id, Branch, City, Customer_Type, Gender, Product_Line, 
       Unit_Price, Quantity, VAT, Total, Date, Time, Payment_Method, 
	   COGS, Gross_Margin_Percentage, Gross_Income, Rating;
       
select * from staging_table;


--                       STEP 3 - CREATING SALES TABLE WITH APPROPRIATE DATA TYPES AND CONSTRAINTS


create table sales
(
Invoice_id varchar(30),
Branch varchar(5) not null,
City varchar(30) not null,
Customer_type varchar(30) not null,
Gender varchar(10) not null,
Product_line varchar(100) not null,
Unit_price decimal(10,2) not null,
Quantity int not null,
VAT float(6,2) not null,
Total decimal(10,2) not null,
Date date not null,
Time time not null,
Payment_Method varchar(30) not null,
COGS decimal(10,2) not null,
Gross_Margin_Percentage float(11,2) not null,
Gross_Income decimal(10,2) not null,
Rating float(3,1) not null,
primary key (Invoice_id)
);

--  TRANSFERRING DATA FROM STAGING TABLE TO TARGET TABLE "sales" 
--  AND CHANGING DATE AND TIME FORMAT

insert into sales(Invoice_id, Branch, City, Customer_Type, Gender, Product_Line, 
                  Unit_Price, Quantity, VAT, Total, Date, Time, Payment_Method, 
                  COGS, Gross_Margin_Percentage, Gross_Income, Rating)
		  (select Invoice_id, Branch, City, Customer_Type, Gender, Product_Line, 
                  Unit_Price, Quantity, VAT, Total, str_to_date(date,"%m/%d/%Y"), 
                  str_to_date(Time,"%H:%i:%s"), Payment_Method, COGS,
                  Gross_Margin_Percentage, Gross_Income, Rating from staging_table);


--                              STEP 4 - FEATURE ENGINEERING


-- 1. REMOVING COLUMN "Gross_Margin_Percentage" AND "Gross_Income"
alter table sales drop column Gross_Margin_Percentage;
alter table sales drop column Gross_Income;

-- 2. ADDING TIME_OF_DAY COLUMN
alter table sales add column time_of_day varchar(10) not null;
update sales 
set time_of_day = case when time between "06:00:00" and "12:00:00" then "Morning"
				       when time between "12:00:00" and "18:00:00" then "Afternoon"
                       else "Evening" 
				  end;

-- 3. ADDING DAY_NAME COLUMN
alter table sales add column day_name varchar(10);
update sales 
set day_name = date_format(date,"%a");

-- 4. ADDING MONTH_NAME COLUMN
alter table sales add column month_name varchar(10);
update sales 
set month_name = date_format(date,"%b");

-- 5. Creating customer table 
create table customers as
(select invoice_id, branch, city, customer_type, gender from sales);
alter table customers add primary key customers(invoice_id);

-- 6. Creating order table 
create table orders as
(select invoice_id, product_line, date, time, time_of_day, 
day_name, month_name, rating from sales);
alter table orders add primary key orders(invoice_id);

-- 7. Creating payment table 
create table payments as
(select invoice_id, payment_method, quantity, unit_price, 
vat, cogs, total from  sales);
alter table payments add primary key payments(invoice_id);


 --                               QUESTIONS
 
 
-- 1. What is the count of distinct cities in the dataset?
select count( distinct city) as city_count 
from customers;

-- comment:- There are 3 distinct cities Mandalay, Naypyitaw and Yangon.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 2. For each branch, what is the corresponding city?
select distinct branch, 
       city 
from customers 
order by branch;

-- comment:- For branch A, B and C the corresponding cities are Yangon, Mandalay, Naypyitaw.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 3. What is the count of distinct product lines in the dataset?
select count(distinct product_line) as product_count 
from orders;
-- comment:- There are 6 distinct product lines.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 4. Which payment method occurs most frequently?
select payment_method, 
       count(*) as count 
from payments 
group by payment_method
order by count(*) desc
limit 1;

-- E-wallet payment mode occurs more frequently 345 times.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Which product line has the highest sales?
select product_line,
       sum(quantity) as total_sales
from orders o inner join payments p 
on o.invoice_id=p.invoice_id
group by product_line
order by total_sales desc
limit 1;

-- comment:- Electronic accessories category have highest sale of 971 products.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 6. How much revenue is generated each month?
select month_name, 
       sum(total) as revenue
from orders o inner join payments p 
on o.invoice_id=p.invoice_id
group by month_name
order by field(month_name, "Jan","Feb","Mar");

-- comment:- The revenue generated in January, February and March months are 116291.87, 97219.37 and 109455.51 respectively.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 7. In which month did the cost of goods sold reach its peak?
select month_name, 
       sum(cogs) as tot_cogs
from orders o inner join payments p
on o.invoice_id=p.invoice_id
group by month_name
order by tot_cogs desc
limit 1;

-- comment:- The cost of goods sold was maximum in january month of 110754.16.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 8. Which product line generated the highest revenue?
select product_line, 
       sum(total) as tot_revenue
from orders o inner join payments p
on o.invoice_id=p.invoice_id
group by product_line
order by tot_revenue desc
limit 1;

-- comment:- The Food and beverages category has generated highest revenue of 56144.84.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 9. In which city was the highest revenue recorded?
select city, 
       sum(total) as tot_revenue
from customers c inner join payments p
on c.invoice_id=p.invoice_id
group by city
order by tot_revenue desc
limit 1;

-- comment:- Naypyitaw city has recorded highest revenue of 110568.71.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 10. Which product line incurred the highest Value Added Tax?
select product_line, 
       sum(vat) as tot_vat
from orders o inner join payments p
on o.invoice_id=p.invoice_id
group by product_line
order by tot_vat desc
limit 1;

-- comment:- Food and beverages is liable to highest vat of 2673.56.
 -----------------------------------------------------------------------------------------------------------------------------------------------------

-- 11. For each product line, add a column indicating "Good" if its sales are above average, otherwise "Bad."
with total_sales as
(select product_line, 
        sum(total) as tot_sales
from orders o inner join payments p
on o.invoice_id=p.invoice_id
group by product_line),

average as
(select avg(tot_sales) as avg_sales from total_sales)

select product_line, tot_sales, 
case when tot_sales > avg_sales then "Good"
     else "Bad" end as category_performance
from total_sales join average 
order by tot_sales;

-- comment:- Health and beauty category is performing below average rest all product_lines are above avrage.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 12. Identify the branch that exceeded the average number of products sold.
with product_count as
(select branch, 
        sum(quantity) as sum_orders
from customers c inner join payments p 
on c.invoice_id = p.invoice_id
group by branch),

average as
(select avg(sum_orders) as avg_orders from product_count)

select branch, sum_orders, avg_orders 
from product_count join average
where sum_orders > avg_orders;

-- comment:- Branch A of Yangon city has saled more than average products.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 13. Which product line is most frequently associated with each gender?
with product_category as
(select gender, 
        product_line, 
		count(quantity) as sum_quantity
from customers c inner join orders o
on c.invoice_id = o.invoice_id
inner join payments p
on o.invoice_id = p.invoice_id
group by gender, product_line
order by gender, sum_quantity desc),

ranking as
(select *, row_number() over(partition by gender order by gender) as rnk from product_category)

select gender, 
       product_line, 
       sum_quantity 
from ranking 
where rnk <= 3;

-- comment:- Top 3 products under female category are fashion accessories, food and beverages, sports and travel.
--           Top 3 products under male category are health and beauty, electronic accessories and food and beverages.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 14. Calculate the average rating for each product line.
select product_line, 
       round(avg(rating),2) as avg_rating 
from orders
group by product_line
order by avg_rating desc;

-- comment:- The average rating of food and beverages is highest 7.11 followed by fashion accessories 7.03.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 15. Count the sales occurrences for each time of day on every weekday.
select day_name, time_of_day, count(invoice_id) as order_count
from orders 
group by day_name, time_of_day
order by field(day_name, "sun","mon","tue","wed","thu","fri","sat") , 
         order_count desc;

-- comment:- coment:- Most of the sales have occurred in saturday and wednesday afternoon.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 16. Identify the customer type contributing the highest revenue.
select distinct customer_type, 
	   sum(total) over(partition by customer_type) as revenue,
       concat(round(sum(total) over(partition by customer_type)/sum(total) over()*100,2),"%") as percent
from customers c inner join payments p 
on c.invoice_id = p.invoice_id;

-- comment:- members contributed to 51% of total revenue 
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 17. Determine the city with the highest VAT percentage.
select distinct city, 
       sum(vat) over(partition by city) as vat,
       concat(round(sum(vat) over(partition by city)/sum(vat) over()*100,2),"%") as percent
from customers c inner join payments p 
on c.invoice_id = p.invoice_id;

-- comment:- Naypyitaw is contributing to highest VAT percentage of 34.24 %.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 18. Identify the customer type with the highest VAT payments.
select customer_type,
       sum(vat) as total_vat
from customers c inner join payments p 
on c.invoice_id = p.invoice_id
group by customer_type
order by total_vat desc
limit 1;

-- comment:- Members are contributing 7820.25 VAT.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 19. What is the count of distinct customer types in the dataset?
select distinct customer_type
from customers;

-- comment:- There are two types of customers Menber and Normal customer.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 20. What is the count of distinct payment methods in the dataset?
select distinct payment_method 
from payments;

-- comment:- There are 3 payment methods available Ewallet, Cash and Credit card mode.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 21. Which customer type occurs most frequently?
select customer_type,
       count(customer_type) as occurence
from customers 
group by customer_type
order by occurence desc
limit 1;

-- comment:- members are ordering more frequently which is 501.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 22. Identify the customer type with the highest purchase frequency.
select customer_type,
       count(customer_type) as purch_frequency
from customers 
group by customer_type
order by purch_frequency desc
limit 1;

-- comment:- members are purchasing more frequently which is 501 orders.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 23. Determine the predominant gender among customers.
select gender as dominant_gender, 
       count(invoice_id) as count
from customers 
group by gender
order by count desc
limit 1;

-- comment:- Females are predominant gender with 501 orders.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 24. Examine the distribution of genders within each branch.
with gender_distribution as
(select distinct branch, 
       gender, 
       count(gender) over(partition by branch,gender) as genderwise_count,
       count(gender) over(partition by branch) as branchwise_count
from customers 
order by branch, genderwise_count desc)

select branch, 
       gender, 
       genderwise_count,
       concat(round(genderwise_count/branchwise_count*100,2),"%") as percent
from gender_distribution;

-- comment:- 
--          In branch A there are 47.35% female customers and 52.65% male custmers
--          In branch B there are 48.80% female customers and 51.20% male custmers
--          In branch C there are 54.27% female customers and 45.73% male custmers
--      so in branch A and B majority of customers are males whereas in branch C majority of customers are females
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 25. Identify the time of day when customers provide the most ratings.
select distinct time_of_day, 
       count(rating) over(partition by time_of_day) as ratings,
       concat(round(count(rating) over(partition by time_of_day)/count(rating) over()*100,2),"%") as percent
from orders
order by ratings desc;

-- comment:- 53% of customer ratings have been made in afternoon.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 26. Determine the time of day with the highest customer ratings for each branch.
with ratings as
(select distinct branch, 
        time_of_day,
        count(rating) over(partition by branch, time_of_day) as highest_rating,
        count(rating) over(partition by branch) as branchwise_rating
from orders o inner join customers c
on o.invoice_id = c.invoice_id
order by branch, highest_rating desc),

ranking as
(select *, 
        row_number() over(partition by branch) as rnk
from ratings)

select branch, 
	   time_of_day, 
       highest_rating,
	   concat(round(highest_rating/branchwise_rating*100 ,2),"%") as percent
from ranking
where rnk=1 ;

-- comment:- branch A- 54.71% in afternoon
-- 	   	     branch B- 49.10% in afternoon
--           branch C- 55.18% in afternoon
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 27. Identify the day of the week with the highest average ratings.
select day_name, round(avg(rating),2)  avg_rating
from orders
group by day_name
order by avg_rating desc;

-- Comment:- Most ratings have been given on monday and friday.
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- 28. Determine the day of the week with the highest average ratings for each branch.
with ratings as
(select branch,
        day_name,
        round(avg(rating),2) as highest_avg_rating
from customers c inner join orders o
on c.invoice_id = o.invoice_id
group by branch, day_name
order by branch, highest_avg_rating desc),

ranking as
(select *, 
        row_number() over(partition by branch) as rnk
 from ratings)
 
 select branch, 
        day_name,
        highest_avg_rating 
from ranking 
where rnk=1;

-- comment:- The highest average ratings given to branch A, B and C are on Friday, Monday and Friday respectively.
