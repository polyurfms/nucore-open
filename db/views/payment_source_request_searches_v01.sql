select
	u.id as user_id,
	a.id as account_id,
	ea.username,
	a.account_number,
	a.description,
	a.expires_at,
	psr.created_at
from
	external_accounts ea
join accounts a on
	a.account_number = ea.account_number
	and a.suspended_at is null
join users u on
	u.username = ea.username
	and u.suspended_at is null
LEFT JOIN payment_source_requests psr ON
	psr.account_id = a.id
where
	ea.user_role = 'N'
	and (ea.account_number,
	ea.username) not in (
	select
		a.account_number, u.username
	from
		account_users au
	join accounts a on
		a.id = au.account_id
	join users u on
		u.id = au.user_id
	where
		au.user_role = 'Purchaser' AND au.deleted_at IS NULL )