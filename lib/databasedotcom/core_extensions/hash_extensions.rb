class Hash
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  def deep_symbolize_keys!
    keys.each do |key|
      value = self[(key.to_sym rescue key) || key] = delete(key)
      value.deep_symbolize_keys! if value.is_a?(Hash)
    end
    self
  end
end
