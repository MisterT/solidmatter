#!/usr/bin/env ruby
#  Created by Björn Breitgoff and Philip Silva on 19.12.2008.
#  Copyright (c) 2008. All rights reserved.

=begin
TODO:
* support an den Start bringen
* einheitliche indizierung (1..n vs. 0...n) ODER indexfreie notation

OPTIM:
* grammatrizen cachen
* threading
* 23 sec. (jetzt 26 sec.) für n=50 (max. fehler bei 2,0%)
* max. 4,3% fehler bei n=20 & 3 sec. (noch immer 3 sec)
* max. 7,9% fehler bei n=12 & 1 sec.
=end

require 'narray_extensions.rb'
require 'test/unit/assertions.rb'
include Test::Unit::Assertions

Force = Struct.new( :origin, :direction )

class FEMSolver
  def initialize( part, forces )
    @mesh = part.tesselate
    @forces = forces
  end
  
  def neighboors point
    @cache ||= {}
    unless @cache[point]
      #checked = []
      #my_tris = @mesh.select{|t| t.include? point }
      #@cache[point] = my_tris.flatten.uniq - [point]
      @mesh.flatten.sort_by{|p| p.distance_to point }
    end
    @cache[p]
  end
  
  def solve samples
    samples.times do
      
    end
  end
end

class NSet
  def initialize r
    @ranges = []
    @ranges[0] = r
  end

  def + r
    non_dj_sets = []
    @ranges.each do |x|
      unless j.disjoint? r
	non_dj_sets << r
	r = nil
	non_dj_sets.compact!
      end
    end
    
    non_dj_sets.each {|x| x.join_with r}
    while non_dj_sets.size > 0
      if non_dj_sets.size == 1
	@ranges << non_dj_sets[0]
	non_dj_sets = []
      else
	pivot = non_dj_sets[0]
	found_ndj = false
	ndj_idx = nil
	for i in 1...non_dj_sets.size
	  unless non_dj_sets[i].disjoint? pivot
	    found_ndj = true
	    ndj_idx = i
	  end
	end
	@ranges << pivot
	if found_ndj
	  non_dj_sets[ndj_idx] = non_dj_sets[ndj_idx].join_with pivot
	end
	non_dj_sets[0] = nil
	non_dj_sets.compact!
      end
    end
  end
  
  # Sortierung würdes optimieren...
  def include? x
    found = false
    @ranges.each do |r|
      if r.include? x
	found = true
	break
      end
    end
    return found
  end
  
  # Sortierung...
  # returns array of ranges; no guarantee that ranges have same size; #partitions >= n
  def partition n
    length = 0.0
    @ranges.each{|r| length += (r.last - r.first).abs }
    delta_x = length / Float(n)
    raise "bla"
  end
end



$h = 0.000001

class Range
  def disjoint?
    assert first < last and r.first < r.last
    last < r.first or r.last < first
  end

  def join_with r
    assert first < last
    assert r.first < r.last
    if disjoint? r
      return self, r
    else
      return [first,r.first].min..[last,r.last].max
    end
  end
end


class L2Vector
  attr_reader :domain, :support # make this read_only!
  
  def initialize(func, domain, support=domain)
    @func = func
    @domain = domain
    @support = support
  end
  
  # !!! this is the representation of Proc as step-wise function
  def discretize n
    delta_x = (domain.last - domain.first)/Float(n-1)
    v = NVector.new(Float, n)
    for i in 0...n
      v[i] = @func[domain.first + i*delta_x]
    end
    return v
  end

  # note that you might just want to integrate over a subdomain
  def integrate(domain=@domain, n=10) # ! in general other n than in Basis
    dx = (domain.last - domain.first) / Float(n)
    integral = 0.0
    for  i in 0...n
      left = @func[domain.first + i*dx]
      right = @func[domain.first + (i+1)*dx]
      integral += (left + right)*dx/2
    end
    return integral
  end
  
  def [] x
    @func[x]
  end
  
  def multiply(g, n=40, subdomain=nil)
    if subdomain==nil
      assert @domain == g.domain
      L2Vector.new(lambda{|x| @func[x]*g[x]}, @domain).integrate(@domain, n)
    else # this sucks!!!!!!!!!!!!!!!
      L2Vector.new(lambda{|x| @func[x]*g[x]}, subdomain).integrate(subdomain, n)
    end
  end
  
  def norm
    sqrt(multiply(@func,10,@support))
  end
  
  # check_domain: specifies where the function is well-defined
  def diff(check_domain=@domain, h = $h)
    assert @domain != nil
      
    g = lambda{|x|
      if check_domain.include? x-h and check_domain.include? x+h
	(@func[x+h] - @func[x-h]) / (2*h)
      elsif check_domain.include? x and check_domain.include? x+h
	# nur rechtsseitige Ableitung - ggf. noch verfeinern (h adaptiv verändern)
	(@func[x+h] - @func[x]) / h
      elsif check_domain.include? x-h and check_domain.include? x
	# nur linksseitige
	(@func[x] - @func[x-h]) / h
      else
	raise "function is not differentiable at x=#{x}"
      end
    }
    return L2Vector.new(g, @domain)
  end
  
  def * c
    if c.kind_of? Numeric
      return L2Vector.new(lambda{|x| @func[x] * c}, @domain)
    elsif c.kind_of? L2Vector
      return multiply(c,$n,support)
    end
  end
  
  # yields the array of coefficents of @func written in terms of base
  def coeffs_wrt base
    c = NVector.new(Float, base.n)
    for i in 0...base.n
      c[i] = self * base[i+1]
    end
    return c
  end  
