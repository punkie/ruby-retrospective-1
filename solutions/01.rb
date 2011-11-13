class Array 
  def to_hash
    hash = {}
    self.each { |arr_elem| hash[arr_elem.first] = arr_elem.at(1) } 
    hash 
  end
  
  def index_by
    hash = {}
    self.each { |arr_elem| hash[yield(arr_elem)] = arr_elem  }
    hash
  end  
  
  def subarray_count(subarray)
    each_cons(subarray.length).count(subarray)
  end
  
  def occurences_count
    hash = Hash.new(0)
    self.each { |elem| hash[elem] += 1 }
    hash
  end
end