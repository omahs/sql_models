{{ 
  config(
    materialized='incremental', 
    sort='block_timestamp', 
    unique_key='block_id', 
    incremental_strategy='delete+insert',
    cluster_by=['block_timestamp'],
    tags=['snowflake', 'terra', 'mirror', 'mirror_gov']
  )
}}

SELECT 
  m.blockchain,
  chain_id,
  block_id,
  block_timestamp,
  tx_id,
  msg_value:sender::string as voter,
  msg_value:execute_msg:cast_vote:poll_id as poll_id,
  msg_value:execute_msg:cast_vote:vote::string as vote,
  msg_value:execute_msg:cast_vote:amount / POW(10,6) as balance,
  msg_value:contract::string as contract_address,
  l.address_name as contract_label 
FROM {{source('silver_terra', 'msgs')}} m

LEFT OUTER JOIN {{source('shared','udm_address_labels_new')}} as l
ON msg_value:contract::string = l.address

WHERE msg_value:contract::string = 'terra1wh39swv7nq36pnefnupttm2nr96kz7jjddyt2x' -- MIR Governance
  AND msg_value:execute_msg:cast_vote IS NOT NULL 
  AND tx_status = 'SUCCEEDED'