end


class Basis # seems ok
  attr_reader :n

def initialize(domain, n = 10)
    @n = n
    @x = []
    for i in 0..n+1
      a = domain.first
      b = domain.last
      @x[i] = a + (b - a) * Float(i)/Float(n+1)
      @delta_x = (b - a) / Float(n+1)
    end
    @domain = domain
  end

  # tent function
  def [] k   # k = 1..n
    assert 1 <= k and k <= @n
    return L2Vector.new( lambda{|x|
      if @x[k-1] <= x and x <= @x[k]
	 sqrt(@n+1) / @delta_x * (x - @x[k-1]).abs # / ((@x[k] - @x[k-1]))
      elsif @x[k] <= x and x <= @x[k+1]
	 sqrt(@n+1) / @delta_x * (@x[k+1] - x).abs # / ((@x[k+1] - @x[k]))
      else
	0
      end
    }, @domain, @x[k-1]..@x[k+1])
  end
  
  def build_func_with c
    L2Vector.new( lambda{|x|
      sum = 0.0
      for i in 0...@n
	sum += c[i] * self[i+1][x]
      end
      sum
    }, @domain)
  end
end


class Object2D
  attr_reader :x, :y
  
  def initialize(x, y)
    @x = x
    @y = y
  end
  
  def include? a
    if x.include? a.x and y.include? a.y
      true
    else
      false
    end
  end
end

# WITHOUT(!!!!!!!!!!!) domain check
def dir_deriv f, dir
  
end

def grad f
#  dir_deriv(f, $e_x) + dir_deriv(f, $e_y)
end

class Basis2D
  def initialize(domain, n = 10)
    @base = Object2D.new(Basis.new(domain.x, n), Basis.new(domain.y, n))
  end
  
  def x
    return @base.x
  end
  
  def y
    return @base.y
  end
  
  def [] k
    return Object2D.new(base.x[k], base.y[k])
  end
  
  def build_func_with c
    raise "fuck you"
  end
end

# characteristic function
def chi (support, domain=support)
#  assert support.begin <= support.end
  L2Vector.new( lambda {|x| 
    if support.include? x
      1
    else
      0
    end
  }, domain, support) # !!!!!!!!!!!!!!!!!!! change this shit
end


def solve_laplace1D n, v, f
  mat_L = NMatrix.new(Float,n,n)
  mat_L.fill_by lambda{|i,j| v[i+1].diff*v[j+1].diff}
  mat_M = NMatrix.new(Float,n,n)
  mat_M.fill_by lambda{|i,j| v[i+1]*v[j+1]}
  g = f.coeffs_wrt(v)*mat_M
  # now we have: -Lu = Mf = g -> solve for u
  u = mat_L.lu.solve(-g)
  v.build_func_with(u).discretize(10) # = u_disc
end


def test_1D
  puts "1D laplace-solver..."
  domain = 0..1
  n = 50
  $n = 2*n
  v = Basis.new(domain, n)
  #f = chi(0.2..0.4)
  f = chi(domain, domain) # Normierungen checken!!

#  puts "u=#{u}"
  u_disc = solve_laplace1D n, v, f
  puts "expected:"
  for i in 0...10
    xx = Float(i)/9.0
    soll = 0.5*(xx**2 - xx)
    berechn = u_disc[i]
    puts "u(#{xx})=#{soll}\t\t  #{berechn}\t\trel_err=#{(soll-berechn)/soll*100}%"
  end
=begin puts "norms:"
  for j in 1..n
  puts "||v[#{j}]||=#{v[j].norm}"
=end
end


def test_2D
  puts "2D laplace-solver..."
  domain = Object2D.new(0..1, 0..1)
  n = 10
  $n = 10
  v = Basis2D.new(domain, n)
  f = Object2D.new(chi(domain.x, domain.x), chi(domain.y, domain.y))
  
  u_disc_x = solve_laplace1D n, v.x, f.x
  u_disc_y = solve_laplace1D n, v.y, f.y
  puts "result: (#{u_disc_x}, #{u_disc_y})"
end

#test_2D
test_1D


