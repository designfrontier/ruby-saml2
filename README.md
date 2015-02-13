Ruby SAML2 Library
==================

[![Build Status](https://travis-ci.org/instructure/ruby-saml2.png)](https://travis-ci.org/instructure/ruby-saml2)
[![Code Climate](https://codeclimate.com/github/instructure/ruby-saml2/badges/gpa.svg)](https://codeclimate.com/github/instructure/ruby-saml2)
[![Gem Version](https://fury-badge.herokuapp.com/rb/saml2.png)](http://badge.fury.io/rb/saml2)

About
-----

This library is for building a custom SAML 2.0 IdP with minimal headache.
A simple example of a Rails controller that just passes on an already
authenticated user to a single SP.


```ruby
require 'saml2'

class SamlIdpController < ApplicationController
  def create
    authn_request = SAML2::AuthnRequest.decode(params[:SAMLRequest])
    sp = authn_request.issuer == self.class.sp_entity_id && self.class.sp_metadata
    unless authn_request.valid?(sp)
      flash[:error] = "Invalid login request"
      return redirect_to @current_user ? root_url : login_url
    end

    if @current_user
      response = SAML2::Response.respond_to(authn_request)
      response.issuer = self.class.entity_id
      response.name_id = self.class.idp_name_id(@current_user, sp)
      response.sign(self.class.x509_certificate, self.class.private_key)

      @saml_response = Base64.encode64(response.to_xml)
      @saml_acs_url = authn_request.assertion_consumer_service.location
      @relay_state = params[:RelayState]
      render template: "saml2/http_post", layout: false
    else
      redirect_to login_url
    end
  end

  protected
  def self.idp_name_id(user)
    SAML2::NameID.new(user.uuid, SAML2::NameID::Format::PERSISTENT)
  end

  def self.saml_config
    @config ||= YAML.load(File.read('saml.yml'))
  end

  def self.sp_entity_id
    saml_config[:sp_entity_id]
  end

  def self.sp_metadata
    @sp ||= SAML2::SPMetadata.parse(File.read(saml_config[:sp_metadata]))
  end

  def self.entity_id
    saml_config[:entity_id]
  end

  def self.x509_certificate
    @cert ||= File.read(saml_config[:encryption][:certificate])
  end

  def self.private_key
    @key ||= File.read(saml_config[:encryption][:private_key])
  end

  def self.signature_algorithm
    saml_config[:encryption][:algorithm]
  end
end

```

Copyright
-----------

Copyright (c) 2015 Instructure, Inc. See LICENSE for details.