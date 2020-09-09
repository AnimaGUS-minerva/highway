require 'rails_helper'

RSpec.describe Sqrl do

  describe "building data records" do
    it "should add a URL" do
      s = Sqrl.new
      s.company_name = "ACME Corporation"
      s.product_name = "widget"
      s.model_name   = "fixit"
      s.mud_url      = "http://acme.example/widget/fixit.json"

      expect(s.sqrl_string.unpack("H*").first).to eq("5b293e1e30361d31324e4230303041434d4520436f72706f726174696f6e1f423030317769646765741f4230303266697869741f55303837687474703a2f2f61636d652e6578616d706c652f7769646765742f66697869742e6a736f6e1f1e04")

      # the result is actually rather printable, with a few magic characters
      expect(s.sqrl_string).to eq("[)>\u001E06\u001D12NB000ACME Corporation\u001FB001widget\u001FB002fixit\u001FU087http://acme.example/widget/fixit.json\u001F\u001E\u0004")
    end
  end

end
