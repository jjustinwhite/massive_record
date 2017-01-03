require 'spec_helper'

describe "Retryable" do

  let(:retryable) { MassiveRecord::Adapters::Thrift::Retryable.new { } }

  describe "defaults" do
    it "should default the exception to retry to ::Apache::Hadoop::Hbase::Thrift::IOError" do
      expect(retryable.exception_to_retry).to eq(::Apache::Hadoop::Hbase::Thrift::IOError)
    end
  end
  
end
