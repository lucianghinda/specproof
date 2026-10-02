class Discount
  def rate(score)
    return :low if score <= 30
    return :middle if score <= 50

    :preferred
  end
end
