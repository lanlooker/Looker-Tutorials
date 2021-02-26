# Last update: Nov 4, 2020.
# Dev by Lan. Please send comments and feedback to lantrann@



connection: "XYZ"

############################################################################
#Exercise 1: UNNEST AN ARRAY


explore: base_table {

  join: fruit {
    sql: LEFT JOIN UNNEST(example.fruit) as fruit;;
    relationship: one_to_many
  }
}

view: base_table {
  derived_table: {
    sql: SELECT STRUCT("Rudisha" as name, ["Apple", "Banana", "Orange"] as fruit) as example;;
  }
  dimension: name {
    sql: ${TABLE}.example.name ;;
  }
 }

view: fruit {
  dimension: fruit {
    label: "Fruit Unnested"
    sql: ${TABLE} ;;
  }
}

############################################################################
# Exercise 2: UNNEST REPEATED RECORDS

explore: main {
  label: "Nested Data BQ"

  #Repeated object - level 1
  join: main_hits {
    sql:LEFT JOIN UNNEST(main.hits) as main_hits  ;;
    relationship: one_to_many
  }

  #Repeated object - level 2
  join: main_hits_product {
    #use liquid_in_condition here to manipulate levels of unnest
    sql:{% if main_hits.referer._in_query %}
        LEFT JOIN UNNEST (main_hits.product) as main_hits_product
        {% else %}
        LEFT JOIN UNNEST(main.hits) as main_hits LEFT JOIN UNNEST (main_hits.product) as main_hits_product
        {% endif %} ;;
    relationship: one_to_many
  }

}

view: main {

  sql_table_name: `bigquery-public-data.google_analytics_sample.ga_sessions_20170801` ;;


  dimension: visitId {
    type: number
    primary_key: yes
  }

  dimension_group: date {
    type: time
    timeframes: [date,month,quarter,year]
    sql: TIMESTAMP(PARSE_DATE("%Y%m%d", date));;
  }

  ###########################
  # Non repeated record "Continent"

  dimension: Continent {
    sql: ${TABLE}.geoNetwork.continent ;;
  }

  dimension: Country {
    sql: ${TABLE}.geoNetwork.country ;;
  }

  ###########################
  # Non repeated record "Device"

  dimension: browser {
    sql: ${TABLE}.device.browser ;;
  }

  dimension: language {
    sql: ${TABLE}.device.language ;;
  }
  #########################

  ### Repeated record "Hits"
  dimension: hits {
    label: "hits JSON"
    hidden: yes
  }

  #########################

  measure: totals_transactions {
    type: sum
    sql: ${TABLE}.totals.transactions ;;
  }

  measure: count {
    type: count
  }

}


#############################

# Level 1 UNNEST
view: main_hits {
  label: "Main > Hits"

  dimension: pk {
    primary_key: yes
    hidden: yes
    sql: CONCAT(main.visitID, main_hits.referer) ;;
  }

  dimension: referer{}

  dimension: refere_social {
    label: "Social Referer"
    sql:  CASE WHEN ${TABLE}.referer LIKE '%google%' THEN 'Google'
          WHEN ${TABLE}.referer LIKE '%youtube%' THEN 'Youtube'
          WHEN ${TABLE}.referer LIKE '%facebook%' THEN 'Facebook'
          WHEN ${TABLE}.referer LIKE '%twitter%' THEN 'Twitter'
          WHEN ${TABLE}.referer LIKE '%baidu%' THEN 'Baidu'
          ELSE 'Other'
          END ;;
  }

  dimension: isexit {
    label: "Exit"
    type: yesno
  }

  measure: count {
    type: count
  }
}

# Level 2 UNNEST

view: main_hits_product {
  label: "Main > Hits > Product"
  dimension: pk  {
    primary_key: yes
    hidden: yes
    sql:CONCAT(main.visitID, main_hits_product.productSKU);;
  }

  dimension: productSKU {
    label: "SKU"
  }

  dimension: v2ProductCategory {
    label: "Category"
  }

  dimension: productPrice {
    label: "Price"
    type: number
  }

  measure: count {
    type: count
  }
}
