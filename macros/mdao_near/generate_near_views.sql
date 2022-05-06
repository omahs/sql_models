{% macro generate_near_views(PREFIX) %}
    {% set sql %}
    
    CREATE OR REPLACE PROCEDURE silver.generate_near_views(PREFIX STRING)
        RETURNS STRING
        LANGUAGE JAVASCRIPT
        AS
        $$
            var PREFIX_ARR = PREFIX.split(','); 
    
            var PREFIX_LENGTH = PREFIX_ARR.length; 
            
            for (i=0; i<PREFIX_LENGTH; i++){
        
                var get_tables_name_stmt = "SELECT Table_Name FROM MDAO_NEAR.INFORMATION_SCHEMA.TABLES \
                        WHERE table_schema = 'PROD' AND TABLE_NAME LIKE UPPER('"+ PREFIX_ARR[i] + "%');"

                var get_tables_name_stmt = snowflake.createStatement({sqlText:get_tables_name_stmt });

                var tables = get_tables_name_stmt.execute();

                var create_statement = "CREATE OR REPLACE VIEW FLIPSIDE_DEV_DB.MDAO_NEAR_DYNAMIC." + PREFIX_ARR[i] +" AS \n";

                create_statement += "SELECT * FROM MDAO_NEAR.PROD." + PREFIX_ARR[i];  

                var create_view_statement = snowflake.createStatement( {sqlText: create_statement} );

                create_view_statement.execute();
            
            }

            return create_view_statement.getSqlText();
            
        $$

    {% endset %}

{% do run_query(sql) %}    

{% endmacro %}