# IRB defaults for the image user.
require "irb/completion" if defined?(IRB)

if defined?(IRB)
  IRB.conf[:SAVE_HISTORY] = 1000
  IRB.conf[:HISTORY_FILE] = File.join(Dir.home, ".irb_history")
  IRB.conf[:USE_AUTOCOMPLETE] = true if IRB.conf.key?(:USE_AUTOCOMPLETE)
end
