SELECT
      a.id AS account_id,
      a.committed_amt AS committed_amt,
      COALESCE(SUM((CASE
                  WHEN ISNULL(od.actual_cost) THEN od.estimated_cost
                  ELSE od.actual_cost
              END)),
              0) AS total_expense
  FROM
      accounts a
      JOIN order_details od ON od.account_id = a.id
          AND od.state <> 'validated'
          AND ISNULL(od.canceled_at)
      JOIN orders o ON o.id = od.order_id
          AND o.state <> 'validated'
  GROUP BY a.id , a.committed_amt
