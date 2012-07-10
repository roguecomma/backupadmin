AWS = Fog::Compute.new(
  :provider => 'AWS',
  :aws_access_key_id => ENV['AWS_ACCESS_KEY'] || raise("AWS_ACCESS_KEY must be set in environment"),
  :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'] || raise("AWS_SECRET_ACCESS_KEY must be set in environment")
)