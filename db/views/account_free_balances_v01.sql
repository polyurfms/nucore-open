SELECT
    aue.account_id AS account_id,
    a2.committed_amt,
    SUM(aue.expense_amt) AS total_expense
FROM
    account_user_expenses aue
INNER JOIN accounts a2 ON
    a2.id = aue.account_id
GROUP BY
    aue.account_id
