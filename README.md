# Client run instructions
python3 -m venv streaming_env
source streaming_env/bin/activate
pip3 install -r requirements.txt
python3 stock.py


# TODO
Add script or Terraform to package Flink app into jar file - build directory - still todo
Add TF to create Snowflake resources
Update Lambda with logic to write to Snowflake resources
Update README.md with build instructions