class Checkout
  def shipping(cents)
    cents >= 5_000 ? :free : :standard
  end
end
