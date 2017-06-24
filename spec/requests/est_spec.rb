# spec/requests/todos_spec.rb
require 'rails_helper'

RSpec.describe 'BRSKI EST API', type: :request do

  describe "voucher request" do
    it "POST /requestvoucher" do
      # make an HTTPS request for a new voucher
      # this is section 3.3 of RFCXXXX/draft-ietf-anima-dtbootstrap-anima-keyinfra
      token = File.read("spec/files/jada_abcd.jwt")
      post '/requestvoucher', params: token, headers: {
             'CONTENT_TYPE' => 'application/voucherrequest+cms',
             'ACCEPT'       => 'application/json'
           }

      expect(response).to have_http_status(200)

      (part1,part2,part3) = response.body.split('.')
      jsonreply = JSON.parse(Base64.urlsafe_decode64(part2))
      expect(jsonreply['ietf-voucher:voucher']).to_not be_nil
    end

  end

end
