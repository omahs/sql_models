{{ 
  config(
    materialized='incremental', 
    sort='block_timestamp', 
    unique_key='block_id', 
    incremental_strategy='delete+insert',
    cluster_by=['block_timestamp'],
    tags=['snowflake', 'terra', 'staking']
  )
}}

SELECT 
  blockchain,
  chain_id,
  tx_status,
  block_id,
  block_timestamp, 
  tx_id, 
  tx_type,
  msg_module,
  msg_type, 
  msg_index,
  event_type,
  event_attributes,
  event_attributes:validator::string AS validator,
  CASE WHEN event_type = 'delegate' THEN event_attributes:amount ELSE NULL END AS delegated_amount,
  event_attributes:"0_sender"::string AS "0_sender",
  event_attributes:"1_sender"::string AS "1_sender",
  event_attributes:action::string AS action,
  event_attributes:module::string AS module,
  CASE WHEN event_type = 'transfer' THEN event_attributes:amount:amount ELSE NULL END AS event_transfer_amount,
  CASE WHEN event_type = 'transfer' THEN event_attributes:amount:denom::string ELSE NULL END AS event_transfer_currency,
  event_attributes:sender::string AS sender,
  event_attributes:recipient::string AS recipient
FROM {{source('silver_terra', 'msg_events')}}
WHERE msg_module = 'staking' 
  AND msg_type = 'staking/MsgDelegate'

{% if is_incremental() %}
 AND block_timestamp >= getdate() - interval '1 days'
{% else %}
 AND block_timestamp >= getdate() - interval '9 months'
{% endif %}
