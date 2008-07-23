#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 17.7.2008.
#  Copyright (c) 2008. All rights reserved.



###------------ Topicalization ------------###

class Module
	def _topicalize_ *meths
		for meth in meths
			class_eval "
				alias __#{meth} #{meth}
				def #{meth}
					self.__#{meth} do |arg|
						$_2 = arg if $_1
						$_1 = arg if $_1.nil?
						$__ = [$_1, $_2].compact.last
						return_value = yield *arg
						$_1 = nil if $_2.nil?
						$_2 = nil
						$__ = [$_1, $_2].compact.last
						return_value
					end
				end
			"
		end
	end
end

def given o
	$__ = o
	yield
end

class Array
	_topicalize_ *%w(each map select sort_by any? all?)
end

class Range
	_topicalize_ *%w(each map select sort_by any? all?)
end

class Integer
	_topicalize_ *%w(times step upto downto)
end




###------------ Hyper and reduction operators ------------###

module Enumerable
	def _ op, enum=nil
		if enum
			zip(enum).map{|i,j| i && j ? eval("#{i}.#{op} #{j}") : nil }.compact
		else
			eval "inject{|a,b| a.#{op} b }"
		end
	end
end




###------------ Junctions ------------###

class Junction
	attr_reader :operator, :objects
	def initialize( operator, *objs )
		@operator = operator
		@objects = objs
	end
	
	def & o
		raise "You cannot mix junction types" if @operator == :or or (o.is_a?(Junction) and o.operator != @operator)
		@objects << (o.is_a?(Junction) ? o.objects : o)
		@objects.flatten!
		self
	end
	
	def | o
		raise "You cannot mix junction types" if @operator == :and or (o.is_a?(Junction) and o.operator != @operator)
		@objects << (o.is_a?(Junction) ? o.objects : o)
		@objects.flatten!
		self
	end
	
	def method_missing( meth, *args )
		Junction.define_operator meth
		send meth, *args
	end
	
	# XXX define as method_missing
	def Junction.define_operator op
		class_eval "
			def #{op}( arg, direction=:normal )
				if arg.is_a? Junction
					case @operator
					when :and
						@objects.all?{ $__.#{op} arg }
					when :or
						@objects.any?{ $__.#{op} arg }
					end
				else
					value = (@operator == :and) 
					for obj in @objects
						case @operator
						when :and
							if direction == :normal
								value = (value and (obj.#{op} arg))
							else
								value = (value and (arg.#{op} obj))
							end
						when :or
							if direction == :normal
								value = (value or (obj.#{op} arg))
							else
								value = (value or (arg.#{op} obj))
							end
							return value if value
						end
					end
					return value
				end
			end
		"
	end
	define_operator "=="
	define_operator "<"
	define_operator ">"

	def each
		threads = []
		@objects.each do |o|
			threads << Thread.start{ yield o }
		end
		threads.each{|t| t.join }
		self
	end
	_topicalize_ 'each'
	
	def to_s
		"Junction: " + @objects.join(" #{@operator.to_s} ")
	end
end


class Module
	def _junctionize_ meths=nil
		class_eval "
		def & o
			Junction.new( :and, self, o )
		end

		def | o
			Junction.new( :or, self, o )
		end
		"
		suitable_methods = meths || %w(== < > <= >=)
		methods = public_instance_methods & suitable_methods
		#module_methods = public_methods & suitable_methods
		methods.each{ define_junction_method $__ }
		#module_methods.each{ define_junction_method( $__, :class ) }
	end
			
	def define_junction_method( meth, type=:instance )
		unless ["__id__", "__send__"].any?{ $__ == meth }
			# convert operators to their ascii value for aliasing
			internal = '__' + meth.gsub(/[~@^+-=>*<%&|\[\]]/){ $~[0][0].to_s }
			class_eval "
			alias :___#{internal} :#{meth}
			def #{(type == :class) ? 'self.' : ''}#{meth} o
				if o.is_a? Junction
					o.#{meth}( self, :inverse )
				else
					#{type == :class ? (self.class.to_s + '::') : 'self.'}___#{internal} o
				end
			end
			"
		end
	end
end

def all( *objs, &block )
	j = Junction.new( :and, *objs )
	j.each{|o| yield o } if block_given?
	j
end

def any( *objs, &block )
	j = Junction.new( :or, *objs )
	j.each{|o| yield o }  if block_given?
	j
end

class Fixnum
	_junctionize_
end

class Bignum
	_junctionize_
end

class Float
	_junctionize_
end

class String
	_junctionize_
end

	

	


 
