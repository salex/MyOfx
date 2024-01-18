class MyOfx

  attr_accessor :account
  attr_accessor :transactions
  attr_accessor :node

  def initialize(ofx)
    @ofx = ofx 
    @xml = ofx_to_xml
    @node = Nokogiri::HTML(@xml)
    build_transactions
    build_account(node)
  end

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

  def build_transactions
    @transactions = []
    @node.xpath('//banktranlist//stmttrn').collect do |element|
      @transactions << self.build_transaction(element)
    end
  end

  def build_transaction(element)
    trans = {
       amount: build_amount(element),
       amount_in_pennies: (build_amount(element) * 100).to_i,
       fit_id: (element.search('fitid').text),
       memo: (element.search('memo').text),
       name: (element.search('name').text),
       payee: element.search('payee').text,
       check_number: (element.search('checknum').text),
       ref_number: (element.search('refnum').text),
       posted_at: build_date(element.search('dtposted').text),
       # occurred_at: occurred_at,
       # type: build_type(element),
       sic: (element.search('sic').text)
     }
     return trans
  end

  def build_amount(element)
    element.search('trnamt').text.to_f
  end

  def build_date(date)
    # for rails it's only to_time
    date.to_time
    # tz_pattern = /(?:\[([+-]?\d{1,4}):\S{3}\])?\z/
    # # Timezone offset handling
    # date.sub!(tz_pattern, '')
    # offset = Regexp.last_match(1)

    # if offset
    #   # Offset padding
    #   _, hours, mins = *offset.match(/\A([+-]?\d{1,2})(\d{0,2})?\z/)
    #   offset = format('%+03d%02d', hours.to_i, mins.to_i)
    # else
    #   offset = '+0000'
    # end

    # date << " #{offset}"
    # Time.parse(date)

  end

  def build_account(node)
    account_types = {
      'CHECKING' => :checking,
      'SAVINGS' => :savings,
      'CREDITLINE' => :creditline,
      'MONEYMRKT' => :moneymrkt
    }.freeze

    @account = {
      bank_id: node.search('bankacctfrom > bankid').inner_text,
      id: node.search('bankacctfrom > acctid, ccacctfrom > acctid').inner_text,
      type: account_types[node.search('bankacctfrom > accttype').inner_text.to_s.upcase],
      balance: build_balance(node),
      available_balance: build_available_balance(node),
      currency: node.search('stmtrs > curdef, ccstmtrs > curdef').inner_text,
      transactions: @transactions
    }
  end

  def build_balance(node)
    amount = to_decimal(node.search('ledgerbal > balamt').inner_text)
    posted_at = begin
      build_date(node.search('ledgerbal > dtasof').inner_text)
    rescue StandardError
      nil
    end
    balance = {
     amount: amount,
     amount_in_pennies: (amount * 100).to_i,
     posted_at: posted_at
    }
  end

  def build_available_balance(node)
    if node.search('availbal').size > 0
      amount = to_decimal(node.search('availbal > balamt').inner_text)
      available_balance = {
        amount: amount,
        amount_in_pennies: (amount * 100).to_i,
        posted_at: build_date(node.search('availbal > dtasof').inner_text)
      }
    end
  end

  def to_decimal(amount)
    BigDecimal(amount.to_s.gsub(',', '.'))
  rescue ArgumentError
    BigDecimal('0.0')
  end

end
