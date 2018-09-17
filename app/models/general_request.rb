# frozen_string_literal: true
# == Schema Information
#
# Table name: general_requests
#
#  id                :bigint(8)        not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint(8)        not null
#  target_account_id :bigint(8)        not null
#  show_reblogs      :boolean          default(TRUE), not null
#  request_type      :string
#  uri               :string
#

class GeneralRequest < ApplicationRecord
  include Paginable
  include RelationshipCacheable

  belongs_to :account
  belongs_to :target_account, class_name: 'Account'

  has_one :notification, as: :activity, dependent: :destroy
  has_one :status

  validates :account_id, uniqueness: { scope: :target_account_id }

  def authorize!

    ReblogService.new.call(account, status) if request_type = "reblog"
    account.follow!(target_account, reblogs: show_reblogs, uri: uri) if request_type = "follow"
    MergeWorker.perform_async(target_account.id, account.id)
    destroy!
  end

  alias reject! destroy!

  def local?
    false # Force uri_for to use uri attribute
  end

  before_validation :set_uri, only: :create

  private

  def set_uri
    self.uri = ActivityPub::TagManager.instance.generate_uri_for(self) if uri.nil?
  end
end
