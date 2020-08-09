resource "aws_budgets_budget" "overall" {
  name = "budget-overall"
  budget_type = "COST"

  limit_amount = "10.0"
  limit_unit = "USD"

  time_unit = "MONTHLY"
  time_period_start = "2020-12-01_00:00"

  cost_types {
    include_other_subscription = false
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold = 80
    threshold_type = "PERCENTAGE"
    notification_type = "FORECASTED"

    subscriber_email_addresses = ["sacha@tremoureux.fr"]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold = 100
    threshold_type = "PERCENTAGE"
    notification_type = "ACTUAL"

    subscriber_email_addresses = ["sacha@tremoureux.fr"]
  }

}
