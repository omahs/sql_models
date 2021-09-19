{{ 
  config(
    materialized='incremental',
    unique_key='chain_id || block_id || tx_id || msg_index || event_index', 
    incremental_strategy='delete+insert',
    tags=['snowflake', 'terra_silver', 'terra_msg_events']
  )
}}

with base_tables as (
  select *
  from {{source('bronze', 'prod_terra_sink_645110886')}}
  where record_content:model:name::string = 'terra_msg_event_model'
  {% if is_incremental() %}
        AND (record_metadata:CreateTime::int/1000)::timestamp::date >= (select dateadd('day',-1,max(system_created_at::date)) from {{source('terra_dbt', 'msg_events')}})
  {% endif %}
  )

select (record_metadata:CreateTime::int/1000)::timestamp as system_created_at,
      t.value:blockchain::string as blockchain,
      t.value:block_id::bigint as block_id,
      t.value:block_timestamp::timestamp as block_timestamp,
      t.value:chain_id::string as chain_id,
      t.value:tx_id::string as tx_id,
      t.value:tx_module::string as tx_module,
      t.value:tx_status::string as tx_status,
      t.value:tx_type::string as tx_type,
      t.value:msg_index::integer as msg_index,
      t.value:msg_type::string as msg_type,
      t.value:msg_module::string as msg_module,
      t.value:event_type::string as event_type,
      t.value:event_index::integer as event_index,
      t.value:event_attributes::object as event_attributes
from base_tables
,lateral flatten(input => record_content:results) t