# spec/requests/todos_spec.rb
require 'rails_helper'
require 'support/pem_data'

RSpec.describe 'BRSKI EST API', type: :request do

  before(:each) do
    FileUtils::mkdir_p("tmp")
    MasaKeys.masa.certdir = Rails.root.join('spec','files','cert')

    SystemVariable.setbool!(:enrollment, false)
    $EnrollmentSupported = false
  end

  describe "Device Enrollment API" do
    it "should fail when enrollment not enabled" do
      env = Hash.new
      env["CONTENT_TYPE"]    = "application/pkcs10-base64"
      body = IO::read("spec/files/csr/bulb03.der")

      post "/.well-known/est/simpleenroll", :headers => env, :params => Base64.encode64(body)
      expect(response).to have_http_status(401)
    end

    it "should fail when enrollment is enabled, but not supported" do
      SystemVariable.setbool!(:enrollment, true)
      $EnrollmentSupported = false

      env = Hash.new
      env["CONTENT_TYPE"]    = "application/pkcs10-base64"
      body = IO::read("spec/files/csr/bulb03.der")

      post "/.well-known/est/simpleenroll", :headers => env, :params => Base64.encode64(body)
      expect(response).to have_http_status(401)
    end

    it "should fail when enrollment is enabled, supported with authentication, but no token" do
      SystemVariable.setbool!(:enrollment, true)
      $EnrollmentSupported = :authenticate

      env = Hash.new
      env["CONTENT_TYPE"]    = "application/pkcs10-base64"
      body = IO::read("spec/files/csr/bulb03.der")

      post "/.well-known/est/simpleenroll", :headers => env, :params => Base64.encode64(body)
      expect(response).to have_http_status(401)
    end

    it "should fail when enrollment is enabled, supported with authentication, but wrong token" do
      SystemVariable.setbool!(:enrollment, true)
      $EnrollmentSupported = :authenticate
      SystemVariable.setvalue(:enrollmentauth, "password")

      env = Hash.new
      env["CONTENT_TYPE"]    = "application/pkcs10-base64"
      env["Authorization"]   = "wrong"
      body = IO::read("spec/files/csr/bulb03.der")

      post "/.well-known/est/simpleenroll", :headers => env, :params => Base64.encode64(body)
      expect(response).to have_http_status(401)
    end

    it "should work when enrollment is enabled, supported without authentication" do
      SystemVariable.setbool!(:enrollment, true)
      $EnrollmentSupported = true

      env = Hash.new
      env["CONTENT_TYPE"]    = "application/pkcs10-base64"
      body = IO::read("spec/files/csr/bulb03.der")

      post "/.well-known/est/simpleenroll", :headers => env, :params => Base64.encode64(body)
      expect(response).to have_http_status(200)
    end

    it "should work when enrollment is enabled, supported with correct authentication " do
      SystemVariable.setbool!(:enrollment, true)
      pw0 = "password"
      SystemVariable.setvalue(:enrollmentauth, pw0)
      $EnrollmentSupported = :authenticate

      env = Hash.new
      env["CONTENT_TYPE"]    = "application/pkcs10-base64"
      env["Authorization"] = pw0
      body = IO::read("spec/files/csr/bulb03.der")

      post "/.well-known/est/simpleenroll", :headers => env, :params => Base64.encode64(body)
      expect(response).to have_http_status(200)
      expect(response.body).to_not be_blank
      cert = OpenSSL::X509::Certificate.new(response.body)
      expect(cert.subject.to_a.try(:first).try(:first)).to eq("serialNumber")
      expect(cert.subject.to_a.try(:first).try(:second)).to_not be_blank
    end
  end
end

