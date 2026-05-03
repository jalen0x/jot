class ScheduledTransactionCreationJob < ApplicationJob
  def perform
    ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.current)
  end
end
