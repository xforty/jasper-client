# Logic for both of these were lifted from the rails 
# source tree. We don't call active support directly because
# we didn't want to depend on those gems merely for these
# two bits of functionality.
class String
  def underscore
    word = self.to_s.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end
  
  def humpify
    self.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
  end
end
