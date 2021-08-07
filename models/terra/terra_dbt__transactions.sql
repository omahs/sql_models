{{ 
  config(
    materialized='incremental',
    unique_key='chain_id || block_id || tx_id', 
    incremental_strategy='delete+insert',
    tags=['snowflake', 'terra_silver_2', 'terra_transactions']
  )
}}

with base_tables as (
  select *
  from {{source('bronze', 'prod_terra_sink_645110886')}}
  where record_content:model:name::string = 'terra_tx_model'
  {% if is_incremental() %}
        AND (record_metadata:CreateTime::int/1000)::timestamp >= (select max(system_created_at) from {{source('terra_dbt', 'transactions')}})
  {% endif %}
  )

select (record_metadata:CreateTime::int/1000)::timestamp as system_created_at,
      t.value:blockchain::string as blockchain,
      t.value:block_id::bigint as block_id,
      t.value:block_timestamp::timestamp as block_timestamp,
      t.value:chain_id::string as chain_id,
      t.value:codespace::string as codespace,
      t.value:tx_id::string as tx_id,
      t.value:tx_type::string as tx_type,
      t.value:tx_module::string as tx_module,
      t.value:tx_status::string as tx_status,
      t.value:tx_status_msg::string as tx_status_msg,
      t.value:tx_code::integer as tx_code,
      t.value:fee::array as fee,
      t.value:gas_wanted::double as gas_wanted,
      t.value:gas_used::double as gas_used
from base_tables
,lateral flatten(input => record_content:results) t