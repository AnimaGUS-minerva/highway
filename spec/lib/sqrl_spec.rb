require 'rails_helper'

RSpec.describe Sqrl do

  describe "building data records" do
    it "should add a URL" do
      s = Sqrl.new
      s.company_name = "ACME Corporation"
      s.product_name = "widget"
      s.module_name  = "fixit"
      s.mud_url      = "http://acme.example/widget/fixit.json"

      expect(s.sqrl_string.unpack("H*")).to eq("")
    end
  end

end
