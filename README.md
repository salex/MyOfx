# MyOfx
A small replacement of the OFX gem that is not maintained

I've been using a gem [OFX](https://github.com/annacruz/ofx/tree/main) for years. Its purpose is to parse a OFX (open file exchange) file into a structure. Most banks will have some method to download a current version that contains all you bank transactions for some period. But there are different versions!

The OFX gem has not been well maintained and is probably over 10 years old. It will not work in rails 7.1 because the version of nokogiri is too old. 

Since they won't fix it I took a stab and writing a class to replace what I needed.

OFX uses a file format SGML. Looks a little like HTML or XML, but it not. The major difference is it has attribute like tags that are not closed. e.g.

```html
           <BANKTRANLIST>
               <DTSTART>20230901000000.000[-5:CDT]
               <DTEND>20230930235959.000[-5:CDT]
               <STMTTRN>
                  <TRNTYPE>CREDIT
                  <DTPOSTED>20230929000000.000
                  <TRNAMT>0.68
                  <FITID>79371680
                  <NAME>INTEREST PAID
                  <MEMO>Deposit INTEREST PAID
               </STMTTRN>
```

The gem use nokogiri to parse the file. The open tags are a little problem in that each tag in the <STMTTRN> node is a child of the previous tag. You can get around it but - What if I converted to file to XML! The format is well structured. All open/close tags are on seperate lines.  If I close the *attribute* tags I'd have and XML format!


* I just spilt the file into lines
* Split each line on the closing '>' character. 
* If the split has 2 elements, it's an attribute tag
* Add the > back to the first element, create a closing tag
* Wrap the contents in the tags and you have XML

```ruby
 def ofx_to_xml
    xml = ""
    ofx_arr = @ofx.split("\r\n")
    ofx_arr.each do |elm|
      elm_arr = elm.split(">")
      if elm_arr.size != 2
        xml += (elm + "\r\n")
        next 
      end
      elm_arr[0] += '>' # add back > that split removed
      otag = elm_arr[0].strip
      ctag = otag[0]+'/' + otag[1..-1] # build closing tag
      line = elm_arr[0]+elm_arr[1]+ctag
      xml += (line + "\r\n")
    end
    xml
  end
```

Now you can parse the HTML/XML  using nokogiri into some kind structure. Even found this little gem that converts a Hash into an open struct and stuck it into initializers.

```ruby
class Hash
  def to_o
    JSON.parse to_json, object_class: OpenStruct
  end
end
```

The rest of the code is from the OFX gem and modified a little. It does give me an array of transactions which is all that I really need.

Just stuck the file here so I could share it and post something in the OFX issues.

