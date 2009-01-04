#!/usr/bin/env ruby
#
#  Created by Philip Silva on 2.1.2009.
#  Copyright (c) 2009. All rights reserved.

require 'narray'
include NMath # ! (i<->j) in NMatrix
require 'test/unit/assertions.rb'
include Test::Unit::Assertions

class NVector
  def to_s
    output_str = "["
    for i in 0...self.total
      output_str += self[i].to_s
      output_str += ", " if i < self.total - 1
    end
    output_str += "]"
  end
end


class NMatrix
  def fill_by f # ok
    for i in 0...sqrt(self.size)
      for j in 0...sqrt(self.size)
  self[i,j] = f[j,i] # sic!
      end
    end
  end

  
  def det
    sum = 0.0
    n = sqrt(self.size)
    if n == 1
      return self[0,0]
    elsif n == 2
      return self[0,0]*self[1,1] - self[1,0]*self[0,1]
    else
      i = n - 1
      for j in 0...n
  if self[j,i] != 0
    sum += ((-1)**(i+j)) * self[j,i] * remove_cross(i, j).det # sic!
  end
      end
      return sum
    end
  end

  # row, col
  def remove_cross(i,j)
    n = sqrt(self.size)
    m = NMatrix.new(Float, n-1, n-1)

    for a in 0...n
      for b in 0...n
  k = a
  l = b
  if a >= i
    k -= 1
  end
  if b >= j
    l -= 1
  end
  if a != i or b != j
    m[k,l] = self[a,b] # sic!?
  end
      end
    end
    m
  end
  
  def to_s
    n = sqrt size
    str = ""
    for i in 0...n
      str += "["
      for j in 0...n
  str += "#{self[j,i]}, "
      end
      str += "]\n"
    end
    return str
  end
end