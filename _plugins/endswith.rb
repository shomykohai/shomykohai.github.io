# FROM: https://stackoverflow.com/questions/37022432/how-can-i-check-if-a-string-ends-with-a-particular-substring-in-liquid

module Jekyll
    module StringFilter
     def endswith(text, query)
       return text.end_with? query
     end
   end
 end
   
 Liquid::Template.register_filter(Jekyll::StringFilter)
