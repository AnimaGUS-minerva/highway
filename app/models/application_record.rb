class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def logger
    Rails.logger
  end
end
