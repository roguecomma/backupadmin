::AppConfig.ec2 = YAML::load(IO.read("config/amazon_ec2.yml"))[Rails.env.to_s]

AWS = Fog::Compute.new(
  :provider => 'AWS',
  :aws_access_key_id => AppConfig.ec2['access_key_id'],
  :aws_secret_access_key => AppConfig.ec2['secret_access_key']
)