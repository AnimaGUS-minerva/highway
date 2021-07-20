class VersionController < ActionController::Base
  include Response

  def index
    respond_to do |format|
      format.html {
        # yes, they asked for text/html, but we are giving them text/plain
        render :plain => "highway:\n\tHostname: #{SystemVariable.hostname}\n\tVersion: #{$VERSION}\n\tRevision: #{$REVISION}\n", :content_type => 'text/plain'
      }
      format.json {
        data = Hash.new
        data['version'] = $VERSION
        data['revision']= $REVISION
        data['Hostname'] = SystemVariable.hostname
        cert = request.env['SSL_CLIENT_CERT'] || request.env["rack.peer_cert"]
        unless cert.blank?
          data['client_certificate'] = cert
        end
        api_response(data, :ok, 'application/json')
      }
    end
  end
end
