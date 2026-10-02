class Risk
  def tier(score)
    return :low if score <= 25
    return :medium if score < 75

    :high
  end
end
