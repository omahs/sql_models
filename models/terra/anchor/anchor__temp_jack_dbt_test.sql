{{
  config(
    materialized='table',
    tags=['test']
  )
}}

with
deposits as (

  select * from {{ ref('anchor__deposits') }}

)

select * from deposits
limit 10
