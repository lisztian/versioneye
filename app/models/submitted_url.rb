class SubmittedUrl

  require 'will_paginate/array'

  include Mongoid::Document
  include Mongoid::Timestamps

  field :url, type: String
  field :message, type: String
  field :user_id, type: String
  field :user_email, type: String
  field :search_term, type: String
  field :declined, type: Boolean
  field :declined_message, type: String
  field :integrated, type: Boolean, default: false

  belongs_to :product_resource

  validates :url, presence: true
  validates :message, presence: true
  validates :user_email, format: {with: /^([^@\s]+)@((?:[-a-z0-9]+.)+[a-z]{2,})$/i, 
                                  :allow_blank => true}

  scope :as_unchecked, where(declined: nil)
  scope :as_checked, where(:declined.in => [false, true])
  scope :as_accepted, where(declined: false)
  scope :as_declined, where(declined: true)
  scope :as_not_integrated, where(integrated: false)

  def self.find_by_id(id)
    return nil if id.nil?
    id = id.to_s
    return self.find(id.to_s) if self.where(_id: id.to_s).exists? 
  end

  def user
    User.find_by_id user_id
  end

  def fetch_user_email
    return user_email if user_email

    user = self.user
    return user.email if user
      
    return nil
  end

  def update_integration_status
    user_email = self.fetch_user_email
    resource = self.product_resource
    prod_key = resource.prod_key unless resource.nil? or resource.prod_key.nil?
    @product =  Product.find_by_key(prod_key)
    self.integrated = true unless @product.nil?
    
    if self.save and not @product.nil?
      @submitted_url = self
      SubmittedUrlMailer.integrated_url_email(
        user_email, @submitted_url, @product).deliver unless user_email.nil?

      return true
    else
      $stderr.puts "Failed to update integration status for submittedUrl.#{self._id}"
      $stderr.puts self.errors.full_messages.to_sentence
    end
    return false
  end
end
