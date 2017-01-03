require 'spec_helper'
require 'orm/models/test_class'
require 'orm/models/person'

describe "configuration" do
  include MockMassiveRecordConnection

  before do
    @mock_connection = double(MassiveRecord::Wrapper::Connection, :open => true)
    allow(MassiveRecord::Wrapper::Connection).to receive(:new).and_return(@mock_connection)
  end

  describe "connection" do
    it "should use connection_configuration if present" do
      TestClass.reset_connection!
      expect(MassiveRecord::Wrapper::Connection).to receive(:new).with(TestClass.connection_configuration)
      TestClass.connection
    end

    it "should not ask Wrapper::Base for a connection when Rails is not defined" do
      expect(MassiveRecord::Wrapper::Base).not_to receive(:connection)
      TestClass.connection
    end

    it "should use the same connection if asked twice" do
      TestClass.connection_configuration = {:host => "foo", :port => 9001}
      expect(MassiveRecord::Wrapper::Connection).to receive(:new).once.and_return(@mock_connection)
      2.times { TestClass.connection }
    end

    it "should use the same connection for different sub classes" do
      TestClass.connection_configuration = {:host => "foo", :port => 9001}
      expect(MassiveRecord::Wrapper::Connection).to receive(:new).and_return(@mock_connection)
      expect(TestClass.connection).to eq(Person.connection)
    end

    it "should raise an error if connection configuration is missing" do
      TestClass.connection_configuration = {}
      expect { TestClass.connection }.to raise_error MassiveRecord::ORM::ConnectionConfigurationMissing
    end

    it "should return an opened connection" do
      @mock_connection = double(MassiveRecord::Wrapper::Connection)
      expect(@mock_connection).to receive(:open)
      expect(MassiveRecord::Wrapper::Connection).to receive(:new).and_return(@mock_connection)

      TestClass.connection
    end


    describe "under Rails" do
      before do
        TestClass.connection_configuration = {}
        module ::Rails; end
        allow(MassiveRecord::Wrapper::Base).to receive(:connection).and_return(@mock_connection)
      end
      
      after do
        Object.send(:remove_const, :Rails)
      end

      it "should simply call Wrapper::Base" do
        expect(MassiveRecord::Wrapper::Base).to receive(:connection).and_return(@mock_connection)
        expect(TestClass.connection).to eq(@mock_connection)
      end

      it "should use connection_configuration if defined" do
        TestClass.connection_configuration = {:host => "foo", :port => 9001}
        expect(MassiveRecord::Wrapper::Connection).to receive(:new).with(TestClass.connection_configuration)
        TestClass.connection
      end
    end
  end



  describe "table" do
    it "should create a new wrapper table instance" do
      table_name = "TestClasss"
      connection = "dummy_connection"

      expect(TestClass).to receive(:table_name).and_return(table_name)
      expect(TestClass).to receive(:connection).and_return(connection)
      expect(MassiveRecord::Wrapper::Table).to receive(:new).with(connection, table_name)

      TestClass.table
    end

    it "should not reinitialize the same table twice" do
      expect(MassiveRecord::Wrapper::Table).to receive(:new).twice
      2.times { TestClass.table }
      2.times { Person.table }
    end

    it "should not return the same table for two different sub classes" do
      expect(TestClass.table).not_to eq(Person.table)
    end

    it "should use the same conncetion for two tables" do
      expect(TestClass.table.connection).to eq(Person.table.connection)
    end
  end
end
