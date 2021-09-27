# frozen_string_literal: true

module LdapAuthentication

  class UserEntry


    # Returns a single LdapAuthentication::UserEntry
    def self.find(uid)
      search(uid).first
    end

    def self.find_by_dept(uid, dept)
      search_by_Dept(uid, dept)
    end

    
    # Returns an Array of `LdapAuthentication::UserEntry`s
    def self.search(uid)
      return [] unless uid

      ldap_entries = nil
      ActiveSupport::Notifications.instrument "search.ldap_authentication" do |payload|
        ldap_entries = with_retry { admin_ldap.search(filter: Net::LDAP::Filter.eq(LdapAuthentication.attribute_field, uid)) }
        payload[:uid] = uid
        payload[:results] = ldap_entries
      end

      ldap_entries.map { |entry| new(entry) }
    end

    def self.search_by_Dept(uid, dept)
      return [] unless uid
      return [] unless dept
      
      ldap_entries = nil
      # ldap_entries_username = nil
      # ldap_entries_sn = nil
      # ldap_entries_givename = nil
      ActiveSupport::Notifications.instrument "search.ldap_authentication" do |payload|
        ldap_entries = with_retry { admin_ldap.search(filter: 
          (Net::LDAP::Filter.eq(LdapAuthentication.attribute_field, uid) & Net::LDAP::Filter.eq("departmentNumber", dept)) |
          (Net::LDAP::Filter.eq("givenname", uid) & Net::LDAP::Filter.eq("departmentNumber", dept)) |
          (Net::LDAP::Filter.eq("sn", uid) & Net::LDAP::Filter.eq("departmentNumber", dept))
          
          ) }
        payload[:uid] = uid
        payload[:results] = ldap_entries
      end
      ldap_entries.map { |entry| new(entry) }
    end

    def self.admin_ldap
      LdapAuthentication.admin_connection
    end
    private_class_method :admin_ldap

    def initialize(ldap_entry)
      @ldap_entry = ldap_entry
    end

    def username
      @ldap_entry.public_send(LdapAuthentication.attribute_field).last
    end

    def first_name
      @ldap_entry.givenname.first
    end

    def last_name
      @ldap_entry.sn.first
    end

    def email
      @ldap_entry.mail.first
    end

    def dept_abbrev
      #UAT
      #@ldap_entry.polyuStaffMainDept.first
      @ldap_entry.department.first
      #polyuStaffMainDept
      #DEV
      #@ldap_entry.departmentNumber.first
    end

    def user_type
      #polyuUserType
      @ldap_entry.polyuUserType.first
    end

    def to_user
      UserConverter.new(self).to_user
    end

    def self.with_retry(max_attempts = 3)
      tries = 0
      begin
        yield
      rescue Net::LDAP::Error => e
        tries += 1
        tries >= max_attempts ? raise : retry
      end
    end

  end

end
