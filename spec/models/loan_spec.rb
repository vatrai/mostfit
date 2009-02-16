require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Loan do

  before(:each) do
    @user = User.new(:id => 234, :login => 'Joey User', :password => 'password', :password_confirmation => 'password')
    # validation needs to check for uniqueness, therefor calls the db, therefor we dont do it

    @manager = StaffMember.new(:name => "Mrs. M.A. Nerger")
    # validation needs to check for uniqueness, therefor calls the db, therefor we dont do it

    @branch = Branch.new(:name => "Kerela branch")
    @branch.manager = @manager
    @branch.should be_valid

    @center = Center.new(:name => "Munnar hill center")
    @center.manager = @manager
    @center.branch = @branch
    @center.should be_valid

    @client = Client.new(:name => 'Ms C.L. Ient', :reference => 'XW000-2009.01.05')
    @client.center = @center
    # validation needs to check for uniqueness, therefor calls the db, therefor we dont do it

    @loan = Loan.new(:id => 123456, :amount => 1000, :interest_rate => 0.2, :installment_frequency => :weekly, :number_of_installments => 30, :scheduled_first_payment_date => "2000-12-06", :applied_on => "2000-02-01", :scheduled_disbursal_date => "2000-06-13")
    @loan.history_disabled = true
    @loan.applied_by = @manager
    @loan.client = @client
    @loan.should be_valid

    @loan.approved_on = "2000-02-03"
    @loan.approved_by = @manager
    @loan.should be_valid
  end


  it "should have a discrimintator" do
    @loan.discriminator.should_not be_blank
  end
  it "should not be valid without belonging to a client" do
    @loan.client = nil
    @loan.should_not be_valid
  end
  it "should not be valid without being approved properly" do
    @loan.applied_by = nil
    @loan.should_not be_valid
    @loan.applied_by = @manager
    @loan.applied_on = nil
    @loan.should_not be_valid
  end
  it "should not be valid without being approved properly" do
    @loan.approved_by = nil
    @loan.should_not be_valid
    @loan.approved_by = @manager
    @loan.approved_on = nil
    @loan.should_not be_valid
  end
  it "should not be valid without being rejected properly" do
    date = @loan.approved_on
    @loan.approved_by = nil
    @loan.approved_on = nil
    @loan.should be_valid
    @loan.rejected_on = date
    @loan.rejected_by = nil
    @loan.should_not be_valid
    @loan.rejected_by = @manager
    @loan.rejected_on = nil
    @loan.should_not be_valid
  end
  it "should not be valid without belonging to a client" do
    @loan.client = nil
    @loan.should_not be_valid
  end
  it "should not be valid without a proper amount" do
    @loan.amount = nil
    @loan.should_not be_valid
    @loan.amount = -1
    @loan.should_not be_valid
    @loan.amount = 0
    @loan.should_not be_valid
  end
  it "should not be valid without a proper interest_rate" do
    @loan.interest_rate = nil
    @loan.should_not be_valid
    @loan.interest_rate = -1
    @loan.should_not be_valid
    @loan.interest_rate = -0.2
    @loan.should_not be_valid
    @loan.interest_rate = 2.0
    @loan.should be_valid
  end
  it "should be valid with a proper installment_frequency" do
    @loan.installment_frequency = :daily
    @loan.should be_valid
    @loan.installment_frequency = :weekly
    @loan.should be_valid
    @loan.installment_frequency = :monthly
    @loan.should be_valid
  end
  it "should not be valid without proper installment_frequency" do
    @loan.installment_frequency = nil
    @loan.should_not be_valid
    @loan.installment_frequency = 'day'
    @loan.should_not be_valid
    @loan.installment_frequency = :month
    @loan.should_not be_valid
    @loan.installment_frequency = :week
    @loan.should_not be_valid
    @loan.installment_frequency = 'month'
    @loan.should_not be_valid
    @loan.installment_frequency = 7
    @loan.should_not be_valid
    @loan.installment_frequency = 14
    @loan.should_not be_valid
    @loan.installment_frequency = 30
    @loan.should_not be_valid
  end
  it "should not be valid without a proper number_of_installments" do
    @loan.number_of_installments = nil
    @loan.should_not be_valid
    @loan.number_of_installments = -1
    @loan.should_not be_valid
    @loan.number_of_installments = -0
    @loan.should_not be_valid
  end
  it "should not be valid without a scheduled_first_payment_date" do
    @loan.scheduled_first_payment_date = nil
    @loan.should_not be_valid
  end
  it "should not be valid without a scheduled_disbursal_date" do
    @loan.scheduled_disbursal_date = nil
    @loan.should_not be_valid
  end
  it "should not be valid with a disbursal date earlier than the loan is approved" do
    @loan.disbursed_by = @manager
    @loan.disbursed_by = @manager
    @loan.disbursal_date = @loan.approved_on - 10
    @loan.should_not be_valid
    @loan.disbursal_date = @loan.approved_on
    @loan.should be_valid
    @loan.disbursal_date = @loan.approved_on + 10
    @loan.should be_valid
  end
  it "should not be valid when written_off_on is earlier than the disbursal_date" do
    @loan.written_off_by = @manager
    @loan.disbursed_by   = @manager
    @loan.disbursal_date = @loan.scheduled_disbursal_date
    @loan.written_off_on = @loan.disbursal_date
    @loan.should be_valid
    @loan.written_off_on = @loan.disbursal_date + 1
    @loan.should be_valid
    @loan.written_off_on = @loan.disbursal_date - 1
    @loan.should_not be_valid
  end
  it "should not be valid without approved_on earlier than scheduled_disbursal_date" do
    @loan.scheduled_disbursal_date = @loan.approved_on - 10
    @loan.should_not be_valid
    @loan.scheduled_disbursal_date = @loan.approved_on
    @loan.should be_valid
    @loan.scheduled_disbursal_date = @loan.approved_on + 10
    @loan.should be_valid
  end
  it "should not be valid without being properly written off" do
    @loan.disbursal_date = @loan.scheduled_disbursal_date
    @loan.disbursed_by   = @manager
    @loan.written_off_on = @loan.disbursal_date
    @loan.written_off_by = @manager
    @loan.should be_valid
    @loan.written_off_on = @loan.disbursal_date
    @loan.written_off_by = nil
    @loan.should_not be_valid
    @loan.written_off_on = nil
    @loan.written_off_by = @manager
    @loan.should_not be_valid
  end
  it "should not be valid without being properly disbursed" do
    @loan.disbursal_date = @loan.scheduled_disbursal_date
    @loan.disbursed_by   = @manager
    @loan.should be_valid
    @loan.disbursal_date = nil
    @loan.disbursed_by   = @manager
    @loan.should_not be_valid
    @loan.disbursal_date = @loan.scheduled_disbursal_date
    @loan.disbursed_by   = nil
    @loan.should_not be_valid
  end
  it "should not be valid when scheduled_first_payment_date if before scheduled_disbursal_date" do
    @loan.scheduled_first_payment_date = @loan.scheduled_disbursal_date + 1
    @loan.should be_valid
    @loan.scheduled_first_payment_date = @loan.scheduled_disbursal_date
    @loan.should be_valid
    @loan.scheduled_first_payment_date = @loan.scheduled_disbursal_date - 1  # before disbursed
    @loan.should_not be_valid
  end




  it ".shift_date_by_installments should shift dates properly, even odd ones.. and backwards." do
    loan = Loan.new(:installment_frequency => :daily)
    loan.shift_date_by_installments(Date.parse('2001-01-01'), 1).should == Date.parse('2001-01-02')
    loan.shift_date_by_installments(Date.parse('2001-01-01'), -1).should == Date.parse('2000-12-31')
    loan.shift_date_by_installments(Date.parse('2001-12-31'), 1).should == Date.parse('2002-01-01')
    loan = Loan.new(:installment_frequency => :weekly)
    loan.shift_date_by_installments(Date.parse('2001-01-01'), 1).should == Date.parse('2001-01-08')
    loan.shift_date_by_installments(Date.parse('2001-01-01'), -1).should == Date.parse('2000-12-25')
    loan.shift_date_by_installments(Date.parse('2012-12-21'), 4).should == Date.parse('2013-01-18')
    loan.shift_date_by_installments(Date.parse('2001-01-01'),-52).should == Date.parse('2000-01-03')
    loan = Loan.new(:installment_frequency => :biweekly)
    loan.shift_date_by_installments(Date.parse('2001-01-01'), 1).should == Date.parse('2001-01-15')
    loan.shift_date_by_installments(Date.parse('2001-01-01'), -1).should == Date.parse('2000-12-18')
    loan = Loan.new(:installment_frequency => :monthly)
    loan.shift_date_by_installments(Date.parse('2001-01-01'), 1).should == Date.parse('2001-02-01')
    loan.shift_date_by_installments(Date.parse('2001-01-01'), -1).should == Date.parse('2000-12-01')
    loan.shift_date_by_installments(Date.parse('2000-01-31'), 1).should == Date.parse('2000-02-29') # febs last days:
    loan.shift_date_by_installments(Date.parse('2000-01-30'), 1).should == Date.parse('2000-02-29')
    loan.shift_date_by_installments(Date.parse('2000-01-29'), 1).should == Date.parse('2000-02-29')
    loan.shift_date_by_installments(Date.parse('2000-03-31'), -1).should == Date.parse('2000-02-29')
    loan.shift_date_by_installments(Date.parse('2000-03-30'), -1).should == Date.parse('2000-02-29')
    loan.shift_date_by_installments(Date.parse('2000-03-29'), -1).should == Date.parse('2000-02-29')
    loan.shift_date_by_installments(Date.parse('2001-01-31'), 1).should == Date.parse('2001-02-28')
    loan.shift_date_by_installments(Date.parse('2001-01-30'), 1).should == Date.parse('2001-02-28')
    loan.shift_date_by_installments(Date.parse('2001-01-29'), 1).should == Date.parse('2001-02-28')
    loan.shift_date_by_installments(Date.parse('2001-01-28'), 1).should == Date.parse('2001-02-28')
    loan.shift_date_by_installments(Date.parse('2001-03-31'), -1).should == Date.parse('2001-02-28')
    loan.shift_date_by_installments(Date.parse('2001-03-30'), -1).should == Date.parse('2001-02-28')
    loan.shift_date_by_installments(Date.parse('2001-03-29'), -1).should == Date.parse('2001-02-28')
    loan.shift_date_by_installments(Date.parse('2001-03-28'), -1).should == Date.parse('2001-02-28')
  end

  it ".descendants should keep track of the subclasses (just testing dm-core functionality)" do
    class TestLoan < Loan; end
    Loan.descendants.include?(TestLoan).should be_true
  end

  it ".number_of_installments_before should do what it promises" do
    loan = Loan.new(:installment_frequency => :daily, :scheduled_first_payment_date => Date.parse('2001-01-01'), :number_of_installments => 10)
    loan.number_of_installments_before(Date.parse('2001-01-01')).should == 1
    loan.number_of_installments_before(Date.parse('2001-01-02')).should == 2
    loan.number_of_installments_before(Date.parse('2001-01-03')).should == 3
    loan.number_of_installments_before(Date.parse('2000-12-31')).should == 0
    loan.number_of_installments_before(Date.parse('1999-01-01')).should == 0
    loan.number_of_installments_before(Date.parse('2001-01-10')).should == 10
    loan.number_of_installments_before(Date.parse('2001-01-11')).should == 10
    loan.installment_frequency = :weekly
    loan.number_of_installments_before(Date.parse('2001-01-01')).should == 1
    loan.number_of_installments_before(Date.parse('2001-01-02')).should == 1
    loan.number_of_installments_before(Date.parse('2001-01-08')).should == 2
    loan.number_of_installments_before(Date.parse('2001-01-01')+(7*10)).should == 10
    loan.number_of_installments_before(Date.parse('2001-01-01')+(7*10)+1).should == 10
    loan.number_of_installments_before(Date.parse('2001-01-01')+(7*10)+100).should == 10
    loan.number_of_installments_before(Date.parse('1999-01-01')).should == 0
    loan.installment_frequency = :biweekly
    loan.number_of_installments_before(Date.parse('2001-01-01')).should == 1
    loan.number_of_installments_before(Date.parse('2001-01-14')).should == 1
    loan.number_of_installments_before(Date.parse('2001-01-15')).should == 2
    loan.number_of_installments_before(Date.parse('2001-01-01')+10*14).should == 10
    loan.number_of_installments_before(Date.parse('2001-01-01')+100*14).should == 10
    loan.number_of_installments_before(Date.parse('1999-01-01')).should == 0
    loan.installment_frequency = :monthly
    loan.number_of_installments_before(Date.parse('2001-01-01')).should == 1
    loan.number_of_installments_before(Date.parse('2001-02-01')).should == 2
    loan.number_of_installments_before(Date.parse('2001-03-01')).should == 3
    loan.number_of_installments_before(Date.parse('2001-10-01')).should == 10
    loan.number_of_installments_before(Date.parse('2001-11-01')).should == 10
    loan.scheduled_first_payment_date = Date.parse('2000-01-30')  # febs last days
    loan.number_of_installments_before(Date.parse('2000-02-01')).should == 1
    loan.number_of_installments_before(Date.parse('2000-02-28')).should == 1
    loan.number_of_installments_before(Date.parse('2000-02-29')).should == 1
    loan.number_of_installments_before(Date.parse('2000-03-01')).should == 2
    loan.number_of_installments_before(Date.parse('2000-03-30')).should == 3
    loan.scheduled_first_payment_date = Date.parse('2001-01-30')  # febs last days (non leap year)
    loan.number_of_installments_before(Date.parse('2001-02-28')).should == 1
    loan.number_of_installments_before(Date.parse('2001-03-01')).should == 2
    loan.number_of_installments_before(Date.parse('2001-03-30')).should == 3
  end

  it ".last_loan_history_date should have some tests -- albeit more a view thing"

  it ".scheduled_repaid_on give the proper date" do
    @loan.scheduled_repaid_on.should eql(Date.parse('2001-06-27'))
  end

  it ".status should give status accoring to changing properties up to it written off" do
    @loan.status.should == :approved
    @loan.disbursal_date = Date.today
    @loan.disbursed_by   = @manager
    @loan.status.should == :outstanding
    @loan.status(Date.today - 1).should == :approved
    @loan.written_off_on = Date.today
    @loan.written_off_by = @manager
    @loan.status.should == :written_off
    @loan.status(Date.today - 1).should == :approved
  end
  it ".status should give status accoring to changing properties up to it is repaid" do
    @loan.disbursal_date = Date.today
    @loan.disbursed_by   = @manager
    @loan.status.should == :outstanding
    # no payments on unsaved (new_record? == true) loans:
    lambda { @loan.repay(@loan.total_to_be_received, @user, Date.today, @manager) }.should raise_error
    @loan.save.should == true
    r = @loan.repay(@loan.total_to_be_received, @user, Date.today, @manager)
    p r[1].errors unless r[0]
    r[0].should == true
    @loan.status.should == :repaid
    @loan.status(Date.today - 1).should == :approved
  end
  it ".status should give status accoring to changing properties before being approved" do
    @loan.status(@loan.applied_on - 1).should be_nil
    @loan.status(@loan.applied_on).should == :pending
    @loan.status(@loan.approved_on - 1).should == :pending
    @loan.status.should == :approved
  end
  it ".status should give status accoring to changing properties when being rejected" do
    date = @loan.approved_on
    @loan.approved_on = nil
    @loan.approved_by = nil
    @loan.rejected_on = date
    @loan.rejected_by = @manager
    @loan.should be_valid
    @loan.status(@loan.rejected_on - 1).should == :pending
    @loan.status(@loan.rejected_on).should == :rejected
    @loan.status.should == :rejected
  end


  it "cannot repay an unsaved loan" do
    lambda { @loan.repay(@loan.total_to_be_received, @user, Date.today, @manager) }.should raise_error
  end

  it ".installment_dates should give a list with some dates" do
    dates = @loan.installment_dates
    dates.uniq.size.should eql(@loan.number_of_installments)
    dates.sort[0].should eql(@loan.scheduled_first_payment_date)
    dates.sort[-1].should eql(@loan.scheduled_repaid_on)
    dates.sort[-2].should eql(@loan.shift_date_by_installments(@loan.scheduled_repaid_on, -1))
  end

  it ".payment_schedule should also have some specs -- albeit more on the view side"

end