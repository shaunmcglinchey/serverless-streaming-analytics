environment_tag = "dev"
app_name = "stocks-flink-app"
app_autoscaling_enabled = true
app_parallelism = 1
app_runtime_environment = "FLINK-1_11"
app_sink_bucket = "stocks-flink-app-sink"
app_source = "./app/kinesis-analytics-app/target/stocks-flink-app-1.0.jar"
app_log_group = "/aws/kinesis-analytics/stocks"
app_log_level = "INFO"
app_log_stream = "stocks-log-stream"
lambda = "stocks"
lambda_handler = "stocks.lambda_handler"
lambda_log_group = "/aws/lambda/stocks"
kinesis_input_stream = "stocks"