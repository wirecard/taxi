# frozen_string_literal: true

class SessionFactory
  def initialize(aws_config, sftp_config)
    @aws_config = aws_config
    @sftp_config = sftp_config
  end

  def create_S3_session(bucket)
  end

  def create_sftp_session
  end
end
