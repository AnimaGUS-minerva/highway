#
# this class encapsulates the encoding (and decoding) for
# for an RLA.ORG SQRL -- https://rla.org/resource/12n-documentation
#

class Sqrl
  attr_accessor :data_records

  CompanyRecord = "B000"
  ProductRecord = "B001"
  ModelRecord   = "B002"
  MUDURLRecord  = "U087"
  MacAddrRecord = "M06C"
  UnitSeparator   = [31].pack("C")  # hex 0x1f
  RecordSeparator = [30].pack("C")  # hex 0x1e
  GroupSeparator  = [29].pack("C")  # hex 0x1d
  FieldSeparator  = [28].pack("C")  # hex 0x1c
  EndOfTransmission= [4].pack("C")  # hex 0x04 aka ^D.

  def data_records
    @data_records ||= Hash.new
  end

  def company_name=(x)
    data_records[CompanyRecord] = x
  end
  def product_name=(x)
    data_records[ProductRecord] = x
  end
  def model_name=(x)
    data_records[ModelRecord] = x
  end
  def mud_url=(x)
    data_records[MUDURLRecord] = x
  end
  def macaddr=(x)
    data_records[MacAddrRecord] = x
  end

  def sqrl_string
    encode_records
  end

  private
  def data_record(x)
    (x + data_records[x] + UnitSeparator)
  end
  def encode_records
    things = []
    things << generate_preamble

    # always put this first.
    things << data_record(CompanyRecord)

    data_records.each { |key,value|
      next if key == CompanyRecord
      # build DataRecord string otherwise
      things << data_record(key)
    }
    things << generate_postfix

    # put them all together
    things.join('')
  end

  def generate_preamble
    "[)>" + RecordSeparator + "06" + GroupSeparator + "12N"
  end
  def generate_postfix
    RecordSeparator + EndOfTransmission
  end


end
