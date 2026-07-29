# Pry defaults for the image user (loaded when pry is available).
if defined?(Pry)
  Pry.config.history_file = File.join(Dir.home, ".pry_history")
end
