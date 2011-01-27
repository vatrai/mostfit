class Report
  include DataMapper::Resource

  attr_accessor :raw
  property :id, Serial
  property :start_date, Date
  property :end_date, Date
  property :report, Yaml, :length => 20000
  property :dirty, Boolean
  property :report_type, Discriminator
  property :created_at, DateTime
  property :generation_time, Integer

  validates_with_method :method => :from_date_should_be_less_than_to_date

  def name
    "#{report_type}: #{start_date} - #{end_date}"
  end

  def get_parameters(params, user=nil)
    st     = user.staff_member if user
    @funder = Funder.first(:user_id => user.id) if user and user.role == :funder
    @branch = get_branches(params)
    @account = Account.all(:order => [:name])

    # if the user is staff member or a funder then filter the branches against their managed branches list
    if user and st
      @branch = @branch & [st.centers.branches, st.branches].flatten
    elsif @funder
      @branch = @branch & @funder.branches
    end

    # if the user is staff member or a funder then filter the branches against their managed branches list
    if @area = get_areas(params)
      if user and st
        @area = @area & [st.branches.areas, st.areas].flatten
      elsif @funder
        @area = @area & @funder.areas
      end
      @branch = @area.branches
    end

    set_centers(params, user, st)    
    @funder = Funder.get(params[:funder_id]) if not @funder and params and params[:funder_id] and not params[:funder_id].blank?

    [:loan_product_id, :late_by_more_than_days, :absent_more_than, :late_by_less_than_days, :absent_more_than, :include_past_data, :include_unapproved_loans].each{|key|
      if params and params[key] and params[key].to_i>0
        instance_variable_set("@#{key}", params[key].to_i)
      end
    }
    set_instance_variables(params)
  end

  def calc
    t0 = Time.now
    all(:report_type => self.report_type, :start_date => self.start_date, :end_date => self.end_date).destroy!
    self.report = Marshal.dump(self.generate)
    self.generation_time = Time.now - t0
    self.save
  end

  def group_loans(by, columns, conditions = {})
    by_query = if by.class == String
                 by
               elsif by.class==Symbol
                 "l.#{by}"
               elsif by.class==Array
                 by.join(",")
               end
    condition, select = process_conditions(conditions)
    repository.adapter.query(%Q{
       SELECT #{[by, columns, select].flatten.reject{|x| x.blank?}.join(', ')}
       FROM branches b, centers c, clients cl, loans l
       WHERE b.id=c.branch_id AND c.id=cl.center_id AND cl.id=l.client_id AND l.deleted_at is NULL AND cl.deleted_at is NULL AND l.rejected_on is NULL
             #{condition}
       GROUP BY #{by_query}
    })    
  end

  def get_pdf
    pdf = PDF::HTMLDoc.new
    pdf.set_option :bodycolor, :white
    pdf.set_option :toc, false
    pdf.set_option :portrait, true
    pdf.set_option :links, true
    pdf.set_option :webpage, true
    pdf.set_option :left, '2cm'
    pdf.set_option :right, '2cm'
    pdf.set_option :header, "Header here!"
    f = File.read("app/views/reports/_#{name.snake_case.gsub(" ","_")}.pdf.haml")
    report = Haml::Engine.new(f).render(Object.new, :report => self)
    pdf << report
    pdf.footer ".t."
    pdf
  end

  def get_xls
    f = File.read("app/views/reports/_#{name.snake_case.gsub(" ","_")}.pdf.haml")
    doc = Hpricot(Haml::Engine.new(f).render(Object.new, :data => self.generate))
    
  end

  private
  def process_conditions(conditions)
    selects = []
    conditions = conditions.map{|query, value|
      key      = get_key(query)
      operator = get_operator(query, value)
      value    = get_value(value)
      operator = " is " if value == "NULL" and operator == "="
      next if not key
      "#{key}#{operator}#{value}"
    }
    query = ""
    query = " AND " + conditions.join(' AND ') if conditions.length>0
    [query, selects.join(', ')]
  end

  def get_key(query)
    if query.class==DataMapper::Query::Operator
      return query.target
    elsif query.class==String
      return query
    elsif query.class==Symbol and query==:fields
      return nil
    else
      return query
    end    
  end
  
  def get_operator(query, value)
    if query.respond_to?(:operator)
      case query.operator
      when :lte
        "<="
      when :gte
        ">="
      when :gt
        ">"
      when :lt
        "<"
      when :eq
        "="
      when :not
        " is not "
      else
        "="
      end
    elsif value.class == Array
      " in "
    else
      "="
    end
  end

  def get_value(val)
    if val.class==Date
      "'#{val.strftime("%Y-%m-%d")}'"
    elsif val.class==Array
      "(#{val.join(",")})"
    elsif val.nil?
      "NULL"
    else
      val
    end    
  end

  def get_branches(params)
    # if a branch is selected pick that or pick all of them
    if (params and params[:branch_id] and not params[:branch_id].blank?)
      Branch.all(:id => params[:branch_id])
    else
      Branch.all(:order => [:name])
    end
  end

  def get_areas(params)
    #if an area is selected pick otherwise pick NONE of them
    if (params and params[:area_id] and not params[:area_id].blank?)
      Area.all(:id => params[:area_id])
    end
  end

  def set_centers(params, user=nil, staff=nil)
    # if a center is selected pick that
    @center = Center.all(:id => params[:center_id]) if params and params[:center_id] and not params[:center_id].blank?

    # if the user is a staff member or funder and center is not selected then pick all the managed centers
    @center = 
      if user and not @center and (params and (not params[:staff_member_id] or params[:staff_member_id].blank?))
        if staff and (not params or not params[:staff_member_id] or params[:staff_member_id].blank?)
          [staff.centers, staff.branches.centers].flatten
        elsif staff and params[:staff_member_id] and not params[:staff_member_id].blank?
          StaffMember.get(params[:staff_member_id]).centers
        elsif @funder and (not params or not params[:staff_member_id] or params[:staff_member_id].blank?)
          @funder.centers
        elsif @funder and params[:staff_member_id] and not params[:staff_member_id].blank?
          @funder.centers & StaffMember.get(params[:staff_member_id]).centers
        end
      elsif @center and params and params[:staff_member_id] and not params[:staff_member_id].blank?
        @center & StaffMember.get(params[:staff_member_id]).centers
      elsif params and params[:staff_member_id] and not params[:staff_member_id].blank?
        StaffMember.get(params[:staff_member_id]).centers
      else
        @center
      end
    @center = @branch.collect{|b| b.centers}.flatten unless @center
  end

  def set_instance_variables(params)
    params.each{|key, value|
      instance_variable_set("@#{key}", value) if not [:date, :from_date, :to_date].include?(key.to_sym) and value and value.to_i>0
    } if params
  end

  def from_date_should_be_less_than_to_date
    if @from_date and @to_date and @from_date > @to_date
      return [false, "From date should be before to date"]
    end
    return true
  end

end
