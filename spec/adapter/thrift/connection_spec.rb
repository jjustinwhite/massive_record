require 'spec_helper'

describe "A connection" do
  
  let(:subject) { MassiveRecord::Wrapper::Connection }
  let(:conn) { subject.new(:host => MR_CONFIG['host'], :port => MR_CONFIG['port']) }  

  it "should populate the port" do
    expect(conn.port).to eq(MR_CONFIG['port'])
  end

  it "should have a default timeout of 4 seconds" do
    expect(conn.timeout).to eq(4)
  end
  
  it "should allow configurable timeouts" do
    conn = subject.new(:timeout => 5)
    expect(conn.timeout).to be 5
  end
  
  describe "open / close" do

    it "should not be open be default" do
      expect(conn.open?).to be_false
    end
    
    it "should be open if opened" do
      expect(conn.open).to eq true
      expect(conn.open?).to be_truthy
      conn.close
    end
    
    it "should not be open if closed" do
      expect(conn.open).to eq true
      expect(conn.close).to be_truthy
      expect(conn.open?).to be_falsey
    end

    it "shouldn't trigger any error if we try to close a close connection and there is no open connection" do
      expect(conn.close).to eq true
    end

  end
    
  describe "tables" do
    
    before do
      allow(conn).to receive(:getTableNames) { [MR_CONFIG['table']] }
    end

    it "should have a collection of tables" do
      conn.open
      expect(conn.tables).to be_a_kind_of(MassiveRecord::Wrapper::TablesCollection)
      conn.close
    end

    it "should load a table" do
      expect(conn.load_table(MR_CONFIG['table']).class).to eql(MassiveRecord::Wrapper::Table)
      expect(conn.tables.load(MR_CONFIG['table']).class).to eql(MassiveRecord::Wrapper::Table)
    end

  end

  describe "caching" do

    before do
      allow(conn).to receive(:getTableNames) { ["table_name_1"] }
    end

    it "should cache the list of tables" do
      conn.open
      expect(conn.tables).to eq(["table_name_1"])
      expect(conn.tables_collection).to eq(["table_name_1"])
    end

    it "should not expire tables collection unless a table is modified" do
      conn.tables_collection = ["test"]
      conn.send(:expire_tables_collection_if_needed, "updateRow")
      expect(conn.tables_collection).to eq(["test"])
    end

    it "should expire the cache when another table is created" do
      conn.tables_collection = ["test"]
      conn.send(:expire_tables_collection_if_needed, "createTable")
      expect(conn.tables_collection).to be_nil
    end

    it "should expire the cache when another table is deleted" do
      conn.tables_collection = ["test"]
      conn.send(:expire_tables_collection_if_needed, "deleteTable")
      expect(conn.tables_collection).to be_nil
    end

  end

  describe "catching errors" do
    it "should not be able to open a new connection with a wrong configuration and Raise an error" do
      conn.port = 1234
      expect { conn.open }.to raise_error(MassiveRecord::Wrapper::Errors::ConnectionException)
    end

    it "should try to open a new connection when an IO error occured" do
      conn.open
      allow_any_instance_of(Apache::Hadoop::Hbase::Thrift::Hbase::Client).to receive(:scannerGetList) do 
        raise ::Apache::Hadoop::Hbase::Thrift::IOError, "closed stream"
      end
      expect(conn).to receive(:open).with(:reconnecting => true, :reason => ::Apache::Hadoop::Hbase::Thrift::IOError)
      conn.scannerGetList("arg1", "arg2")
    end

    it "should try to open a new connection when some packets are lost" do
      conn.open
      allow_any_instance_of(Apache::Hadoop::Hbase::Thrift::Hbase::Client).to receive(:scannerGetList) do 
        raise ::Thrift::TransportException
      end
      expect(conn).to receive(:open).with(:reconnecting => true, :reason => ::Thrift::TransportException)
      conn.scannerGetList("arg1", "arg2")
    end

    it "should try to open a new connection when getting table names fails" do
      conn.open
      allow_any_instance_of(Apache::Hadoop::Hbase::Thrift::Hbase::Client).to receive(:getTableNames) do 
        raise ::Thrift::ApplicationException.new(::Thrift::ApplicationException::MISSING_RESULT, 'getTableNames failed: unknown result')
      end
      expect(conn).to receive(:open).with(:reconnecting => true, :reason => ::Thrift::ApplicationException)
      conn.tables
    end
  end

  describe "host(s)" do
    it "should have a host populated" do
      conn = subject.new(:host => "12.34.56.78")
      expect(conn.host).to eq("12.34.56.78")
    end    

    it "should have a pool of hosts" do
      conn = subject.new(:hosts => ["12.34.56.78", "34.56.78.90"])
      expect(conn.hosts).to eq(["12.34.56.78", "34.56.78.90"])
    end

    it "should have a current_host empty by default" do
      conn = subject.new(:host => "12.34.56.78")
      expect(conn.current_host).to be_nil
    end

    it "should populate current_host according to host" do
      conn = subject.new(:host => "12.34.56.78")
      conn.send(:populateCurrentHost)
      expect(conn.current_host).to eq("12.34.56.78")
    end

    it "should populate current_host according to hosts" do
      conn = subject.new(:hosts => ["90.34.56.78", "34.56.78.90"])
      conn.send(:populateCurrentHost)
      expect(["90.34.56.78", "34.56.78.90"]).to include(conn.current_host)
      selectedHost = conn.current_host

      nextSelectedHost = ["90.34.56.78", "34.56.78.90"]
      nextSelectedHost.delete(conn.current_host)
      nextSelectedHost = nextSelectedHost.first
      conn.send(:populateCurrentHost)      
      expect(conn.current_host).to eq(nextSelectedHost)
    end
  end

end
