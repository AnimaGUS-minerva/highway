class SystemVariable < ActiveRecord::Base

  @@cache = Hash.new

  def self.lookup(thing)
    self.find_by_variable(thing.to_s)
  end

  def self.findormake(thing)
    v = self.lookup(thing)
    if v.nil?
      v = self.new
      v.variable = thing.to_s
    end
    v
  end

  def self.boolvalue?(thing)
    v = self.lookup(thing)
    return false if v.nil?
    return (v.number != 0)
  end

  def self.boolcache?(thing)
    @@cache[thing] ||= boolvalue?(thing)
  end

  def self.setnumber(thing, value)
    v = self.findormake(thing)
    v.number = value
    v.save
  end

  def self.nextval(thing)
    v = self.findormake(thing)
    if v.number.nil?
      v.number = 1
    end
    v.nextval
  end

  def self.get_uid
    return self.nextval(:unix_id)
  end

  def after_save
    @@cache.delete(self.variable)
  end

  def nextval
    n = nil
    begin
      transaction do
        n = self.number
        m = n + 1
        self.number = m
        self.save
      end
    #rescue ActiveRecord::Rollback
    #  logger.err "failed to get nextval for #{variable}"
    end
    n
  end

  def elidedvalue
    if value.blank?
      ""
    elsif value.length > 15
      value[0..7] + ".." + value[-7..-1]
    else
      value
    end
  end


end