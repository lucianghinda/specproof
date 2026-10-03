# frozen_string_literal: true

# Adds the requirement-backed pair missing from the baseline tests.
class GapDeliveryOptionsTest < Minitest::Test
  def test_express_delivery_with_notification
    assert_equal({ speed: :express, notification: true },
                 DeliveryOptions.new.build(expedited: true, notify: true),
                 "Requirement: notification follows notify; see requirements.md")
  end
end
