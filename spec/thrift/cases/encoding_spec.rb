# encoding: utf-8
require 'spec_helper'

describe "encoding" do
  before :all do
    @table_name = "encoding_test" + SecureRandom.hex(3)
  end

  before do
    transport = Thrift::BufferedTransport.new(Thrift::Socket.new(MR_CONFIG['host'], 9090))
    protocol  = Thrift::BinaryProtocol.new(transport)
    @client   = Apache::Hadoop::Hbase::Thrift::Hbase::Client.new(protocol)
    
    transport.open()
    
    @column_family = "info:"
  end
  
  it "should create a new table" do
    column = Apache::Hadoop::Hbase::Thrift::ColumnDescriptor.new{|c| c.name = @column_family}
    expect(@client.createTable(@table_name, [column])).to be_nil
  end
  
  it "should save standard caracteres" do
    m        = Apache::Hadoop::Hbase::Thrift::Mutation.new
    m.column = "info:first_name"
    m.value  = "Vincent"
    
    expect(m.value.encoding).to eq(Encoding::UTF_8)
    expect(@client.mutateRow(@table_name, "ID1", [m], {})).to be_nil

    row = @client.getRow(@table_name, "ID1", {})[0].columns['info:first_name']
    expect(row.value).to eq("Vincent")
  end
  
  it "should save UTF8 caracteres" do
    m        = Apache::Hadoop::Hbase::Thrift::Mutation.new
    m.column = "info:first_name"
    m.value  = "Thorbjørn"
    
    expect(m.value.encoding).to eq(Encoding::UTF_8)
    expect(@client.mutateRow(@table_name, "ID1", [m], {})).to be_nil

    row = @client.getRow(@table_name, "ID1", {})[0].columns['info:first_name']
    expect(row.value).to eq("Thorbjørn")
  end
  
  it "should save JSON" do
    m        = Apache::Hadoop::Hbase::Thrift::Mutation.new
    m.column = "info:first_name"
    m.value  = { :p1 => "Vincent", :p2 => "Thorbjørn" }.to_json.force_encoding(Encoding::UTF_8)
    
    expect(m.value.encoding).to eq(Encoding::UTF_8)
    expect(@client.mutateRow(@table_name, "ID1", [m], {})).to be_nil

    row = @client.getRow(@table_name, "ID1", {})[0].columns['info:first_name']
    expect(JSON.parse(row.value)).to eq({ 'p1' => "Vincent", 'p2' => "Thorbjørn" })
  end
  
  it "should take care of several encodings" do
    m1        = Apache::Hadoop::Hbase::Thrift::Mutation.new
    m1.column = "info:first_name"
    m1.value  = { :p1 => "Vincent", :p2 => "Thorbjørn" }.to_json.force_encoding(Encoding::UTF_8)
    
    m2        = Apache::Hadoop::Hbase::Thrift::Mutation.new
    m2.column = "info:company_name"
    m2.value  = "Thorbjørn"
    
    expect(m1.value.encoding).to eq(Encoding::UTF_8)
    expect(m2.value.encoding).to eq(Encoding::UTF_8)

    expect(@client.mutateRow(@table_name, "ID1", [m1, m2], {})).to be_nil
  end
  
  it "should destroy the table" do
    expect(@client.disableTable(@table_name)).to be_nil
    expect(@client.deleteTable(@table_name)).to be_nil
  end
end
