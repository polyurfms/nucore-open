module LdapAuthentication

  class SupervisorLookup

    def call(username, dept)
      entry = UserEntry.find_by_dept(username, dept)
      # entry.to_user if entry
      result = Array.new
      if (!entry.nil? && entry.length > 0)
        entry.each do |e|
          result << e.to_user 
        end
      end
      result
    end
  end
end
