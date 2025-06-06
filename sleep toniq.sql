# initial view of data

select
customer_id,
count(*) as number_of_orders
from orders
where gross_sales > 0
group by customer_id
order by number_of_orders desc, customer_id desc;

select *
from orders_per_customer;

# join tables to view all data together

select *
from orders o
left join orders_per_customer c
on o.customer_id = c.customer_id
where o.gross_sales > 0;

# add row numbers, resetting for each new customer

select *,
row_number() over (partition by customer_id order by date) as customer_order_number
from orders
where gross_sales > 0
order by date;

select 
date, 
customer_order_number
from paid_orders
where customer_order_number != 1
order by date;

# find repeat customers (ie more than 1 order)

select 
month, 
year,
count(customer_order_number) as existing_customer_order_count
from paid_orders
where customer_order_number > 1
group by month, year;

select * 
from new_customer_count a
join existing_customer_order_count b
on a.month = b.month and a.year = b.year;


select 
date,
gross_sales,
customer_id,
customer_order_number
from paid_orders
order by customer_id, customer_order_number;


select *
from customers_brief
order by total_orders desc;

# formatting

alter table customers_brief
rename column `Total Orders` to total_orders;

# find the most recent order for each customer

update customers_brief c
join last_order_date l
on c.customer_id = l.customer_id
set last_order_date = `max(date)`;

alter table customers_brief
modify column last_order_date date;

# use datediff to find the lifetime of customers (time between first and last orders)

select
customer_id,
total_orders,
first_order_date,
last_order_date,
datediff(last_order_date, first_order_date)
from customers_brief
order by total_orders desc;

update customers_brief
set lifespan_days = datediff(last_order_date, first_order_date) + 1
where total_orders > 0;

select *
from customers_brief;

# create columns for order frequency, average spend and activity (whether a customer is 'active' - based on order frequency and time since last order)

alter table customers_brief
add order_frequency float;

update customers_brief
set order_frequency = lifespan_days/(total_orders - 1)
where total_orders > 1;

alter table customers_brief
add average_spend float;

update customers_brief
set average_spend = round(total_spent/total_orders,2)
where total_orders > 0;

delete from customers_brief
where total_spent = 0;

select *
from customers_brief
order by total_orders desc;

alter table customers_brief
add days_since_last_order int;

update customers_brief
set days_since_last_order = datediff(curdate(), last_order_date);

alter table customers_brief
add status text;

update customers_brief
set status = 'active'
where days_since_last_order/2 <= order_frequency;

update customers_brief
set status = 'inactive'
where days_since_last_order/2 > order_frequency;

select *
from customers_brief
where accepts_email_marketing = 'yes';

select
`First Name`,
`Last Name`,
`Accepts Email Marketing`,
`Total Orders`
from customers
order by `Total Orders` desc;

select *
from customers_brief;

# create table for exporting, showing activity of customers

select 
(select
round(avg(total_spent),2)
from customers_numbers
where status = 'inactive'
and total_orders < 5) as 'inactive<5',
(select
round(avg(total_spent),2)
from customers_numbers
where status = 'inactive'
and total_orders >= 5) as 'inactive5+',
(select
round(avg(total_spent),2)
from customers_numbers
where status = 'inactive') as 'inactive_total',
(select
round(avg(total_spent),2)
from customers_numbers
where status = 'active'
and total_orders < 5) as 'active<5',
(select
round(avg(total_spent),2)
from customers_numbers
where status = 'active'
and total_orders >= 5) as 'active5+',
(select
round(avg(total_spent),2)
from customers_numbers
where status = 'active') as 'active_total',
(select
round(avg(total_spent),2)
from customers_numbers
where total_orders < 5) as '<5total',
(select
round(avg(total_spent),2)
from customers_numbers
where total_orders >= 5) as '5+total'
from customers_numbers;

select *
from customers_numbers;

select *
from paid_orders;

# create table for exporting, showing discounts

select
Name, 
`Paid at`, 
date,
Id,
order_name, 
customer_id, 
subtotal,
`Discount Amount`,
Total,
gross_sales
from orders2
left join orders
on orders2.Name = orders.order_name;

select *
from orders2
order by Name, Total desc;

alter table orders2
add year int;

alter table orders2
drop column id;

update orders2 o2
join orders o
on Name = order_name
set o2.date = o.date;

select *
from orders2
where `Fulfillment status` = 'fulfilled';

alter table orders2
rename column `Shipping Province Name` to shipping_province;

update orders2
set discount_code = null
where discount_code = '';

delete
from orders2
where customer_id = 0;

# create table for exporting, showing discounts

select
customer_id,
count(discount_code) as discounts,
round(sum(discount_amount),2) as total_discount,
count(customer_id) as orders,
round(sum(total),2) as total_spent
from orders2
group by customer_id
having sum(total) > 0
order by discounts desc, total_spent desc;

select
discount_code,
count(discount_code) as times_used,
round(sum(discount_amount),2) as total_saved
from orders2
where discount_code is not null
group by discount_code
order by times_used desc, total_saved desc;

select
shipping_province, 
count(shipping_province) as order_count
from orders2
where shipping_province != ''
group by shipping_province;

update orders2
set year = year(date), month = month(date);

select
year,
month, 
sum(lineitem_name * lineitem_quantity) as cans_sold,
round(sum(total),2) as total_sales,
round(sum(total)/sum(lineitem_name * lineitem_quantity),2) as sales_per_can,
count(lineitem_name) as order_count,
count(discount_code) as discount_count,
round(sum(discount_amount),2) as total_discount
from orders2
where lineitem_name != 'Giftbox'
group by year, month
order by year, month