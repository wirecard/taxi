module Taxi
  class FileNotFound < IOError
  end

  # generic Taxi error
  class EngineFailure < StandardError
  end

  class AWSError < EngineFailure
  end

  class SFTPError < EngineFailure
  end
end
