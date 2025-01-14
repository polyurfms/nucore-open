# frozen_string_literal: true

class User < ApplicationRecord

  include ::Users::Roles
  include Nucore::Database::WhereIdsIn

  # ldap_authenticatable is included via a to_prepare hook if ldap is enabled
  devise :database_authenticatable, :encryptable, :trackable, :recoverable, :timeoutable

  has_many :account_users, -> { where(deleted_at: nil) }
  has_many :accounts, through: :account_users
  has_many :orders
  has_many :order_details, through: :orders
  has_many :reservations, through: :order_details
  has_many :price_group_members, class_name: "UserPriceGroupMember", dependent: :destroy
  has_many :price_groups, -> { SettingsHelper.feature_on?(:user_based_price_groups) ? distinct : none }, through: :price_group_members
  has_many :product_users
  has_many :product_admins
  has_many :products, through: :product_users
  has_many :notifications
  has_many :assigned_order_details, class_name: "OrderDetail", foreign_key: "assigned_user_id"
  has_many :user_roles, -> { extending UserRole::AssociationExtension }, dependent: :destroy
  has_many :facilities, through: :user_roles
  has_many :training_requests, dependent: :destroy
  has_many :stored_files, through: :order_details, class_name: "StoredFile"
  has_many :log_events, as: :loggable
  has_many :user_preferences, dependent: :destroy
  has_many :user_delegations, dependent: :destroy

  has_one :supervisor, inverse_of: :user

  validates_presence_of :username, :first_name, :last_name
  validates :email, presence: true, email_format: true
  validates_uniqueness_of :username, :email
  validates :suspension_note, length: { maximum: 255 }

  accepts_nested_attributes_for :account_users, allow_destroy: true

  # Gem ldap_authenticatable expects User to respond_to? :login. For us that's #username.
  alias_attribute :login, :username

  # TODO: This allows downstream forks that reference deactivated_at to not break. Once
  # those are cleaned up, remove me.
  alias_attribute :deactivated_at, :suspended_at

  # Gem ldap_authenticatable expects User to respond_to? :ldap_attributes. For us should return nil.
  attr_accessor :ldap_attributes

  attr_reader :is_normal_user

  cattr_accessor(:default_price_group_finder) { ::Users::DefaultPriceGroupSelector.new }

  scope :authenticated_externally, -> { where(encrypted_password: nil, password_salt: nil) }
  scope :active, -> { unexpired.where(suspended_at: nil) }
  scope :unexpired, -> { where(expired_at: nil) }

  scope :with_global_roles, -> { where(id: UserRole.global.select("distinct user_id")) }
  scope :with_recent_orders, ->(facility) { distinct.joins(:order_details).merge(OrderDetail.recent.for_facility(facility)) }
  scope :sort_last_first, -> { order(Arel.sql("LOWER(users.last_name), LOWER(users.first_name)")) }

  scope :check_academic_user_and_payment_source, -> (users_id) {joins(:account_users).where("(LOWER(user_role) = LOWER('Owner') or LOWER(user_type) = LOWER('staff')) and user_id = ? ", users_id)}

  # finds all user role mappings for a this user in a facility
  def facility_user_roles(facility)
    UserRole.where(facility_id: facility.id, user_id: id)
  end

  #
  # Returns true if the user is authenticated against nucore's
  # user table, false if authenticated by an external system
  def authenticated_locally?
    encrypted_password.present? && password_salt.present?
  end

  #
  # Returns true if this user uses Devise's authenticatable module
  def email_user?
    if !user_type.nil? && (!user_type.to_s.casecmp("Staff").zero? && !user_type.to_s.casecmp("Student").zero?)
      return true
    else
      username.casecmp(email.downcase).zero?
    end
  end

  def password_updatable?
    email_user?
  end

  def update_password_confirm_current(params)
    unless valid_password? params[:current_password]
      errors.add(:current_password, :incorrect)
    end
    update_password(params)
  end

  def update_password(params)
    unless password_updatable?
      errors.add(:base, :password_not_updatable)
      return false
    end

    errors.add(:password, :empty) if params[:password].blank?
    errors.add(:password, :password_too_short) if params[:password] && params[:password].strip.length < 6
    errors.add(:password_confirmation, :confirmation) if params[:password] != params[:password_confirmation]

    if errors.empty?
      self.password = params[:password].strip
      clear_reset_password_token
      save!
      return true
    else
      return false
    end
  end

  # Find the users for a facility
  def self.find_users_by_facility(facility)
    facility
      .users
      .sort_last_first
  end

  #
  # A cart is an order. This method finds this user's order.
  # [_created_by_user_]
  #   The user that created the order we want. +self+ is
  #   inferred if left nil.
  # [_find_existing_]
  #   true if we want to look in the DB for an order to add
  #   new +OrderDetail+s to, false if we want a brand new order
  def cart(created_by_user = nil, find_existing = true)
    if find_existing
      Cart.new(self, created_by_user).order
    else
      Cart.new(self, created_by_user).new_cart
    end
  end

  def account_price_groups
    groups = accounts.active.collect(&:price_groups).flatten.uniq
  end

  #
  # Given a +Product+ returns all valid accounts this user has for
  # purchasing that product
  def accounts_for_product(product)
    acts = accounts.active.for_facility(product.facility).to_a
    acts.reject! { |acct| !acct.validate_against_product(product, self).nil? }
    acts
  end

  # Returns a hash of product_id => approved_at date when this user was granted
  # access to the product
  def approval_dates_by_product
    product_users.pluck(:product_id, :approved_at).to_h
  end

  def approval_remark_by_product
    product_users.pluck(:product_id, :remark).to_h
  end

  def product_admin_by_user
    product_admins.pluck(:product_id, :user_id).to_h
  end

  def administered_order_details(curr_user = self)
    OrderDetail.where(account_id: Account.administered_by(curr_user))
  # def administered_order_details
  #   OrderDetail.where(account_id: Account.administered_by(self))
  end

  def full_name(suspended_label: true)
    Users::NamePresenter.new(self, suspended_label: suspended_label).full_name
  end
  alias to_s full_name
  alias name full_name

  def last_first_name(suspended_label: true)
    Users::NamePresenter.new(self, suspended_label: suspended_label).last_first_name
  end

  # Devise uses this method for determining if a user is allowed to log in. It
  # also gets called on each request, so if a user gets suspended, they'll be
  # kicked out of their session.
  def active_for_authentication?
    super && active?
  end

  def active?
    !suspended? && !expired?
  end

  def suspended?
    suspended_at.present?
  end

  def expired?
    expired_at.present?
  end

  def internal?
    price_groups.include?(PriceGroup.base)
  end

  def payment_source_owner?
    account_users.exists?(user_role: 'Owner')
  end

  def update_price_group(params)
    if params[:internal] == "true"
      price_group_members.find_by(price_group: PriceGroup.external).try(:destroy)
      price_group_members.find_or_create_by(price_group: PriceGroup.base)
    elsif params[:internal] == "false"
      price_group_members.find_by(price_group: PriceGroup.base).try(:destroy)
      price_group_members.find_or_create_by(price_group: PriceGroup.external)
    else
      true
    end
  end

  def update_to_internal_price_group!
    price_group_members.find_by(price_group: PriceGroup.external).try(:destroy)
    price_group_members.find_or_create_by(price_group: PriceGroup.base)
  end

  def update_to_base_external_group!
    price_group_members.find_by(price_group: PriceGroup.base).try(:destroy)
    price_group_members.find_or_create_by(price_group: PriceGroup.external)
  end

  def default_price_group
    self.class.default_price_group_finder.call(self)
  end

  def create_default_price_group!
    return unless SettingsHelper.feature_on?(:user_based_price_groups)

    price_group_members.find_or_create_by!(price_group: default_price_group)
  end

  def is_normal_user?
    if @is_normal_user.nil?
      @is_normal_user = false
      @is_normal_user = true unless (administrator? || UserRole.where(deleted_at: nil, user_id: id).count > 0)
    end

    return @is_normal_user
  end

  def create_default_supervisor!
    creator = SupervisorCreator.create(self, last_name, first_name, email, username, dept_abbrev, true)
    creator.save()
  end

  def update_supervisor(params, created_by)
    creator = SupervisorCreator.update(self, params[:supervisor_last_name], params[:supervisor_first_name], params[:supervisor_email], params[:supervisor_netid], params[:supervisor_dept_abbrev], params[:supervisor_is_acad_staff], created_by)
    creator.save()
  end

  def has_supervisor?
    supervisor.present?
  end

  def supervisor_is_acad_staff?
    if supervisor.present?
      supervisor.is_academic?
    else
      false
    end
  end

  def supervisor_is_acad_staff
    supervisor.present? && supervisor.is_academic ? "Yes" : "No"
  end

  def supervisor_first_name
    supervisor.present? ? supervisor.first_name : nil
  end

  def supervisor_last_name
    supervisor.present? ? supervisor.last_name : nil
  end

  def supervisor_email
    supervisor.present? ? supervisor.email : nil
  end

  def supervisor_netid
    supervisor.present? ? supervisor.net_id : nil
  end

  def supervisor_dept_abbrev
    supervisor.present? ? supervisor.dept_abbrev : nil
  end

  def supervisor_full_name
    if supervisor.present?
      supervisor.first_name + " " + supervisor.last_name
    else
      nil
    end
  end

end
