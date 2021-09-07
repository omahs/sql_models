{{ 
  config(
    materialized='incremental', 
    sort='block_timestamp', 
    unique_key='block_id', 
    incremental_strategy='delete+insert',
    cluster_by=['block_timestamp'],
    tags=['snowflake', 'terra', 'mirror', 'short_farm']
  )
}}

WITH msgs as(

SELECT 
  blockchain,
  chain_id,
  block_id,
  block_timestamp,
  tx_id,
  msg_value:sender::string AS sender,
  msg_value:execute_msg:open_position:collateral_ratio AS collateral_ratio,
  msg_value:contract::string AS contract_address,
  l.address_name AS contract_label
FROM {{source('silver_terra', 'msgs')}}

LEFT OUTER JOIN {{source('shared','udm_address_labels_new')}} as l
ON contract_address = l.address

WHERE msg_value:contract::string = 'terra1wfz7h3aqf4cjmjcvc6s8lxdhh7k30nkczyf0mj' --Mirror Mint
  AND msg_value:execute_msg:open_position IS NOT NULL 
  AND tx_status = 'SUCCEEDED'

),

events as (

SELECT
  tx_id,
  event_attributes:"0_position_idx" as collateral_id,
  
  event_attributes:collateral_amount[0]:amount / POW(10,6) AS collateral_amount, 
  collateral_amount * o.price AS collateral_amount_usd,
  event_attributes:collateral_amount[0]:denom::string AS collateral_currency,
  
  event_attributes:mint_amount[0]:amount / POW(10,6) AS mint_amount,
  mint_amount * i.price AS mint_amount_usd, 
  event_attributes:mint_amount[0]:denom::string AS mint_currency,
  
  event_attributes:return_amount / POW(10,6) AS return_amount,
  return_amount * r.price AS return_amount_usd, 
  'uusd' AS return_currency, 
  
  event_attributes:locked_amount[0]:amount / POW(10,6) AS locked_amount,
  locked_amount * l.price AS locked_amount_usd,
  event_attributes:locked_amount[0]:denom::string AS locked_currency,
  
  event_attributes:tax_amount / POW(10,6) AS tax,
  event_attributes:commission_amount / POW(10,6) AS commission,
  event_attributes:spread_amount / POW(10,6) AS spread,
  
  to_timestamp(event_attributes:unlock_time) AS unlock_time
FROM {{source('silver_terra', 'msg_events')}} t

LEFT OUTER JOIN prices o
 ON date_trunc('hour', t.block_timestamp) = o.hour
 AND t.collateral_currency = o.currency 

LEFT OUTER JOIN prices i
 ON date_trunc('hour', t.block_timestamp) = i.hour
 AND t.mint_currency = i.currency  

LEFT OUTER JOIN prices r
 ON date_trunc('hour', t.block_timestamp) = o.hour
 AND t.return_amount = o.currency 

LEFT OUTER JOIN prices l
 ON date_trunc('hour', t.block_timestamp) = i.hour
 AND t.locked_currency = i.currency  

WHERE event_type = 'from_contract'
  AND event_attributes:is_short::string = 'true'
  AND event_attributes:from::string = 'terra1wfz7h3aqf4cjmjcvc6s8lxdhh7k30nkczyf0mj' -- Mirror Mint
  AND tx_status = = 'SUCCEEDED'

)

SELECT
  blockchain, 
  chain_id, 
  block_id, 
  block_timestamp, 
  m.tx_id, 
  collateral_ratio, 
  collateral_id,
  sender, 
  collateral_amount, 
  collateral_amount_usd, 
  collateral_currency, 
  mint_amount,
  mint_amount_usd, 
  mint_currency, 
  return_amount,
  return_amount_usd, 
  return_currency, 
  locked_amount,
  locked_amount_usd,
  locked_currency,
  tax,
  commission,
  spread,
  unlock_time,
  contract_address, 
  contract_label 
FROM msgs m 

JOIN events e 
  ON m.tx_id = e.tx_id
