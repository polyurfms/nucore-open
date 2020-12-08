SELECT au.id as account_user_id, od.account_id, o.user_id,
sum(case when od.actual_cost is null then od.estimated_cost
         else od.actual_cost end) as expense_amt
 FROM order_details od
join orders o on o.id = od.order_id
join account_users au on au.account_id = od.account_id
	and au.user_id = o.user_id
where od.canceled_at is null
group by au.id, account_id, user_id
