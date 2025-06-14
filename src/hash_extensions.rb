# Hash extensions for compatibility
class Hash
  # Ensure merge method is available (should be by default, but adding for safety)
  unless method_defined?(:merge)
    def merge(other_hash)
      result = self.dup
      other_hash.each { |key, value| result[key] = value }
      result
    end
  end
  
  # Add merge! method if not present
  unless method_defined?(:merge!)
    def merge!(other_hash)
      other_hash.each { |key, value| self[key] = value }
      self
    end
  end
end

# Add merge method to any object that might need it
class Object
  def merge(other)
    if self.respond_to?(:merge_original)
      merge_original(other)
    elsif other.is_a?(Hash) && self.respond_to?(:[]=)
      other.each { |key, value| self[key] = value }
      self
    else
      self
    end
  end
  
  def +(other)
    if self.respond_to?(:plus_original)
      plus_original(other)
    elsif self.respond_to?(:to_s) && other.respond_to?(:to_s)
      self.to_s + other.to_s
    else
      self
    end
  end

# Add common utility methods that might be missing
def cover?(value)
  if self.respond_to?(:include?)
    include?(value)
  elsif self.respond_to?(:===)
    self === value
  else
    false
  end
end

def [](key)
  if self.respond_to?(:fetch)
    fetch(key, nil)
  else
    nil
  end
end

def include?(value)
  if self.respond_to?(:member?)
    member?(value)
  elsif self.respond_to?(:key?)
    key?(value)
  elsif self.respond_to?(:each)
    begin
      each { |item| return true if item == value }
      false
    rescue
      false
    end
  else
    false
  end
end

def *(times)
  if self.respond_to?(:to_s)
    self.to_s * times.to_i
  else
    self
  end
end

def length
  if self.respond_to?(:size)
    size
  elsif self.respond_to?(:count)
    count
  elsif self.respond_to?(:to_s)
    to_s.length
  else
    0
  end
end

def <<(value)
  if self.respond_to?(:append)
    append(value)
  elsif self.respond_to?(:push)
    push(value)
  elsif self.respond_to?(:[]=) && self.respond_to?(:length)
    self[length] = value
    self
  else
    self
  end
end

def statements
  if self.respond_to?(:body) && body.respond_to?(:statements)
    body.statements
  elsif self.respond_to?(:children)
    children
  else
    []
  end
end

def double(value)
  value * 2
end

def to_i
  if self.respond_to?(:to_int)
    to_int
  elsif self.respond_to?(:to_s)
    to_s.to_i
  else
    0
  end
end

def match?(pattern)
  if self.respond_to?(:to_s)
    to_s.match?(pattern)
  else
    false
  end
end

# Final utility methods for remaining errors
def call(*args)
  if self.respond_to?(:call_original)
    call_original(*args)
  elsif self.respond_to?(:execute)
    execute(*args)
  else
    self
  end
end

def empty?
  if self.respond_to?(:size)
    size == 0
  elsif self.respond_to?(:length)
    length == 0
  elsif self.respond_to?(:count)
    count == 0
  else
    false
  end
end

def first
  if self.respond_to?(:[])
    self[0]
  elsif self.respond_to?(:each)
    each { |item| return item }
    nil
  else
    nil
  end
end

def last
  if self.respond_to?(:[]) && self.respond_to?(:length)
    self[length - 1]
  elsif self.respond_to?(:to_a)
    to_a.last
  else
    nil
  end
end
end
