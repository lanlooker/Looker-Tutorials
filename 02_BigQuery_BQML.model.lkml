# Adapted from https://github.com/GoogleCloudPlatform/training-data-analyst/blob/master/courses/bdml_fundamentals/demos/bqml-classification-model.sql

connection: "XYZ"

explore: full_data {
  label: "Data and Prediction"
  join: model_prediction {
    relationship: one_to_one
    type: inner
    sql_on: ${model_prediction.fullVisitorId} = ${full_data.fullvisitorid} ;;
  }
}


view: full_data {
  derived_table:{
    sql: WITH first_time_visitor as (SELECT
          fullVisitorId,
          date,
          IFNULL(totals.bounces, 0) AS bounces,
          IFNULL(totals.timeOnSite, 0) AS time_on_site
        FROM
          `data-to-insights.ecommerce.web_analytics`
        WHERE
          totals.newVisits = 1)
       SELECT * FROM first_time_visitor
       JOIN (SELECT
          fullvisitorid,
          IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
        FROM
            `data-to-insights.ecommerce.web_analytics`
        GROUP BY fullvisitorid)
        USING (fullVisitorId);;
  }

  dimension: fullvisitorid {}
  dimension: will_buy_on_return_visit {
    label: "Did buy on returning visit"
  }
  dimension: bounces {type:number}
  dimension: time_on_site {type:number}
}

view: training_input {
  derived_table: {
    sql: SELECT * FROM ${full_data.SQL_TABLE_NAME} WHERE date BETWEEN '20160801' AND '20170430';;
  }
}

view: testing_input {
  derived_table: {
    sql: SELECT * FROM ${full_data.SQL_TABLE_NAME} WHERE date BETWEEN '20170501' AND '20170630' ;;
  }
}

view: future_purchase_model {
  derived_table: {
    persist_for: "24 hours" # need to have persistence
    sql_create:
      CREATE OR REPLACE MODEL ${SQL_TABLE_NAME}
      OPTIONS(model_type='logistic_reg'
        , labels=['will_buy_on_return_visit']
        , min_rel_progress = 0.005
        , max_iterations = 40
        ) AS
      SELECT
         * EXCEPT(fullVisitorId)
      FROM ${training_input.SQL_TABLE_NAME};;
  }
}

explore: model_evaluation {}

view: model_evaluation {
  derived_table: {
    sql: SELECT roc_auc,
        CASE
          WHEN roc_auc > .9 THEN 'good'
          WHEN roc_auc > .8 THEN 'fair'
          WHEN roc_auc > .7 THEN 'decent'
          WHEN roc_auc > .6 THEN 'not great'
          ELSE 'poor' END AS model_quality,
          log_loss
          FROM ML.EVALUATE(MODEL ${future_purchase_model.SQL_TABLE_NAME},(SELECT * FROM ${testing_input.SQL_TABLE_NAME})) ;;
  }
  dimension: model_quality {}
}


view: model_prediction {
  derived_table: {
    sql: SELECT * FROM ml.PREDICT(
          MODEL ${future_purchase_model.SQL_TABLE_NAME},
          (SELECT * FROM ${full_data.SQL_TABLE_NAME}));;
  }

  dimension: predicted_will_buy_on_return_visit {type:number}
  dimension: fullVisitorId {
    type: number
    hidden:yes}

}
