require 'spec_helper'

describe MassiveRecord::Adapters::Thrift::Table do
  def connection
    @connection ||= MassiveRecord::Wrapper::Connection.new(:host => MR_CONFIG['host'], :port => MR_CONFIG['port']).tap do |connection|
      connection.open
    end
  end

  def subject
    @subject ||= MassiveRecord::Wrapper::Table.new(connection, MR_CONFIG['table'])
  end

  before :all do
    subject.destroy if subject.exists?
    subject.column_families.create(:base)
    subject.save
  end
  
  after :all do
    subject.destroy
    connection.close
  end  

  before do
    2.times do |index|
      MassiveRecord::Wrapper::Row.new.tap do |row|
        row.id = (index + 1).to_s
        row.values = {:base => {:first_name => "John-#{index}", :last_name => "Doe-#{index}" }}
        row.table = subject
        row.save
      end
    end
  end

  after do
    subject.all.each &:destroy
  end

  it "finds one id" do
    expect(subject.find("1").id).to eq "1"
  end

  it "finds one id given as array" do
    expect(subject.find(["1"]).first.id).to eq "1"
  end

  it "finds multiple ids" do
    expect(subject.find(["1", "2"]).collect(&:id)).to eq ["1", "2"]
  end
end
