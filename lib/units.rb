#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 2008-08-07.
#  Copyright (c) 2008. All rights reserved.

module Units
  CONVERSION_FACTORS = {
    :mm => 10.0,
    :cm => 1.0,
    :m => 0.1
  }

  def enunit( value, power=1, usys=$manager.unit_system )
    power.times{ value *= CONVERSION_FACTORS[usys.to_sym] }
    value.to_s + usys.to_s + (power > 1 ? power.to_s : '')
  end

  def ununit( value, power=1, usys=$manager.unit_system )
    power.times{ value /= CONVERSION_FACTORS[usys.to_sym] }
    value
  end
end
